"""Reconstruct a cTSEMO acquisition field from one retained iteration.

This is deterministic post-processing of the saved COSSIN2 result.  It does
not refit the optimizer, draw new random functions, or perform a new
optimization evaluation. The script reproduces the stored feasibility model,
objective Thompson draws, sampled HVI, crowding masks, and scalar acquisition
on a regular unit-square grid, and validates those calculations against the
saved candidate values. The analytical constraints are evaluated separately
only to draw the dashed offline truth boundary.
"""

from __future__ import annotations

import csv
from pathlib import Path

import h5py
import matplotlib.pyplot as plt
import numpy as np


ITERATION = 20
GRID_SIZE = 201


def matlab_array(dataset: h5py.Dataset) -> np.ndarray:
    """Return a MATLAB v7.3 numeric array in ordinary row-major orientation."""
    return np.asarray(dataset).T


def vector(dataset: h5py.Dataset) -> np.ndarray:
    return matlab_array(dataset).reshape(-1)


def scalar(dataset: h5py.Dataset) -> float:
    return float(np.asarray(dataset).reshape(-1)[0])


def referenced(handle: h5py.File, dataset: h5py.Dataset, index: int) -> h5py.Group:
    return handle[dataset[0, index]]


def pairwise_squared_distance(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    values = (
        np.sum(a * a, axis=1)[:, None]
        + np.sum(b * b, axis=1)[None, :]
        - 2.0 * a @ b.T
    )
    return np.maximum(values, 0.0)


def evaluate_pof(model: h5py.Group, query: np.ndarray) -> np.ndarray:
    training_x = matlab_array(model["X"])
    training_length = vector(model["trainingLength"])
    coefficient = vector(model["coefficient"])
    base_length = scalar(model["baseLength"])
    local_strength = scalar(model["localStrength"])
    maximum_multiplier = scalar(model["maxLengthScaleMultiplier"])
    purity_exponent = scalar(model["purityExponent"])
    prior_mean = scalar(model["priorMean"])

    state = model["densityState"]
    infeasible_x = matlab_array(state["infeasibleX"])
    feasible_x = matlab_array(state["feasibleX"])
    bandwidth = scalar(state["bandwidth"])
    pair_reference = scalar(state["pairReference"])
    infeasible_count = int(round(scalar(state["infeasibleCount"])))
    feasible_count = int(round(scalar(state["feasibleCount"])))

    if infeasible_count == 0:
        support = np.zeros(query.shape[0])
    else:
        infeasible_weight = np.exp(
            -0.5 * pairwise_squared_distance(query, infeasible_x) / bandwidth**2
        )
        infeasible_sum = np.sum(infeasible_weight, axis=1)
        pair_mass = 0.5 * (
            infeasible_sum**2 - np.sum(infeasible_weight**2, axis=1)
        )
        absolute_support = 1.0 - np.exp(-np.maximum(0.0, pair_mass) / pair_reference)

        if feasible_count == 0:
            feasible_sum = np.zeros(query.shape[0])
        else:
            feasible_weight = np.exp(
                -0.5 * pairwise_squared_distance(query, feasible_x) / bandwidth**2
            )
            feasible_sum = np.sum(feasible_weight, axis=1)

        density_minus = infeasible_sum / max(1, infeasible_count)
        density_plus = feasible_sum / max(1, feasible_count)
        contrast = (density_minus - density_plus) / (
            density_minus + density_plus + np.finfo(float).eps
        )
        purity = np.clip(contrast, 0.0, 1.0) ** purity_exponent
        support = np.clip(absolute_support * purity, 0.0, 1.0)

    query_length = base_length * np.minimum(
        maximum_multiplier, 1.0 + local_strength * support
    )
    distance_squared = pairwise_squared_distance(query, training_x)
    length_sum = query_length[:, None] ** 2 + training_length[None, :] ** 2
    dimension = query.shape[1]
    amplitude = (
        2.0 * query_length[:, None] * training_length[None, :] / length_sum
    ) ** (dimension / 2.0)
    q = 2.0 * distance_squared / length_sum
    scaled_distance = np.sqrt(3.0 * np.maximum(q, 0.0))
    covariance = amplitude * (1.0 + scaled_distance) * np.exp(-scaled_distance)
    raw = prior_mean + covariance @ coefficient

    anchor_x = matlab_array(model["anchorX"])
    anchor_targets = vector(model["anchorTargets"])
    for anchor, target in zip(anchor_x, anchor_targets, strict=True):
        exact = np.all(query == anchor, axis=1)
        raw[exact] = target
    return np.clip(raw, 0.0, 1.0)


def evaluate_draw(draw: h5py.Group, query: np.ndarray) -> np.ndarray:
    frequencies = matlab_array(draw["frequencies"])
    phases = vector(draw["phases"])
    feature_weights = vector(draw["featureWeights"])
    signal_std = scalar(draw["signalStd"])
    feature_count = int(round(scalar(draw["nFeatures"])))
    length_scale = vector(draw["lengthScale"])
    training_x = matlab_array(draw["XNormalized"])
    correction_weights = vector(draw["correctionWeights"])

    features = np.sqrt(2.0 * signal_std**2 / feature_count) * np.cos(
        query @ frequencies.T + phases[None, :]
    )
    prior_sample = features @ feature_weights
    scaled_query = query / length_scale[None, :]
    scaled_training = training_x / length_scale[None, :]
    squared_distance = pairwise_squared_distance(scaled_query, scaled_training)
    scaled_distance = np.sqrt(3.0 * squared_distance)
    covariance = signal_std**2 * (1.0 + scaled_distance) * np.exp(-scaled_distance)
    standardized_sample = prior_sample + covariance @ correction_weights
    return scalar(draw["outputMean"]) + scalar(draw["outputScale"]) * standardized_sample


def pareto2d(points: np.ndarray) -> np.ndarray:
    if points.size == 0:
        return np.empty((0, 2))
    order = np.lexsort((np.arange(points.shape[0]), points[:, 1], points[:, 0]))
    sorted_points = points[order]
    keep = []
    best_second = np.inf
    for point in sorted_points:
        if point[1] < best_second:
            keep.append(point)
            best_second = point[1]
    return np.asarray(keep)


def sampled_hvi(
    candidate_objectives: np.ndarray,
    feasible_objectives: np.ndarray,
    reference: np.ndarray,
) -> np.ndarray:
    contributes = np.all(feasible_objectives < reference[None, :], axis=1)
    front = pareto2d(feasible_objectives[contributes])
    if front.size == 0:
        return np.zeros(candidate_objectives.shape[0])
    interval_left = np.r_[-np.inf, front[:, 0]]
    interval_right = np.r_[front[:, 0], reference[0]]
    attained_second = np.r_[reference[1], front[:, 1]]
    widths = np.maximum(
        0.0,
        interval_right[None, :] - np.maximum(interval_left[None, :], candidate_objectives[:, 0, None]),
    )
    heights = np.maximum(0.0, attained_second[None, :] - candidate_objectives[:, 1, None])
    return np.maximum(0.0, np.sum(widths * heights, axis=1))


def compact_mask(distance: np.ndarray, radius: float, floor: float) -> np.ndarray:
    scaled = distance / radius
    kernel = np.zeros_like(scaled)
    active = np.isfinite(scaled) & (scaled < 1.0)
    s = np.maximum(0.0, scaled[active])
    kernel[active] = (1.0 - s) ** 4 * (4.0 * s + 1.0)
    return floor + (1.0 - floor) * (1.0 - kernel)


def minimum_distance(query: np.ndarray, training: np.ndarray) -> np.ndarray:
    if training.size == 0:
        return np.full(query.shape[0], np.inf)
    return np.sqrt(np.min(pairwise_squared_distance(query, training), axis=1))


def option_scalar(handle: h5py.File, path: str) -> float:
    return scalar(handle[path])


def cossin2_truth(query: np.ndarray) -> np.ndarray:
    centers = np.array([[0.10, 0.70], [0.40, 0.40], [0.70, 0.10]])
    outside_disks = np.all(
        np.sqrt(np.sum((query[:, None, :] - centers[None, :, :]) ** 2, axis=2))
        >= 0.15,
        axis=1,
    )
    below_diagonal = np.sum(query, axis=1) <= 1.0
    return outside_disks & below_diagonal


def main() -> None:
    repository = Path(__file__).resolve().parents[2]
    artifact = repository / "manuscript" / "artifacts" / "two_dimensional_campaign"
    result_path = artifact / "runs" / "COSSIN2_result.mat"
    output_directory = artifact / "figures"
    output_directory.mkdir(parents=True, exist_ok=True)
    output_pdf = output_directory / "cossin2_acquisition_decomposition.pdf"
    output_png = output_directory / "cossin2_acquisition_decomposition.png"
    output_csv = artifact / "cossin2_acquisition_decomposition_metrics.csv"

    axis = np.linspace(0.0, 1.0, GRID_SIZE)
    grid_x, grid_y = np.meshgrid(axis, axis, indexing="xy")
    grid = np.column_stack([grid_x.ravel(), grid_y.ravel()])

    with h5py.File(result_path, "r") as handle:
        iteration_index = ITERATION - 1
        iterations = handle["result/iterations"]
        model = referenced(handle, iterations["pofModel"], iteration_index)
        candidates = referenced(handle, iterations["candidates"], iteration_index)
        selected = referenced(handle, iterations["selected"], iteration_index)
        scaling = referenced(handle, iterations["objectiveScaling"], iteration_index)
        draws_ref = referenced(handle, iterations["objectiveDraws"], iteration_index)
        draws = [handle[reference] for reference in np.asarray(draws_ref).reshape(-1)]

        pof = evaluate_pof(model, grid)
        y_draw = np.column_stack([evaluate_draw(draw, grid) for draw in draws])
        center = vector(scaling["center"])
        scale = vector(scaling["scale"])
        y_draw_standardized = (y_draw - center[None, :]) / scale[None, :]

        training_count = matlab_array(model["X"]).shape[0]
        training_x = matlab_array(handle["result/data/X"])[:training_count]
        training_y = matlab_array(handle["result/data/Y"])[:training_count]
        training_feasible = vector(handle["result/data/isFeasible"])[:training_count].astype(bool)
        training_y_standardized = (training_y - center[None, :]) / scale[None, :]
        reference = vector(referenced(handle, iterations["acquisitionReferencePoint"], iteration_index))
        hvi = sampled_hvi(y_draw_standardized, training_y_standardized[training_feasible], reference)

        design_radius = option_scalar(handle, "result/options/masks/design/radiusScale")
        design_floor = option_scalar(handle, "result/options/masks/design/floor")
        codomain_radius = option_scalar(handle, "result/options/masks/codomain/radiusScale")
        codomain_floor = option_scalar(handle, "result/options/masks/codomain/floor")
        duplicate_tolerance = option_scalar(handle, "result/options/candidates/duplicateTolerance")
        pof_power = option_scalar(handle, "result/options/acquisition/pofPower")
        if not np.isclose(pof_power, 1.0):
            raise ValueError("The direct PoF-times-HVI panel requires pofPower = 1.")
        epsilon = scalar(candidates["epsilon"])

        design_distance = minimum_distance(grid, training_x)
        design_mask = compact_mask(design_distance, design_radius, design_floor)
        design_mask[design_distance <= duplicate_tolerance] = 0.0
        codomain_distance = minimum_distance(y_draw_standardized, training_y_standardized)
        codomain_mask = compact_mask(codomain_distance, codomain_radius, codomain_floor)
        weighted_hvi = pof**pof_power * hvi
        acquisition = (hvi + epsilon) * pof**pof_power * design_mask * codomain_mask

        # Verify the reconstruction on the exact 513 stored candidate points.
        candidate_x = matlab_array(candidates["XUnit"])
        candidate_pof = evaluate_pof(model, candidate_x)
        candidate_y = np.column_stack([evaluate_draw(draw, candidate_x) for draw in draws])
        candidate_y_standardized = (candidate_y - center[None, :]) / scale[None, :]
        candidate_hvi = sampled_hvi(
            candidate_y_standardized,
            training_y_standardized[training_feasible],
            reference,
        )
        candidate_design_distance = minimum_distance(candidate_x, training_x)
        candidate_design_mask = compact_mask(candidate_design_distance, design_radius, design_floor)
        candidate_design_mask[candidate_design_distance <= duplicate_tolerance] = 0.0
        candidate_codomain_distance = minimum_distance(candidate_y_standardized, training_y_standardized)
        candidate_codomain_mask = compact_mask(candidate_codomain_distance, codomain_radius, codomain_floor)
        candidate_acquisition = (
            (candidate_hvi + epsilon)
            * candidate_pof**pof_power
            * candidate_design_mask
            * candidate_codomain_mask
        )
        residuals = {
            "pof": float(np.max(np.abs(candidate_pof - vector(candidates["pof"])))),
            "sampled_hvi": float(np.max(np.abs(candidate_hvi - vector(candidates["sampledHVI"])))),
            "design_mask": float(np.max(np.abs(candidate_design_mask - vector(candidates["designMask"])))),
            "codomain_mask": float(np.max(np.abs(candidate_codomain_mask - vector(candidates["codomainMask"])))),
            "acquisition": float(np.max(np.abs(candidate_acquisition - vector(candidates["AF"])))),
        }
        if max(residuals.values()) > 2.0e-9:
            raise RuntimeError(f"Stored-candidate reconstruction failed: {residuals}")

        selected_x = matlab_array(selected["X"]).reshape(-1, 2)[0]
        selected_pof = scalar(selected["pof"])
        selected_hvi = scalar(selected["sampledHVI"])
        selected_acquisition = scalar(selected["AF"])
        stored_pof = vector(candidates["pof"])
        stored_hvi = vector(candidates["sampledHVI"])
        max_pof_index = int(np.argmax(stored_pof))
        max_hvi_index = int(np.argmax(stored_hvi))

    truth = cossin2_truth(grid).reshape(GRID_SIZE, GRID_SIZE)
    fields = [
        (pof, r"(a) Feasibility score $p_{i,20}$", "viridis"),
        (hvi, r"(b) Sampled HVI $H^{\mathrm{TS}}_{20}$", "magma"),
        (weighted_hvi, r"(c) Product $p_{i,20}H^{\mathrm{TS}}_{20}$", "magma"),
        (acquisition, r"(d) Final acquisition $A_{20}$", "magma"),
    ]

    plt.rcParams.update(
        {
            "font.family": "serif",
            "font.serif": ["Times New Roman", "DejaVu Serif"],
            "mathtext.fontset": "custom",
            "mathtext.rm": "Times New Roman",
            "mathtext.it": "Times New Roman:italic",
            "mathtext.bf": "Times New Roman:bold",
            "mathtext.cal": "Times New Roman:italic",
            "mathtext.sf": "Times New Roman",
            "mathtext.tt": "Times New Roman",
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
            "font.size": 9.0,
            "axes.titlesize": 10.0,
            "axes.labelsize": 9.0,
            "xtick.labelsize": 8.0,
            "ytick.labelsize": 8.0,
        }
    )
    figure, axes = plt.subplots(2, 2, figsize=(7.25, 6.55), constrained_layout=True)
    for panel, (values, title, color_map) in zip(axes.flat, fields, strict=True):
        field = values.reshape(GRID_SIZE, GRID_SIZE)
        image = panel.pcolormesh(
            grid_x,
            grid_y,
            field,
            shading="auto",
            cmap=color_map,
            rasterized=True,
            antialiased=False,
            linewidth=0,
        )
        panel.contour(grid_x, grid_y, truth.astype(float), levels=[0.5], colors="white", linestyles="--", linewidths=0.9)
        panel.scatter(
            training_x[training_feasible, 0],
            training_x[training_feasible, 1],
            s=18,
            facecolors="white",
            edgecolors="black",
            linewidths=0.55,
            zorder=4,
        )
        panel.scatter(
            training_x[~training_feasible, 0],
            training_x[~training_feasible, 1],
            s=19,
            marker="x",
            color="#d62728",
            linewidths=0.9,
            zorder=5,
        )
        panel.scatter(
            selected_x[0],
            selected_x[1],
            s=75,
            marker="*",
            facecolors="#35f2ff",
            edgecolors="black",
            linewidths=0.7,
            zorder=6,
        )
        panel.set_title(title, pad=5)
        panel.set_xlim(0.0, 1.0)
        panel.set_ylim(0.0, 1.0)
        panel.set_aspect("equal", adjustable="box")
        panel.set_xlabel(r"Normalized $x_1$")
        panel.set_ylabel(r"Normalized $x_2$")
        panel.grid(False)
        colorbar = figure.colorbar(image, ax=panel, fraction=0.047, pad=0.025)
        colorbar.ax.tick_params(labelsize=7.5)

    axes[1, 1].plot([], [], "o", markerfacecolor="white", markeredgecolor="black", markersize=5, label="Observed feasible")
    axes[1, 1].plot([], [], "x", color="#d62728", markersize=5, label="Observed violating")
    axes[1, 1].plot([], [], "*", markerfacecolor="#35f2ff", markeredgecolor="black", markersize=8, label="Selected next point")
    axes[1, 1].plot([], [], "--", color="white", linewidth=1.0, label="True boundary (offline)")
    legend = axes[1, 1].legend(loc="upper right", fontsize=7.0, frameon=True, framealpha=0.88)
    legend.get_frame().set_edgecolor("0.3")

    figure.savefig(output_pdf, dpi=600, bbox_inches="tight")
    figure.savefig(output_png, dpi=400, bbox_inches="tight")
    plt.close(figure)

    rows = [
        ("iteration", ITERATION),
        ("training_observations", training_count),
        ("pof_power", pof_power),
        ("epsilon", epsilon),
        ("selected_x1", selected_x[0]),
        ("selected_x2", selected_x[1]),
        ("selected_pof", selected_pof),
        ("selected_sampled_hvi", selected_hvi),
        ("selected_acquisition", selected_acquisition),
        ("maximum_pof", stored_pof[max_pof_index]),
        ("hvi_at_maximum_pof_candidate", stored_hvi[max_pof_index]),
        ("maximum_sampled_hvi", stored_hvi[max_hvi_index]),
        ("pof_at_maximum_hvi_candidate", stored_pof[max_hvi_index]),
    ] + [(f"maximum_validation_residual_{name}", value) for name, value in residuals.items()]
    with output_csv.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(["metric", "value"])
        writer.writerows(rows)

    print(output_pdf)
    print(output_png)
    print(output_csv)
    print(residuals)


if __name__ == "__main__":
    main()
