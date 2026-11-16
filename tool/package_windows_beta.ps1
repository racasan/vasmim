[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ReleaseDirectory,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [Parameter(Mandatory = $true)][string]$LicenseDirectory,
    [string]$DocumentsDirectory
)

# Packages an existing Windows release build as the public portable ZIP.
# It never builds, downloads, installs or publishes anything.

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$releasePath = [System.IO.Path]::GetFullPath($ReleaseDirectory)
$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
if (-not $DocumentsDirectory) { $DocumentsDirectory = Join-Path $repositoryRoot 'release' }
$documentsPath = [System.IO.Path]::GetFullPath($DocumentsDirectory)
if (-not (Test-Path -LiteralPath $releasePath -PathType Container)) { throw 'Release folder is missing.' }
if (Test-Path -LiteralPath $outputPath) {
    if (@(Get-ChildItem -LiteralPath $outputPath -Force).Count -ne 0) {
        throw 'Output directory must be empty. Existing artifacts are preserved.'
    }
}

$requiredFiles = @(
    'vasmim.exe', 'flutter_windows.dll', 'file_selector_windows_plugin.dll',
    'irondash_engine_context_plugin.dll', 'pdfium.dll', 'pdfx_plugin.dll',
    'super_native_extensions.dll', 'super_native_extensions_plugin.dll',
    'url_launcher_windows_plugin.dll', 'data\app.so', 'data\icudtl.dat',
    'data\flutter_assets\AssetManifest.bin', 'data\flutter_assets\NOTICES.Z'
)
foreach ($name in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $releasePath $name) -PathType Leaf)) {
        throw "Required current runtime payload is missing: $name"
    }
}
$allowedRootFiles = @($requiredFiles | Where-Object { $_ -notmatch '\\' }) + @(
    # The resolved jni package's Windows native-asset hook emits this DLL in a
    # normal Flutter build. Its package notice is collected like the others.
    'dartjni.dll',
    # A normal build leaves this metadata in .dart_tool; the ZIP step finds,
    # validates and adds it when the release folder does not already hold it.
    'native_assets.json'
)
foreach ($item in Get-ChildItem -LiteralPath $releasePath -Force) {
    if ($item.PSIsContainer) {
        if ($item.Name -ne 'data') { throw "Unexpected runtime directory: $($item.Name)" }
    } elseif ($item.Name -notin $allowedRootFiles) {
        # Anything not listed here has no reviewed notices in this package.
        throw "Unexpected runtime file (clean build required): $($item.Name)"
    }
}
$runtime = @(Get-ChildItem -LiteralPath $releasePath -Recurse -Force)
foreach ($item in $runtime) {
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Runtime contains a link: $($item.Name)"
    }
    if ($item.Name -match '^\.(git|vscode|idea|env)$|^board\.json|\.(pdb|dart|ps1|vasmim|freeform|key|pem)$') {
        throw "Private/development content in runtime: $($item.Name)"
    }
}
foreach ($item in $runtime | Where-Object { -not $_.PSIsContainer }) {
    $text = [System.Text.Encoding]::ASCII.GetString(
        [System.IO.File]::ReadAllBytes($item.FullName))
    if ($item.Name -eq 'super_native_extensions.dll') {
        # The pinned upstream Rust binary contains its public CI worker's
        # source paths. These are provenance, not this project's user data.
        $text = $text -replace '(?i)C:\\Users\\runneradmin\\\.cargo\\', 'upstream-ci/'
    }
    if ($text -match '(?i)file:///C:/Users/|[A-Z]:\\Users\\') {
        throw "A local user path remains in the runtime ($($item.Name)). Build from a neutral location and keep split debug information out of the package."
    }
}
$fingerprintText = (@($runtime | Where-Object { -not $_.PSIsContainer } |
    Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($releasePath.TrimEnd('\').Length + 1).Replace('\', '/')
        "$relative $((Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash)"
    })) -join "`n"
$hasher = [System.Security.Cryptography.SHA256]::Create()
try {
    $fingerprint = [BitConverter]::ToString($hasher.ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($fingerprintText))).Replace('-', '')
} finally { $hasher.Dispose() }

