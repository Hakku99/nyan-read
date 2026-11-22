param(
    [string]$TxtSample,
    [string]$OutputDirectory = '.dart_tool/reader_baseline'
)
$ErrorActionPreference = 'Stop'
$workspaceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Push-Location $workspaceRoot
$previousSample = $env:NYAN_BASELINE_TXT
try {
    $outputPath = [IO.Path]::GetFullPath((Join-Path $workspaceRoot $OutputDirectory))
    if (-not $outputPath.StartsWith($workspaceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Baseline output must stay inside the workspace.'
    }
    New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
    $env:NYAN_BASELINE_TXT = $null
    & flutter test --no-pub tool/reader_baseline/navigation_baseline_test.dart tool/reader_baseline/pdf_loading_baseline_test.dart tool/reader_baseline/list_offset_contract_test.dart --reporter json > (Join-Path $outputPath 'synthetic.jsonl')
    $syntheticExit = $LASTEXITCODE
    $externalExit = $null
    if ($TxtSample) {
        $resolvedSample = (Resolve-Path -LiteralPath $TxtSample).Path
        $env:NYAN_BASELINE_TXT = $resolvedSample
        & flutter test --no-pub tool/reader_baseline/navigation_baseline_test.dart --plain-name 'external/' --reporter json > (Join-Path $outputPath 'external.jsonl')
        $externalExit = $LASTEXITCODE
    }
    $summary = [ordered]@{
        capturedAt = (Get-Date).ToUniversalTime().ToString('o')
        syntheticExitCode = $syntheticExit
        externalExitCode = $externalExit
        externalSampleIncluded = [bool]$TxtSample
        note = 'Nonzero test exits remain failures. This baseline deliberately does not bless known defects.'
    }
    $summary | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputPath 'run.json') -Encoding utf8
    $summary | ConvertTo-Json
    if ($syntheticExit -ne 0 -or ($null -ne $externalExit -and $externalExit -ne 0)) { exit 1 }
} finally {
    $env:NYAN_BASELINE_TXT = $previousSample
    Pop-Location
}
