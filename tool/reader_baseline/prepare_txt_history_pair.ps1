param(
    [string]$Reference = '27e79a8'
)

# Generate an ignored benchmark target containing both engines. Production
# sources stay untouched, and no historical implementation is shipped.
$ErrorActionPreference = 'Stop'
$workspaceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Push-Location $workspaceRoot
try {
    $outputDirectory = Join-Path $workspaceRoot '.dart_tool/reader_baseline/txt-history-paired'
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
    # Use app-private files for the sample; no unused cache fixtures.
    $harness = $harness.Replace('final generated = await Isolate.run(_createSources);', 'const generated = <String, String>{};')
    $harness = $harness.Replace('if (sources != null) {', 'if (sources != null && sources.isNotEmpty) {')
    $harness = $harness.Replace('final view = View.of(context);', 'while (View.of(context).physicalSize.isEmpty) { await _pause(100); } final view = View.of(context);')
    $import = "import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';"
    $harness = $harness.Replace($import, "$import`nimport 'reference_txt.dart' as reference;")
    $state = 'class _ProfileReaderState extends State<_ProfileReader> {'
    $harness = $harness.Replace($state, "$state`n  bool _reference = false;")
    $start = $harness.IndexOf("      const smoke = bool.fromEnvironment('BASELINE_SMOKE');")
    $end = $harness.IndexOf("      _emit({'event': 'complete', 'failedScenarios': _failedScenarios});", $start)
    if ($start -lt 0 -or $end -le $start) { throw 'Harness structure changed; review the generator.' }
    $pairedRun = @'
      const external = String.fromEnvironment('BASELINE_TXT');
      for (final mode in [PageTurnMode.tap, PageTurnMode.swipe, PageTurnMode.disabled]) {
        for (final old in [true, false]) {
          _reference = old;
          await _recordScenario('txt', external, mode,
              external: true, continuousScroll: mode == PageTurnMode.disabled);
        }
      }
'@
    $harness = $harness.Substring(0, $start) + $pairedRun.Replace("`r`n", "`n") + "`n" + $harness.Substring($end)
    $harness = $harness.Replace("'txt' => TxtReaderEngine(book),", "'txt' => _reference ? reference.TxtReaderEngine(book) : TxtReaderEngine(book),")
    $harness = $harness.Replace("      'event': 'scenario',", "      'event': 'scenario',`n      'implementation': _reference ? 'before-04' : 'fixed-04',")
    [IO.File]::WriteAllText((Join-Path $outputDirectory 'profile_pair.dart'), $harness)
    Write-Output 'Generated .dart_tool/reader_baseline/txt-history-paired/profile_pair.dart'
} finally {
    Pop-Location
}
