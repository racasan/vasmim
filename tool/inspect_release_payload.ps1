[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ReleaseDirectory,
    [Parameter(Mandatory = $true)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$releasePath = [System.IO.Path]::GetFullPath($ReleaseDirectory)
$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
if (-not (Test-Path -LiteralPath $releasePath -PathType Container)) {
    throw "Release directory does not exist: $releasePath"
}
if (Test-Path -LiteralPath $outputPath) {
    throw 'Inventory output must be a new directory; existing files are preserved.'
}

$inventory = @(
    Get-ChildItem -LiteralPath $releasePath -Recurse -File | Sort-Object FullName |
    ForEach-Object {
        [ordered]@{
            path = $_.FullName.Substring($releasePath.TrimEnd('\').Length + 1).Replace('\', '/')
            bytes = $_.Length
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
        }
    }
)
$fingerprintText = ($inventory | ForEach-Object { "$($_.path) $($_.sha256)" }) -join "`n"
$hasher = [System.Security.Cryptography.SHA256]::Create()
try {
    $fingerprint = [BitConverter]::ToString($hasher.ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($fingerprintText))).Replace('-', '')
}
finally { $hasher.Dispose() }

New-Item -ItemType Directory -Path $outputPath | Out-Null
$licensePath = Join-Path $outputPath 'licenses'
New-Item -ItemType Directory -Path $licensePath | Out-Null
$configPath = Join-Path $repositoryRoot '.dart_tool\package_config.json'
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$configUri = [uri]::new($configPath)
$packages = @()
foreach ($package in $config.packages) {
    if ($package.name -eq 'vasmim') { continue }
    $packageRoot = [uri]::new($configUri, $package.rootUri).LocalPath
    $packageNotices = @(Get-ChildItem -LiteralPath $packageRoot -File |
        Where-Object { $_.Name -match '^(LICENSE|LICENCE|COPYING|NOTICE)([.-]|$)' })
    foreach ($notice in $packageNotices) {
        $destination = Join-Path $licensePath ("$($package.name)-$($notice.Name)")
        Copy-Item -LiteralPath $notice.FullName -Destination $destination
    }
    $packages += [ordered]@{ package = $package.name; noticesCollected = @($packageNotices.Name) }
}
$runtimePdfiumNotices = Join-Path $releasePath 'data\native_licenses\pdfium'
if (Test-Path -LiteralPath $runtimePdfiumNotices -PathType Container) {
    $pdfiumProvenance = Get-Content -LiteralPath (Join-Path $runtimePdfiumNotices 'provenance.json') -Raw | ConvertFrom-Json
    $runtimePdfiumHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $releasePath 'pdfium.dll')).Hash
    if ($runtimePdfiumHash -ine $pdfiumProvenance.dllSha256) {
        throw 'PDFium runtime and bundled notice provenance do not match.'
    }
    Copy-Item -LiteralPath $runtimePdfiumNotices -Destination (Join-Path $licensePath 'pdfium') -Recurse
}
$nativeNotices = @{
    'flutter-LICENSE.txt' = 'windows\flutter\ephemeral\LICENSE'
    'clipboard-NOTICES.txt' = 'release\CLIPBOARD_THIRD_PARTY_NOTICES.txt'
    'rust-stdlib-NOTICES.html' = 'release\RUST_STDLIB_NOTICES.html'
    'rust-runtime-LICENSES.txt' = 'release\RUST_RUNTIME_LICENSES.txt'
}
if (-not (Test-Path -LiteralPath $runtimePdfiumNotices -PathType Container)) {
    # Historical candidates retain their historical source-cache evidence.
    $nativeNotices['pdfium-LICENSE.txt'] = 'build\windows\x64\pdfium-src\LICENSE'
}
foreach ($name in $nativeNotices.Keys) {
    $source = Join-Path $repositoryRoot $nativeNotices[$name]
    if (Test-Path -LiteralPath $source -PathType Leaf) {
        Copy-Item -LiteralPath $source -Destination (Join-Path $licensePath $name)
    }
}
$report = [ordered]@{
    schemaVersion = 1
    runtimeFingerprint = $fingerprint
    files = $inventory
    packageNotices = $packages
    note = 'Inventory and collected notices for this exact runtime. It is a record, not a warranty.'
}
[System.IO.File]::WriteAllText((Join-Path $outputPath 'runtime_inventory.json'),
    ($report | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))
Write-Output "Created inventory and collected licence evidence in $outputPath"
Write-Output "Runtime fingerprint: $fingerprint"
