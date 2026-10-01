# Run from the DataSuite editor repository after the Windows build. Writes the update feed (latest.json per setup) and
# the GitHub release body (versions/release-body.md) for this version.
#   .\update-version.ps1                         the version is product.json's datasuiteVersion, the commit is HEAD
#   .\update-version.ps1 -ReleaseVersion 1.1.0   (then build with DATASUITE_VERSION=1.1.0 too, so the app knows it)
param(
    [string]$ReleaseVersion = $(if ($env:DATASUITE_VERSION) { $env:DATASUITE_VERSION } else { (Get-Content "product.json" -Raw | ConvertFrom-Json).datasuiteVersion }),
    [string]$BuildSourceVersion = $(git rev-parse HEAD)
)
if (-not $ReleaseVersion) { throw "No release version: pass -ReleaseVersion or set datasuiteVersion in product.json" }
$BaseUrl = "https://github.com/aphrcwaro/datasuite_public/releases/download/$ReleaseVersion"
$OutRoot = "versions/stable/win32/x64"

$SystemExe = Get-ChildItem ".build/win32-x64/system-setup/*.exe" | Select-Object -First 1
$UserExe   = Get-ChildItem ".build/win32-x64/user-setup/*.exe"   | Select-Object -First 1
$ZipFile   = Get-ChildItem "../*.zip" | Select-Object -First 1

function Get-Sha1Hex($path) {
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    $stream = [System.IO.File]::OpenRead($path)
    try {
        ($sha1.ComputeHash($stream) | ForEach-Object { $_.ToString("x2") }) -join ""
    } finally {
        $stream.Dispose()
        $sha1.Dispose()
    }
}

function Get-Sha256Hex($path) {
    return (Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
}

function Transform-Version($version) {
    # Split into numeric core and optional suffix, e.g.
    # 1.2.0-beta3 -> base=1.2.0, suffix=-beta3
    # 1.2.0-insider -> base=1.2.0, suffix=-insider
    if ($version -match '^(?<base>\d+\.\d+\.\d+)(?<suffix>-[0-9A-Za-z.-]+)?$') {
        $base = $Matches.base
        $suffix = $Matches.suffix
    } else {
        throw "Unsupported version format: $version"
    }

    $parts = $base.Split('.')

    # normalize patch segment
    $parts[2] = ([int]$parts[2]).ToString()

    # VSCodium-style productVersion uses 4 numeric parts
    $productVersion = "$($parts[0]).$($parts[1]).$($parts[2]).0"

    # keep prerelease suffix if you want it in JSON
    if ($suffix) {
        $productVersion += $suffix
    }

    return $productVersion
}

function Write-LatestJson($filePath, $subPath) {
    $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $fileName = Split-Path $filePath -Leaf

    $json = [ordered]@{
        url            = "$BaseUrl/$fileName"
        name           = $ReleaseVersion
        version        = $BuildSourceVersion
        productVersion = Transform-Version $ReleaseVersion
        hash           = Get-Sha1Hex $filePath
        timestamp      = $timestamp
        sha256hash     = Get-Sha256Hex $filePath
    }

    $targetDir = Join-Path $OutRoot $subPath
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    $json | ConvertTo-Json -Depth 3 | Set-Content -Encoding utf8 (Join-Path $targetDir "latest.json")
}

Write-LatestJson $SystemExe.FullName "system"
Write-LatestJson $UserExe.FullName   "user"
Write-LatestJson $ZipFile.FullName   "archive"

# The GitHub release body: it points to the version's release notes on the docs site, which the app also shows
# (Help > Show Release Notes). Publish that page first (see README.md), then:
#   gh release create <version> -R aphrcwaro/datasuite_public --title "DataSuite <version>" --notes-file versions/release-body.md <files>
$Docs = "https://datasuite.damurka.com"
$Body = @"
## DataSuite $ReleaseVersion

What's new in this version: **[release notes]($Docs/en/release-notes/$ReleaseVersion/)**
(also in [French]($Docs/fr/release-notes/$ReleaseVersion/) and [Portuguese]($Docs/pt/release-notes/$ReleaseVersion/)).

Download DataSuite from [datasuite.damurka.com]($Docs/en/downloads/), or update from the app: **Help** > **Check for Updates**.
"@
New-Item -ItemType Directory -Force -Path "versions" | Out-Null
$Body | Set-Content -Encoding utf8 "versions/release-body.md"
Write-Host "Release body written to versions/release-body.md"