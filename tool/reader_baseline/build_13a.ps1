param([ValidateSet('A', 'B')][string]$Variant,
      [switch]$InputAudit,
      [string]$Flutter = 'C:\flutter\bin\flutter.bat')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$output = Join-Path $root '.dart_tool/perf13a'
$prepareArgs = @((Join-Path $PSScriptRoot 'prepare_13a.py'), '--variant', $Variant)
if ($InputAudit) { $prepareArgs += '--input-audit' }
python @prepareArgs
if ($LASTEXITCODE -ne 0) { throw 'Source preparation failed.' }
$tag = if ($InputAudit) { "input-$Variant" } else { $Variant }
$digest = (Get-FileHash (Join-Path $output "manifest-$tag.json") -Algorithm SHA256).Hash
Push-Location (Join-Path $output 'project')
try {
    # Distinct source identifiers force Flutter/Gradle to invalidate old AOT
    # artifacts; a successful incremental command alone is insufficient proof.
    & $Flutter pub get --offline *> (Join-Path $output "dependencies-$Variant.log")
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
    & $Flutter build apk --profile --no-pub --target lib/perf13a_main.dart --target-platform android-x64 "--dart-define=PERF13A_VARIANT=$Variant" "--dart-define=PERF13A_SOURCE_HASH=$digest" *> (Join-Path $output "build-$tag.log")
    if ($LASTEXITCODE -ne 0) { throw 'Profile build failed.' }
    Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-profile.apk' -Destination (Join-Path $output "$tag.apk")
    Get-FileHash (Join-Path $output "$tag.apk") -Algorithm SHA256
} finally { Pop-Location }
