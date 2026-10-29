$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$Python = Join-Path $PWD '.venv313/Scripts/python.exe'
if (!(Test-Path $Python)) { throw 'Create .venv313 and install requirements.lock as described in README first' }
& $Python -m pytest tools/data_builder/tests -q
if ($LASTEXITCODE -ne 0) { throw 'Python tests failed' }
Push-Location app
try {
    flutter pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Dependency lock mismatch' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Analyze failed' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed' }
} finally { Pop-Location }
