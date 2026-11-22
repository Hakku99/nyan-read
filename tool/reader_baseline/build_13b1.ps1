param([ValidateSet('A', 'B')][string]$Variant,
      [string]$CandidateFile,
      [string]$OutputDirectory = '.dart_tool/perf13b1',
      [string]$Flutter = 'C:\flutter\bin\flutter.bat')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$output = Join-Path $root $OutputDirectory
$prepareArgs = @((Join-Path $PSScriptRoot 'prepare_13b1.py'), '--variant', $Variant, '--output', $output)
if ($CandidateFile) { $prepareArgs += @('--candidate-file', $CandidateFile) }
python @prepareArgs
if ($LASTEXITCODE -ne 0) { throw 'Preparation failed' }
$digest = (Get-FileHash (Join-Path $output "manifest-$Variant.json") -Algorithm SHA256).Hash
Push-Location (Join-Path $output 'project')
try {
    & $Flutter pub get --offline *> (Join-Path $output "dependencies-$Variant.log")
    if ($LASTEXITCODE -ne 0) { throw 'Dependencies failed' }
    & $Flutter build apk --profile --no-pub --target lib/perf13a_main.dart --target-platform android-x64 "--dart-define=PERF13A_VARIANT=$Variant" "--dart-define=PERF13A_SOURCE_HASH=$digest" *> (Join-Path $output "build-$Variant.log")
    if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
    Copy-Item build/app/outputs/flutter-apk/app-profile.apk (Join-Path $output "$Variant.apk")
} finally { Pop-Location }
