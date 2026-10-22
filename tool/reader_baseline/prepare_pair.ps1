param(
    [string]$Reference = 'c41869fab15a49b402a5530e8e37760289a0f122'
)

# Generate an ignored benchmark target containing both engines. Production
# sources stay untouched, and no historical implementation is shipped.
$ErrorActionPreference = 'Stop'
$workspaceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Push-Location $workspaceRoot
try {
    $outputDirectory = Join-Path $workspaceRoot '.dart_tool/reader_baseline/paired'
    New-Item -ItemType Directory -Force $outputDirectory | Out-Null
    $referenceSource = (& git show "${Reference}:lib/modules/reader/reader_engine/txt/txt_reader.dart") -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Could not read the reference engine.' }
    $referenceSource = $referenceSource.Replace("'../../../../", "'package:nyan_read/").
        Replace("'../../widgets/", "'package:nyan_read/modules/reader/widgets/").
        Replace("'../reader_engine.dart'", "'package:nyan_read/modules/reader/reader_engine/reader_engine.dart'").
        Replace("'pagination_helper.dart'", "'package:nyan_read/modules/reader/reader_engine/txt/pagination_helper.dart'").
        Replace("'txt_position.dart'", "'package:nyan_read/modules/reader/reader_engine/txt/txt_position.dart'")
    [IO.File]::WriteAllText((Join-Path $outputDirectory 'reference_txt.dart'), $referenceSource)

    $harness = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'profile_reader.dart')).Replace("`r`n", "`n")
    $import = "import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';"
    $harness = $harness.Replace($import, "$import`nimport 'reference_txt.dart' as reference;")
    $state = 'class _ProfileReaderState extends State<_ProfileReader> {'
    $harness = $harness.Replace($state, "$state`n  bool _reference = false;")
    $start = $harness.IndexOf("      const smoke = bool.fromEnvironment('BASELINE_SMOKE');")
    $end = $harness.IndexOf("      _emit({'event': 'complete', 'failedScenarios': _failedScenarios});", $start)
    if ($start -lt 0 -or $end -le $start) { throw 'Harness structure changed; review the generator.' }
    $pairedRun = @'
      const external = String.fromEnvironment('BASELINE_TXT');
      for (final caseId in [0, 1, 2]) {
        const order = bool.fromEnvironment('PAIR_NEW_FIRST');
        for (final old in [!order, order]) {
          _reference = old;
          await _recordScenario('txt', caseId == 0 ? generated['txt']! : external,
              caseId == 2 ? PageTurnMode.disabled : PageTurnMode.swipe,
              external: caseId != 0, continuousScroll: caseId == 2);
        }
      }
'@
    $harness = $harness.Substring(0, $start) + $pairedRun.Replace("`r`n", "`n") + "`n" + $harness.Substring($end)
    $harness = $harness.Replace("'txt' => TxtReaderEngine(book),", "'txt' => _reference ? reference.TxtReaderEngine(book) : TxtReaderEngine(book),")
    $harness = $harness.Replace("      'event': 'scenario',", "      'event': 'scenario',`n      'implementation': _reference ? 'main-reference' : 'fixed',")
    [IO.File]::WriteAllText((Join-Path $outputDirectory 'profile_pair.dart'), $harness)
    Write-Output 'Generated .dart_tool/reader_baseline/paired/profile_pair.dart'
} finally {
    Pop-Location
}