$documentNames = @('README.md', 'INSTALL.md', 'QUICK_START.md', 'KNOWN_LIMITATIONS.md',
    'PRIVACY.md', 'BUG_REPORTING.md', 'THIRD_PARTY_NOTICES.md', 'RELEASE_NOTES.md')
foreach ($name in $documentNames) {
    $document = Join-Path $documentsPath $name
    if (-not (Test-Path -LiteralPath $document -PathType Leaf)) { throw "Release document missing: $name" }
    if ((Get-Content -LiteralPath $document -Raw) -match
        '(?i)clearance pending|owner review required|not a published|no live support URL|awaiting final|private review') {
        throw "Draft text remains in public release document: $name"
    }
}
$applicationLicense = Join-Path $repositoryRoot 'LICENSE'
if (-not (Test-Path -LiteralPath $applicationLicense -PathType Leaf)) {
    throw 'The application LICENSE file is missing from the repository root.'
}

if (-not (Test-Path -LiteralPath $LicenseDirectory -PathType Container)) {
    throw 'Collected licence directory is missing.'
}
$licenseRoot = [System.IO.Path]::GetFullPath($LicenseDirectory).TrimEnd('\')
$collectedNotices = @(Get-ChildItem -LiteralPath $licenseRoot -Force -Recurse)
if (@($collectedNotices | Where-Object { -not $_.PSIsContainer }).Count -eq 0) {
    throw 'Collected licence directory is empty.'
}
foreach ($notice in $collectedNotices) {
    if (($notice.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'Licence directory must not contain links.'
    }
    $relativeNotice = $notice.FullName.Substring($licenseRoot.Length + 1).Replace('\', '/')
    if ($notice.PSIsContainer) {
        if ($relativeNotice -notin @('pdfium', 'pdfium/licenses')) {
            throw 'Unexpected licence subdirectory.'
        }
    } elseif ($relativeNotice -notmatch '^[^/]*(?i:LICENSE|LICENCE|COPYING|NOTICE)[^/]*$' -and
        $relativeNotice -notmatch '^pdfium/(LICENSE|VERSION|args\.gn|provenance\.json|package\.sha256|licenses/[a-zA-Z0-9_.-]+)$') {
        throw 'Licence directory contains an unreviewed file.'
    }
}

$stagingPath = Join-Path ([System.IO.Path]::GetTempPath()) ("vasmim-beta-stage-" + [guid]::NewGuid().ToString('N'))
$expectedStaging = [System.IO.Path]::GetFullPath($stagingPath)
New-Item -ItemType Directory -Path $stagingPath | Out-Null
try {
    foreach ($item in Get-ChildItem -LiteralPath $releasePath -Force) {
        Copy-Item -LiteralPath $item.FullName -Destination $stagingPath -Recurse
    }
    foreach ($name in $documentNames | Where-Object { $_ -ne 'RELEASE_NOTES.md' }) {
        Copy-Item -LiteralPath (Join-Path $documentsPath $name) -Destination (Join-Path $stagingPath $name)
    }
    Copy-Item -LiteralPath $applicationLicense -Destination (Join-Path $stagingPath 'LICENSE.txt')
    Copy-Item -LiteralPath $licenseRoot -Destination (Join-Path $stagingPath 'third_party_licenses') -Recurse
    & (Join-Path $PSScriptRoot 'package_windows_alpha.ps1') -SkipBuild `
        -ReleaseDirectory $stagingPath -OutputDirectory $outputPath `
        -ReleaseNotesPath (Join-Path $documentsPath 'RELEASE_NOTES.md')
    Write-Output "Runtime fingerprint: $fingerprint"
} finally {
    $resolvedStaging = [System.IO.Path]::GetFullPath($stagingPath)
    if ($resolvedStaging -ne $expectedStaging -or
        -not [System.IO.Path]::GetFileName($resolvedStaging).StartsWith('vasmim-beta-stage-')) {
        throw 'Safety stop: unexpected staging path.'
    }
    if (Test-Path -LiteralPath $resolvedStaging) { Remove-Item -LiteralPath $resolvedStaging -Recurse -Force }
}
