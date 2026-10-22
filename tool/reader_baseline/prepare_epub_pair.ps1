param([string]$Reference = '8eef9ed')

# Keep the historical engine outside production and test source discovery.
$ErrorActionPreference = 'Stop'
$workspaceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Push-Location $workspaceRoot
try {
    $outputDirectory = Join-Path $workspaceRoot '.dart_tool/reader_baseline/epub-paired'
    New-Item -ItemType Directory -Force $outputDirectory | Out-Null
    $referenceSource = (& git show "${Reference}:lib/modules/reader/reader_engine/epub/epub_reader.dart") -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Could not read the reference engine.' }
    $referenceSource = $referenceSource.Replace("'../../../../", "'package:nyan_read/").
        Replace("'../../widgets/", "'package:nyan_read/modules/reader/widgets/").
        Replace("'../reader_engine.dart'", "'package:nyan_read/modules/reader/reader_engine/reader_engine.dart'").
        Replace("'epub_parse_helpers.dart'", "'package:nyan_read/modules/reader/reader_engine/epub/epub_parse_helpers.dart'")
    [IO.File]::WriteAllText((Join-Path $outputDirectory 'reference_epub.dart'), $referenceSource)
    $harness = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'profile_reader.dart')).Replace("`r`n", "`n")
    # This pair uses only the authorized file. Android may evict temporary
    # fixtures under storage pressure, so do not create unused cache inputs.
    $harness = $harness.Replace('final generated = await Isolate.run(_createSources);', 'const generated = <String, String>{};')
    $harness = $harness.Replace('if (sources != null) {', 'if (sources != null && sources.isNotEmpty) {')
    $import = "import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';"
    $harness = $harness.Replace($import, "$import`nimport 'reference_epub.dart' as reference;")
    $state = 'class _ProfileReaderState extends State<_ProfileReader> {'
    $harness = $harness.Replace($state, "$state`n  bool _reference = false;")
    $start = $harness.IndexOf("      const smoke = bool.fromEnvironment('BASELINE_SMOKE');")
    $end = $harness.IndexOf("      _emit({'event': 'complete', 'failedScenarios': _failedScenarios});", $start)
    if ($start -lt 0 -or $end -le $start) { throw 'Harness structure changed; review the generator.' }
    $pairedRun = @'
      const external = String.fromEnvironment('BASELINE_EPUB');
      for (final mode in [PageTurnMode.tap, PageTurnMode.swipe, PageTurnMode.disabled]) {
        for (final old in [true, false]) {
          _reference = old;
          await _recordScenario('epub', external, mode,
              external: true, continuousScroll: mode == PageTurnMode.disabled);
        }
      }
'@
    $harness = $harness.Substring(0, $start) + $pairedRun.Replace("`r`n", "`n") + "`n" + $harness.Substring($end)
    $harness = $harness.Replace("'epub' => EpubReaderEngine(book),", "'epub' => _reference ? reference.EpubReaderEngine(book) : EpubReaderEngine(book),")
    $harness = $harness.Replace('external ? 12544 : 20', "external ? const int.fromEnvironment('BASELINE_EPUB_INDEX', defaultValue: 61007) : 20")
    $harness = $harness.Replace("      'event': 'scenario',", "      'event': 'scenario',`n      'implementation': _reference ? 'before-03' : 'fixed-03',")
    [IO.File]::WriteAllText((Join-Path $outputDirectory 'profile_epub_pair.dart'), $harness)
    Write-Output 'Generated .dart_tool/reader_baseline/epub-paired/profile_epub_pair.dart'
} finally {
    Pop-Location
}
