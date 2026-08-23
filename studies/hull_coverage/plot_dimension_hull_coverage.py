"""Create the manuscript figure for dimension and convex-hull coverage.

The left panel re-plots archived, deterministic convex-hull calculations for
one fixed-seed maximin Latin-hypercube sequence per dimension.  The right
panel shows two exact geometric endpoint constructions in the unit cube.
No optimizer, surrogate model, or random-number generator is invoked here.
"""

from __future__ import annotations

import csv
import math
import os
from collections import defaultdict
from pathlib import Path

os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("MKL_NUM_THREADS", "1")

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import colormaps


STUDY_DIRECTORY = Path(__file__).resolve().parent
REPOSITORY = STUDY_DIRECTORY.parents[1]
HULL_CSV = STUDY_DIRECTORY / "data" / "convex_hull_growth.csv"
SIMPLEX_CSV = STUDY_DIRECTORY / "data" / "maximum_simplex_volume.csv"
OUTPUT_DIR = REPOSITORY / "manuscript" / "artifacts" / "hull_coverage"


def read_hull_growth() -> dict[int, list[tuple[int, float]]]:
    curves: dict[int, list[tuple[int, float]]] = defaultdict(list)
    with HULL_CSV.open(newline="", encoding="utf-8-sig") as stream:
        for row in csv.DictReader(stream):
            if row["Status"].strip().lower() != "ok":
                continue
            volume = float(row["ConvexHullHV"])
            if not math.isfinite(volume) or volume <= 0.0:
                continue
            curves[int(row["Dimension"])].append(
                (int(row["SampleCount"]), volume)
            )
    return dict(sorted(curves.items()))


def read_simplex_volumes() -> tuple[list[int], list[float]]:
    dimensions: list[int] = []
    volumes: list[float] = []
    with SIMPLEX_CSV.open(newline="", encoding="utf-8-sig") as stream:
        for row in csv.DictReader(stream):
            dimension = int(row["Dimension"])
            if dimension < 2:
                continue
            dimensions.append(dimension)
            volumes.append(float(row["MaxSimplexHV"]))
    return dimensions, volumes


def configure_style() -> None:
    plt.rcParams.update(
        {
            "font.family": "serif",
            "font.serif": ["Times New Roman", "Times", "DejaVu Serif"],
            "mathtext.fontset": "stix",
            "font.size": 7.5,
            "axes.labelsize": 7.5,
            "axes.titlesize": 8.0,
            "legend.fontsize": 6.3,
            "xtick.labelsize": 7.0,
            "ytick.labelsize": 7.0,
            "axes.linewidth": 0.65,
            "grid.linewidth": 0.45,
            "lines.linewidth": 1.0,
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
            "savefig.bbox": "tight",
            "savefig.pad_inches": 0.03,
        }
    )


def main() -> None:
    configure_style()
    curves = read_hull_growth()
    dimensions, simplex_volumes = read_simplex_volumes()

    expected_dimensions = list(range(2, 11))
    if list(curves) != expected_dimensions:
        raise RuntimeError(
            f"Expected hull data for dimensions {expected_dimensions}; "
            f"found {list(curves)}."
        )
    if dimensions != list(range(2, 21)):
        raise RuntimeError("Expected maximum-simplex data for dimensions 2--20.")

    endpoint_checks = {2: 0.949208624490543, 8: 0.063788426334456,
                       9: 0.0175856910081299, 10: 0.00258327408627884}
    for dimension, expected in endpoint_checks.items():
        actual = curves[dimension][-1][1]
        if not math.isclose(actual, expected, rel_tol=1e-12, abs_tol=0.0):
            raise RuntimeError(
                f"Unexpected d={dimension} endpoint: {actual:.16g}."
            )

    fig, axes = plt.subplots(2, 1, figsize=(4.80, 5.25))
    fig.subplots_adjust(left=0.125, right=0.985, bottom=0.09, top=0.985,
                        hspace=0.56)

    ax = axes[0]
    colors = colormaps["viridis"](
        [(dimension - 2) / 8 for dimension in expected_dimensions]
    )
    line_styles = ["-", "--", "-."]
    marker_styles = ["o", "s", "^"]
    for index, (color, dimension) in enumerate(zip(colors, expected_dimensions)):
        points = curves[dimension]
        x = [item[0] for item in points]
        y = [item[1] for item in points]
        ax.plot(
            x,
            y,
            color=color,
            linestyle=line_styles[index % len(line_styles)],
            marker=marker_styles[index // len(line_styles)],
            markevery=20,
            markersize=2.4,
            markerfacecolor="white",
            markeredgewidth=0.65,
            label=fr"$d={dimension}$",
        )
        if dimension in (9, 10):
            ax.plot(x[-1], y[-1], marker="x", markersize=4.4,
                    markeredgewidth=0.9, color=color)
    ax.axvline(150, color="0.35", linestyle="--", linewidth=0.8)
    ax.text(151.5, 1.55e-8, "150-evaluation budget", rotation=90,
            va="bottom", ha="left", color="0.30", fontsize=6.4)
    ax.set_yscale("log")
    ax.set_xlim(0, 205)
    ax.set_ylim(1e-9, 1.3)
    ax.set_xlabel("Number of points, $k$")
    ax.set_ylabel("Observed convex-hull fraction")
    ax.set_title("(a) Hull expansion along fixed maximin-LHS sequences",
                 loc="left", pad=4)
    ax.grid(True, which="both", alpha=0.30)
    ax.legend(
        ncol=5,
        loc="upper center",
        bbox_to_anchor=(0.5, -0.18),
        frameon=True,
        columnspacing=0.8,
        handlelength=1.5,
        borderpad=0.35,
    )

    ax = axes[1]
    near_complete = [1.0 - 1.0 / math.factorial(dimension)
                     for dimension in dimensions]
    ax.axvspan(2, 10, color="0.92", zorder=0,
               label="evaluated dimension range")
    ax.semilogy(
        dimensions,
        simplex_volumes,
        color="#2166ac",
        marker="o",
        markersize=3.0,
        label=r"maximum at $k=d+1$",
    )
    ax.semilogy(
        dimensions,
        near_complete,
        color="#b35806",
        marker="s",
        markersize=2.8,
        label=r"construction at $k=2^d-1$",
    )
    ax.set_xlim(1.7, 20.3)
    ax.set_ylim(1e-12, 2.0)
    ax.set_xticks([2, 4, 6, 8, 10, 12, 14, 16, 18, 20])
    ax.set_xlabel("Dimension, $d$")
    ax.set_ylabel("Normalized hull volume")
    ax.set_title("(b) Two geometric endpoint cases in the unit cube",
                 loc="left", pad=4)
    ax.grid(True, which="both", alpha=0.30)
    ax.legend(loc="lower left", frameon=True, borderpad=0.35)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    pdf_path = OUTPUT_DIR / "dimension_hull_coverage.pdf"
    png_path = OUTPUT_DIR / "dimension_hull_coverage.png"
    fig.savefig(pdf_path)
    fig.savefig(png_path, dpi=320)
    plt.close(fig)

    print(pdf_path)
    print(png_path)


if __name__ == "__main__":
    main()
