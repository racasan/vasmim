[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [string]$FlutterCommand = 'flutter',
    [string]$ReleaseDirectory,
    [string]$OutputDirectory,
    [string]$NativeAssetsSearchDirectory,
    [string]$ReleaseNotesPath,
    [string]$ArtifactSuffix
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

if (-not $ReleaseDirectory) {
    $ReleaseDirectory = Join-Path $repositoryRoot 'build\windows\x64\runner\Release'
}
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repositoryRoot 'dist'
}
if (-not $NativeAssetsSearchDirectory) {
    $NativeAssetsSearchDirectory = Join-Path $repositoryRoot '.dart_tool\flutter_build'
}

$releasePath = [System.IO.Path]::GetFullPath($ReleaseDirectory)
$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
$nativeAssetsSearchPath = [System.IO.Path]::GetFullPath($NativeAssetsSearchDirectory)
$outputRoot = [System.IO.Path]::GetPathRoot($outputPath)
if ($outputPath.TrimEnd('\') -eq $outputRoot.TrimEnd('\')) {
    throw "Output directory must not be a filesystem root: $outputPath"
}
if ($outputPath.TrimEnd('\') -eq $repositoryRoot.TrimEnd('\')) {
    throw "Output directory must not be the repository root: $outputPath"
}

function Assert-NativeAssetsMetadata {
    param([string]$Path)

    try {
        $rawMetadata = [System.IO.File]::ReadAllText($Path)
        $metadata = $rawMetadata | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Native-assets metadata is malformed: $Path. $($_.Exception.Message)"
    }

    if ($null -eq $metadata -or
        $metadata -isnot [System.Management.Automation.PSCustomObject]) {
        throw "Native-assets metadata is malformed: expected a JSON object in $Path"
    }
    $propertyNames = @($metadata.PSObject.Properties.Name)
    if ($propertyNames -notcontains 'format-version' -or
        $propertyNames -notcontains 'native-assets') {
        throw "Native-assets metadata is malformed: expected format-version and native-assets properties in $Path"
    }

    $formatVersion = @($metadata.'format-version')
    if ($formatVersion.Count -ne 3 -or
        $formatVersion[0] -ne 1 -or
        $formatVersion[1] -ne 0 -or
        $formatVersion[2] -ne 0) {
        throw "Native-assets metadata is malformed: unsupported format-version in $Path"
    }
    if ($null -eq $metadata.'native-assets' -or
        $metadata.'native-assets' -isnot [System.Management.Automation.PSCustomObject]) {
        throw "Native-assets metadata is malformed: native-assets must be an object in $Path"
    }
}

if (-not $SkipBuild) {
    Push-Location $repositoryRoot
    try {
        & $FlutterCommand build windows
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter Windows release build failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path -LiteralPath $releasePath -PathType Container)) {
    throw "Windows release directory does not exist: $releasePath"
}

$requiredPayload = @(
    'vasmim.exe',
    'flutter_windows.dll',
    'file_selector_windows_plugin.dll',
    'data\app.so',
    'data\icudtl.dat',
    'data\flutter_assets\AssetManifest.bin'
)
foreach ($relativePath in $requiredPayload) {
    $requiredPath = Join-Path $releasePath $relativePath
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required Windows runtime payload is missing: $requiredPath"
    }
}

$releaseNativeAssetsPath = Join-Path $releasePath 'native_assets.json'
if (Test-Path -LiteralPath $releaseNativeAssetsPath -PathType Leaf) {
    Assert-NativeAssetsMetadata -Path $releaseNativeAssetsPath
    $nativeAssetsSourcePath = $releaseNativeAssetsPath
}
else {
    if (-not (Test-Path -LiteralPath $nativeAssetsSearchPath -PathType Container)) {
        throw "Generated native-assets metadata is missing: search directory does not exist: $nativeAssetsSearchPath"
    }
    $searchRoot = [System.IO.Path]::GetPathRoot($nativeAssetsSearchPath)
    if ($nativeAssetsSearchPath.TrimEnd('\') -eq $searchRoot.TrimEnd('\')) {
        throw "Native-assets metadata search directory must not be a filesystem root: $nativeAssetsSearchPath"
    }

    $searchPrefix = $nativeAssetsSearchPath.TrimEnd('\') + '\'
    $nativeAssetsCandidates = @(
        Get-ChildItem -LiteralPath $nativeAssetsSearchPath -Recurse -File -Filter 'native_assets.json' |
            Sort-Object FullName
    )
    if ($nativeAssetsCandidates.Count -eq 0) {
        throw "Generated native-assets metadata is missing under: $nativeAssetsSearchPath"
    }

    foreach ($candidate in $nativeAssetsCandidates) {
        $candidatePath = [System.IO.Path]::GetFullPath($candidate.FullName)
        if (-not $candidatePath.StartsWith($searchPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Native-assets metadata candidate escaped the search directory: $candidatePath"
        }
        Assert-NativeAssetsMetadata -Path $candidatePath
    }

    $candidateHashes = @(
        $nativeAssetsCandidates |
            ForEach-Object { (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash } |
            Select-Object -Unique
    )
    if ($candidateHashes.Count -ne 1) {
        throw "Generated native-assets metadata is content-ambiguous under: $nativeAssetsSearchPath"
    }
    $nativeAssetsSourcePath = [System.IO.Path]::GetFullPath($nativeAssetsCandidates[0].FullName)
}

if (-not $ReleaseNotesPath) {
    $ReleaseNotesPath = Join-Path $repositoryRoot 'release\RELEASE_NOTES.md'
}
$releaseNotesName = 'RELEASE_NOTES.md'
$releaseNotesPath = [System.IO.Path]::GetFullPath($ReleaseNotesPath)
if (-not (Test-Path -LiteralPath $releaseNotesPath -PathType Leaf)) {
    throw "Release notes are missing: $releaseNotesPath"
}

if (Test-Path -LiteralPath $outputPath) {
    $existingOutput = @(Get-ChildItem -LiteralPath $outputPath -Force)
    if ($existingOutput.Count -ne 0) {
        throw "Output directory must be empty: $outputPath"
    }
}

$pubspecPath = Join-Path $repositoryRoot 'pubspec.yaml'
$versionLine = Get-Content -LiteralPath $pubspecPath | Where-Object {
    $_ -match '^version:\s*(\S+)\s*$'
} | Select-Object -First 1
if (-not $versionLine -or $versionLine -notmatch '^version:\s*(\S+)\s*$') {
    throw "Could not read the release version from: $pubspecPath"
}
$version = $Matches[1]
if ($version -notmatch '^[0-9A-Za-z.+-]+$') {
    throw "Release version contains unsafe artifact-name characters: $version"
}
if ($ArtifactSuffix -and $ArtifactSuffix -notmatch '^[0-9A-Za-z.-]+$') {
    throw "Artifact suffix contains unsafe characters: $ArtifactSuffix"
}

$bundleName = "Vasmim-Windows-$version-x64"
if ($ArtifactSuffix) {
    $bundleName = "$bundleName-$ArtifactSuffix"
}
$zipName = "$bundleName.zip"
$stagingName = ".windows-alpha-staging-$([guid]::NewGuid().ToString('N'))"
$stagingPath = Join-Path $outputPath $stagingName
$stagingPrefix = $outputPath.TrimEnd('\') + '\'

New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
New-Item -ItemType Directory -Path $stagingPath | Out-Null

try {
    $bundlePath = Join-Path $stagingPath $bundleName
    New-Item -ItemType Directory -Path $bundlePath | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $releasePath -Force) {
        Copy-Item -LiteralPath $item.FullName -Destination $bundlePath -Recurse
    }
    Copy-Item -LiteralPath $nativeAssetsSourcePath -Destination (Join-Path $bundlePath 'native_assets.json') -Force
    Copy-Item -LiteralPath $releaseNotesPath -Destination (Join-Path $bundlePath $releaseNotesName)

    $stagedZipPath = Join-Path $stagingPath $zipName
    Compress-Archive -LiteralPath $bundlePath -DestinationPath $stagedZipPath -CompressionLevel Optimal

    $finalZipPath = Join-Path $outputPath $zipName
    Move-Item -LiteralPath $stagedZipPath -Destination $finalZipPath
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $finalZipPath).Hash
    $checksumPath = "$finalZipPath.sha256"
    [System.IO.File]::WriteAllText(
        $checksumPath,
        "$hash  $zipName`r`n",
        [System.Text.Encoding]::ASCII
    )

    Write-Output "Created $finalZipPath"
    Write-Output "Created $checksumPath"
}
finally {
    $resolvedStaging = [System.IO.Path]::GetFullPath($stagingPath)
    if (-not $resolvedStaging.StartsWith($stagingPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Safety stop: staging escaped the output directory: $resolvedStaging"
    }
    if (-not ([System.IO.Path]::GetFileName($resolvedStaging)).StartsWith('.windows-alpha-staging-')) {
        throw "Safety stop: unexpected staging directory name: $resolvedStaging"
    }
    if (Test-Path -LiteralPath $resolvedStaging) {
        Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
    }
}
