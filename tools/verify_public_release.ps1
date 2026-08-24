[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$manifestPath = Join-Path $repositoryRoot 'manuscript\artifacts\artifact_manifest.csv'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Missing artifact manifest: $manifestPath"
}

$rows = Import-Csv -LiteralPath $manifestPath
$seen = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
$prefix = $repositoryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) +
    [IO.Path]::DirectorySeparatorChar
foreach ($row in $rows) {
    $relative = [string]$row.RelativePath
    $candidate = [IO.Path]::GetFullPath((Join-Path $repositoryRoot (
        $relative -replace '/', [IO.Path]::DirectorySeparatorChar)))
    if (-not $candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Manifest path escapes repository: $relative"
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Manifest file is missing: $relative"
    }
    $file = Get-Item -LiteralPath $candidate
    if ($file.Length -ne [int64]$row.Bytes) {
        throw "Manifest size differs: $relative"
    }
    $hash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne ([string]$row.Sha256).ToLowerInvariant()) {
        throw "Manifest hash differs: $relative"
    }
    if (-not $seen.Add($relative.Replace('\', '/'))) {
        throw "Duplicate manifest path: $relative"
    }
}

$prohibitedExtensions = @('.exe', '.dll', '.mexw64', '.pyd', '.so')
$maximumBytes = 20MB
$textExtensions = @('.md', '.m', '.py', '.ps1', '.json', '.csv', '.txt',
    '.xml', '.yml', '.cff', '.tex')
$drivePattern = '[A-Za-z]' + [char]58 + '\\Users\\'
$profilePattern = '(?i)OneDrive\\Desktop|/home/[^/]+/'
$uncIpPattern = '\\\\(?:\d{1,3}\.){3}\d{1,3}\\'
$secretPatterns = @(
    '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    'gh[pousr]_[A-Za-z0-9_]{30,}',
    'sk-[A-Za-z0-9]{32,}',
    'AKIA[0-9A-Z]{16}'
)

foreach ($file in Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File) {
    $relative = $file.FullName.Substring($repositoryRoot.Length + 1).Replace('\', '/')
    if ($relative.StartsWith('.git/', [StringComparison]::OrdinalIgnoreCase) -or
            $relative.StartsWith('generated/', [StringComparison]::OrdinalIgnoreCase) -or
            $relative.StartsWith('tmp/', [StringComparison]::OrdinalIgnoreCase) -or
            $file.FullName -eq $PSCommandPath) {
        continue
    }
    if ($file.Length -ge $maximumBytes) {
        throw "Release file is not below 20 MB: $relative"
    }
    if ($prohibitedExtensions -contains $file.Extension.ToLowerInvariant()) {
        throw "Prohibited executable or compiled extension: $relative"
    }
    if ($textExtensions -notcontains $file.Extension.ToLowerInvariant() -and
            $file.Name -notin @('.gitignore', '.gitattributes')) {
        continue
    }
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if ($content -match $drivePattern -or $content -match $profilePattern -or
            $content -match $uncIpPattern) {
        throw "Machine-specific path found in public text: $relative"
    }
    foreach ($pattern in $secretPatterns) {
        if ($content -match $pattern) {
            throw "Potential credential found in public text: $relative"
        }
    }
}

$required = @(
    'src/cTSEMO.m',
    'docs/REPRODUCING.md',
    'docs/RESULTS_MAP.md',
    'manuscript/artifacts/finite_primary_ablation/reproduce_finite_primary_ablation.m',
    'manuscript/artifacts/wb150_thesis/generate_wb150_thesis_artifacts.m',
    'manuscript/artifacts/ga_primary_dimension/selection_state_totals.csv'
)
foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $relative) -PathType Leaf)) {
        throw "Missing essential release file: $relative"
    }
}

Write-Output (("Public release verified: {0} artifact files; hashes, sizes, " +
    "paths, required files, prohibited binaries, and high-confidence secret " +
    "patterns passed. MAT privacy is checked by ThesisArtifactTest.m.") -f
    $rows.Count)
