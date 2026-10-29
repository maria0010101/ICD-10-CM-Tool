$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot -Parent
Set-Location (Join-Path $Repo 'app')
flutter pub get --enforce-lockfile
if ($LASTEXITCODE -ne 0) { throw 'Lockfile mismatch' }
flutter build apk --release --target-platform android-arm64 --split-per-abi
if ($LASTEXITCODE -ne 0) { throw 'APK build failed' }
New-Item -ItemType Directory -Force (Join-Path $Repo 'dist') | Out-Null
$Output = Join-Path $Repo 'dist/icd-offline-0.1.1-android-arm64-demo.apk'
if (Test-Path $Output) { throw 'Existing APK preserved; choose a new version' }
Copy-Item 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk' $Output
Get-FileHash -Algorithm SHA256 $Output | Format-List | Out-File (Join-Path $Repo 'dist/android.sha256')
