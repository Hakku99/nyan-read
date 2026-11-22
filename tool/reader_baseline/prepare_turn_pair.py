"""Generate a same-APK 05/08/13 comparison; fixtures remain outside Git."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
out = root / '.dart_tool/reader_baseline/turn-0813'
out.mkdir(parents=True, exist_ok=True)
for fmt in ('txt', 'epub', 'pdf'):
    source = subprocess.check_output(['git', 'show', f'3878caf:lib/modules/reader/reader_engine/{fmt}/{fmt}_reader.dart'], cwd=root).decode('utf-8')
    for old, new in {
        "'../../../../": "'package:nyan_read/",
        "'../../widgets/": "'package:nyan_read/modules/reader/widgets/",
        "'../reader_engine.dart'": "'package:nyan_read/modules/reader/reader_engine/reader_engine.dart'",
        "'../text_layout_anchor.dart'": "'package:nyan_read/modules/reader/reader_engine/text_layout_anchor.dart'",
        "'pagination_helper.dart'": "'package:nyan_read/modules/reader/reader_engine/txt/pagination_helper.dart'",
        "'txt_position.dart'": "'package:nyan_read/modules/reader/reader_engine/txt/txt_position.dart'",
        "'pdf_position.dart'": "'package:nyan_read/modules/reader/reader_engine/pdf/pdf_position.dart'",
        "'epub_parse_helpers.dart'": "'package:nyan_read/modules/reader/reader_engine/epub/epub_parse_helpers.dart'",
    }.items():
        source = source.replace(old, new)
    (out / f'reference_{fmt}.dart').write_text(source, encoding='utf-8')
smooth = subprocess.check_output(['git', 'show', '3878caf:lib/modules/reader/widgets/smooth_page_reader.dart'], cwd=root).decode('utf-8')
(out / 'reference_smooth.dart').write_text(smooth, encoding='utf-8')
phase = out / 'phase08_smooth.dart'
pilot = '--pilot' in sys.argv
if pilot and not phase.exists():
    raise SystemExit('Pilot requires the local item-08 checkpoint; final comparison does not.')
if phase.exists():
    phase.write_text(phase.read_text(encoding='utf-8').replace("'../reader_engine/page_turn_request.dart'", "'package:nyan_read/modules/reader/reader_engine/page_turn_request.dart'"), encoding='utf-8')
s = (root / 'tool/reader_baseline/profile_reader.dart').read_text(encoding='utf-8')
s = s.replace("Directory.systemTemp.createTemp('nyan_profile_')", "File(const String.fromEnvironment('BASELINE_TXT')).parent.createTemp('turn_fixture_')")
s = s.replace("import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';", """import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';
import 'package:nyan_read/modules/reader/reader_engine/page_turn_request.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_parse_helpers.dart';
import 'reference_txt.dart' as oldtxt;
import 'reference_epub.dart' as oldepub;
import 'reference_pdf.dart' as oldpdf;
import 'reference_smooth.dart' as old;
import 'phase08_smooth.dart' as phase08;""")
s = s.replace('class _ProfileReaderState extends State<_ProfileReader> {', '''class _ProfileReaderState extends State<_ProfileReader> {
  final _oldKey = GlobalKey<old.SmoothPageReaderState>();
  final _phaseKey = GlobalKey<phase08.SmoothPageReaderState>();
  String _variant = 'before';
  String _scene = 'normal';
  bool _snapshotIncoming = true;
  int _index = 0;
  int _round = 0;
  int _eventId = 0;
  final _phases = <Map<String, num>>[];
''')
s = s.replace('  WidgetsFlutterBinding.ensureInitialized();', '''  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    debugPrint('NYAN_PROFILE ${jsonEncode({'event': 'error', 'type': details.exception.runtimeType.toString()})}');
    FlutterError.presentError(details);
  };''', 1)
s = s.replace('final view = View.of(context);', 'while (View.of(context).physicalSize.isEmpty) { await _pause(100); } final view = View.of(context);')
a = s.index("      const smoke = bool.fromEnvironment('BASELINE_SMOKE');")
b = s.index("      _emit({'event': 'complete', 'failedScenarios': _failedScenarios});", a)
s = s[:a] + '''      const paths = {'txt': String.fromEnvironment('BASELINE_TXT'), 'epub': String.fromEnvironment('BASELINE_EPUB')};
      final imageIndex = await Isolate.run(() async {
        final parsed = await parseEpubFileInIsolate(paths['epub']!);
        for (var i = 1000; i < parsed.paragraphCount; i++) {
          if (parsed.paragraphKinds[i] == EpubParagraphKind.image) return i;
        }
        throw StateError('No image scene');
      });
      const pilot = bool.fromEnvironment('TURN_PILOT');
      for (_round = 0; _round < (pilot ? 1 : 3); _round++) {
        final scenes = <(String, String, int)>[
          ('txt', 'normal', 12544), ('epub', 'normal', 61007), ('pdf', 'normal', 10),
          if (!pilot) ...[('txt', 'long', 34455), ('epub', 'long', 149859), ('epub', 'image', imageIndex - 2)],
        ];
        for (final scene in scenes) {
          _scene = scene.$2;
          _index = scene.$3;
          final variants = pilot ? ['phase08', 'fixed'] : (_round.isEven ? ['before', 'fixed'] : ['fixed', 'before']);
          for (final variant in variants) {
            _variant = variant;
            await _recordScenario(scene.$1, paths[scene.$1] ?? generated['pdf']!, PageTurnMode.tap, external: scene.$1 != 'pdf');
          }
        }
      }
''' + s[b:]
s = s.replace("'txt' => TxtReaderEngine(book),", "'txt' => _variant == 'before' ? oldtxt.TxtReaderEngine(book) : TxtReaderEngine(book),").replace("'epub' => EpubReaderEngine(book),", "'epub' => _variant == 'before' ? oldepub.EpubReaderEngine(book) : EpubReaderEngine(book),").replace('_ => PdfReaderEngine(book),', "_ => _variant == 'before' ? oldpdf.PdfReaderEngine(book) : PdfReaderEngine(book),")
s = s.replace('paragraphIndex: external ? 12544 : 20, pageNumber: 10', 'paragraphIndex: _index, pageNumber: 10')
s = s.replace('    var dispatchedTurns = 0;', '''    var dispatchedTurns = 0;
    var forward = true;
    final trajectory = <String>[];
    final readiness = <bool>[];
    var measuring = false;
    Future<bool> ready(PageTurnRequest request) async {
      bool result = true;
      if (engine is PagePresentationCapability) {
        result = await (engine as PagePresentationCapability).waitForPagePresentation(request);
      } else {
        await SchedulerBinding.instance.endOfFrame;
      }
      if (measuring) readiness.add(result);
      return result;
    }''')
s = s.replace('    final previous = _engine;\n    setState', "    _snapshotIncoming = format != 'pdf';\n    _phases.clear();\n    final previous = _engine;\n    setState")
s = s.replace('      await engine.nextPage();', '      if (forward) { await engine.nextPage(); } else { await engine.previousPage(); }')
s = s.replace('''        await _smoothKey.currentState!
            .playTurn(forward: true, dispatchTurn: dispatch);''', '''        final before = engine.getCurrentPosition()?.toJson();
        final request = PageTurnRequest();
        if (_variant == 'before') {
          await _oldKey.currentState!.playTurn(forward: forward, dispatchTurn: dispatch);
        } else if (_variant == 'phase08') {
          await _phaseKey.currentState!.playTurn(forward: forward, dispatchTurn: dispatch,
            request: request, waitForReady: () => ready(request),
            didMove: () => engine.getCurrentPosition()?.toJson() != before);
        } else {
          await _smoothKey.currentState!.playTurn(forward: forward, dispatchTurn: dispatch,
            request: request, waitForReady: () => ready(request),
            didMove: () => engine.getCurrentPosition()?.toJson() != before);
        }''')
s = s.replace('final warmupTurns = smoke ? 1 : 5;', "final warmupTurns = _scene == 'image' ? 12 : 2;").replace('final measuredTurns = smoke ? 3 : 30;', 'final measuredTurns = smoke ? 3 : 12;')
s = s.replace('''      await turn();
      await _pause(150);''', '''      forward = _scene == 'image' ? i < warmupTurns ~/ 2 : i.isEven;
      await turn();
      await _pause(150);''')
s = s.replace('''    final frames = <FrameTiming>[];''', '''    final warmupPhases = List<Map<String, num>>.of(_phases);
    await engine.goToPosition(ReadingPosition(paragraphIndex: _index, pageNumber: 10));
    await _pause(1500);
    _phases.clear();
    measuring = true;
    final frames = <FrameTiming>[];''')
s = s.replace('''        final timer = Stopwatch()..start();''', '''        forward = i < measuredTurns ~/ 2;
        final timer = Stopwatch()..start();''')
s = s.replace('''        latency.add(timer.elapsedMicroseconds / 1000);''', '''        latency.add(timer.elapsedMicroseconds / 1000);
        trajectory.add(engine.getCurrentPosition()!.toJson());''')
s = s.replace("      'event': 'scenario',", """      'event': 'scenario',
      'implementation': _variant, 'scene': _scene, 'round': _round + 1,
      'trajectory': trajectory, 'readiness': readiness, 'phases': _phases,
      'warmupPhases': warmupPhases,
      'imageCacheBytes': PaintingBinding.instance.imageCache.currentSizeBytes,""")
s = s.replace("  void _emit(Map<String, Object> data) =>\n      debugPrint('NYAN_PROFILE ${jsonEncode(data)}');", """  void _emit(Map<String, Object> data) {
    final encoded = base64Encode(utf8.encode(jsonEncode(data)));
    final id = _eventId++;
    final count = (encoded.length / 600).ceil();
    for (var part = 0; part < count; part++) {
      debugPrint('NYAN_PROFILE ${jsonEncode({'event': 'chunk', 'id': id,
        'part': part, 'count': count, 'data': encoded.substring(part * 600, math.min((part + 1) * 600, encoded.length))})}');
    }
  }""")
s = s.replace('''              return _horizontal
                  ? SmoothPageReader(''', '''              if (_variant == 'before') {
                return old.SmoothPageReader(key: _oldKey,
                  onPreviousTap: () {}, onNextTap: () {}, onCenterTap: () {}, child: child);
              }
              if (_variant == 'phase08') {
                return phase08.SmoothPageReader(key: _phaseKey, onTurnMeasured: _phases.add,
                  onPreviousTap: () {}, onNextTap: () {}, onCenterTap: () {}, child: child);
              }
              return _horizontal
                  ? SmoothPageReader(onTurnMeasured: _phases.add, snapshotIncoming: _snapshotIncoming,''')
s = s.replace("const pilot = bool.fromEnvironment('TURN_PILOT');", f"const pilot = {'true' if pilot else 'false'};")
if not pilot:
    s = s.replace("import 'phase08_smooth.dart' as phase08;", '')
    s = s.replace('  final _phaseKey = GlobalKey<phase08.SmoothPageReaderState>();', '')
    a = s.index("        } else if (_variant == 'phase08') {")
    b = s.index('        } else {', a)
    s = s[:a] + s[b:]
    a = s.index("              if (_variant == 'phase08') {")
    b = s.index('              return _horizontal', a)
    s = s[:a] + s[b:]
(out / 'profile_pair.dart').write_text(s, encoding='utf-8')
print('Generated turn comparison target.')
