$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot -Parent
Set-Location (Join-Path $Repo 'app')
flutter pub get --enforce-lockfile
if ($LASTEXITCODE -ne 0) { throw 'Lockfile mismatch' }
flutter build apk --release --target-platform android-arm64 --split-per-abi
if ($LASTEXITCODE -ne 0) { throw 'APK build failed' }
New-Item -ItemType Directory -Force (Join-Path $Repo 'dist') | Out-Null
$VersionLine = Get-Content (Join-Path $Repo 'app/pubspec.yaml') | Where-Object { $_ -match '^version:' } | Select-Object -First 1
if ($VersionLine -notmatch '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') { throw 'Cannot read app version' }
$Output = Join-Path $Repo "dist/icd-offline-$($Matches[1])-android-arm64-demo.apk"
if (Test-Path $Output) { throw 'Existing APK preserved; choose a new version' }
Copy-Item 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk' $Output
$Hash = (Get-FileHash -Algorithm SHA256 $Output).Hash.ToLowerInvariant()
"$Hash  $([System.IO.Path]::GetFileName($Output))" | Set-Content -Encoding ascii "$Output.sha256"
