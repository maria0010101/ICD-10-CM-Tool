# Run on Windows x64 with Flutter 3.47.5 and Visual Studio Desktop C++.
param([string]$VCRuntimeDir = '')
$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo
if ($env:OS -ne 'Windows_NT') { throw 'Windows executable builds require a Windows host' }
$VersionLine = Get-Content (Join-Path $Repo 'app/pubspec.yaml') | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1
if ($VersionLine -notmatch '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') { throw 'Cannot read app version' }
$Version = $Matches[1]
$Dist = Join-Path $Repo 'dist'
New-Item -ItemType Directory -Force $Dist | Out-Null
$Zip = Join-Path $Dist "icd-offline-$Version-windows-x64-demo.zip"
if (Test-Path $Zip) { throw "Existing release preserved: $Zip" }
# Find only the official installed Visual Studio redistributable, never System32.
if (!$VCRuntimeDir) {
    $Vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (!(Test-Path $Vswhere)) { throw 'Visual Studio installer/vswhere missing; install Desktop development with C++' }
    $Vs = & $Vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (!$Vs) { throw 'Visual Studio C++ toolchain missing' }
    $Candidates = Get-ChildItem -Path (Join-Path $Vs 'VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT') -Directory -ErrorAction SilentlyContinue | Sort-Object FullName -Descending
    if ($Candidates) { $VCRuntimeDir = $Candidates[0].FullName }
}
if (!$VCRuntimeDir -or !(Test-Path (Join-Path $VCRuntimeDir 'vcruntime140.dll'))) {
    throw 'Supply -VCRuntimeDir with licensed Microsoft CRT redistributables; publication stopped'
}
Push-Location (Join-Path $Repo 'app')
try {
    flutter pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed' }
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed' }
    $Bundle = Join-Path $PWD 'build/windows/x64/runner/Release'
    foreach ($Required in @('icd_dictionary.exe','flutter_windows.dll','data/icudtl.dat','data/flutter_assets')) {
        if (!(Test-Path (Join-Path $Bundle $Required))) { throw "Missing runtime artifact: $Required" }
    }
    Copy-Item (Join-Path $VCRuntimeDir '*.dll') $Bundle
    Copy-Item (Join-Path $Repo 'LICENSES.md') (Join-Path $Bundle 'LICENSES.md')
    Compress-Archive -Path (Join-Path $Bundle '*') -DestinationPath $Zip
    $Hash = (Get-FileHash -Algorithm SHA256 $Zip).Hash.ToLowerInvariant()
    "$Hash  $([System.IO.Path]::GetFileName($Zip))" | Set-Content -Encoding ascii "$Zip.sha256"
    Write-Host "Built actual portable ZIP: $Zip"
    Write-Host 'Unzip on a clean Windows x64 workstation and manually test; build success is not runtime acceptance.'
} finally { Pop-Location }
