"""Generate a paired 04/05 profile target; no book contents enter the repository."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[2]
out = root / '.dart_tool/reader_baseline/reflow-paired'
out.mkdir(parents=True, exist_ok=True)
for fmt in ('txt', 'epub'):
    source = subprocess.check_output(['git', 'show', f'0404233:lib/modules/reader/reader_engine/{fmt}/{fmt}_reader.dart'], cwd=root).decode('utf-8')
    for old, new in {
        "'../../../../": "'package:nyan_read/",
        "'../../widgets/": "'package:nyan_read/modules/reader/widgets/",
        "'../reader_engine.dart'": "'package:nyan_read/modules/reader/reader_engine/reader_engine.dart'",
        "'pagination_helper.dart'": "'package:nyan_read/modules/reader/reader_engine/txt/pagination_helper.dart'",
        "'txt_position.dart'": "'package:nyan_read/modules/reader/reader_engine/txt/txt_position.dart'",
        "'epub_parse_helpers.dart'": "'package:nyan_read/modules/reader/reader_engine/epub/epub_parse_helpers.dart'",
    }.items():
        source = source.replace(old, new)
    (out / f'reference_{fmt}.dart').write_text(source, encoding='utf-8')
smooth = subprocess.check_output(['git', 'show', '0404233:lib/modules/reader/widgets/smooth_page_reader.dart'], cwd=root).decode('utf-8')
(out / 'reference_smooth.dart').write_text(smooth, encoding='utf-8')
s = (root / 'tool/reader_baseline/profile_reader.dart').read_text(encoding='utf-8')
s = s.replace("import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';", """import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';
import 'package:nyan_read/modules/reader/reader_engine/text_layout_anchor.dart';
import 'reference_txt.dart' as oldtxt;
import 'reference_epub.dart' as oldepub;
import 'reference_smooth.dart' as oldsmooth;""")
s = s.replace('class _ProfileReaderState extends State<_ProfileReader> {', '''class _ProfileReaderState extends State<_ProfileReader> {
  final _oldSmoothKey = GlobalKey<oldsmooth.SmoothPageReaderState>();
  bool _reference = false;
  String _operation = 'turn';
  bool _covered() {
    var result = false;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is RestoreVisibility && widget.covered.value) result = true;
      element.visitChildren(visit);
    }
    context.visitChildElements(visit);
    return result;
  }
''')
s = s.replace('  WidgetsFlutterBinding.ensureInitialized();', """  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    debugPrint('NYAN_PROFILE ${jsonEncode({'event': 'error', 'type': details.exception.runtimeType.toString()})}');
    FlutterError.presentError(details);
  };""", 1)
s = s.replace('final generated = await Isolate.run(_createSources);' , 'const generated = <String, String>{};').replace('if (sources != null) {', 'if (sources != null && sources.isNotEmpty) {')
s = s.replace('final view = View.of(context);', 'while (View.of(context).physicalSize.isEmpty) { await _pause(100); } final view = View.of(context);')
a = s.index("      const smoke = bool.fromEnvironment('BASELINE_SMOKE');")
b = s.index("      _emit({'event': 'complete', 'failedScenarios': _failedScenarios});", a)
s = s[:a] + '''      const paths = {'txt': String.fromEnvironment('BASELINE_TXT'), 'epub': String.fromEnvironment('BASELINE_EPUB')};
      for (final format in paths.keys) {
        for (final operation in ['turn', 'mode', 'typography']) {
          _operation = operation;
          for (final mode in operation == 'turn' ? PageTurnMode.values : [PageTurnMode.swipe]) {
            for (final old in [true, false]) {
              _reference = old;
              await _recordScenario(format, paths[format]!, mode, external: true,
                  continuousScroll: operation == 'turn' && mode == PageTurnMode.disabled);
            }
          }
        }
      }
''' + s[b:]
s = s.replace("'txt' => TxtReaderEngine(book),", "'txt' => _reference ? oldtxt.TxtReaderEngine(book) : TxtReaderEngine(book),").replace("'epub' => EpubReaderEngine(book),", "'epub' => _reference ? oldepub.EpubReaderEngine(book) : EpubReaderEngine(book),")
s = s.replace('external ? 12544 : 20', "format == 'txt' ? (_operation == 'turn' ? 12544 : 34455) : (_operation == 'turn' ? 61007 : 149859)")
s = s.replace('    var dispatchedTurns = 0;', '''    if (_operation != 'turn') {
      await engine.nextPage();
      await _pause(300);
    }
    var operationStep = 0;
    final original = engine.getCurrentPosition();
    var dispatchedTurns = 0;''')
s = s.replace('''      if (continuousScroll) {''', '''      if (_operation != 'turn') {
        final even = operationStep++ % 2 == 0;
        final nextMode = _operation == 'mode' && even ? PageTurnMode.tap : PageTurnMode.swipe;
        engine.setConfig(ReaderConfig(
          backgroundColor: NyanColors.readerPaperDefault,
          textColor: NyanColors.readerInkDefault,
          fontSize: _operation == 'typography' && even ? 26 : 18,
          lineHeight: _operation == 'typography' && even ? 1.8 : 1.5,
          useSerif: _operation == 'typography' && even,
          pageTurnMode: nextMode));
        setState(() => _horizontal = nextMode == PageTurnMode.tap);
        // Common observation boundary: two committed frames, plus pending restore.
        await SchedulerBinding.instance.endOfFrame;
        await SchedulerBinding.instance.endOfFrame;
        var frames = 0;
        while (_covered() && frames++ < 30) {
          await SchedulerBinding.instance.endOfFrame;
        }
        if (_covered()) throw StateError('Restore failed to settle');
      } else if (continuousScroll) {''',1)
s = s.replace("      'event': 'scenario',", """      'event': 'scenario',
      'implementation': _reference ? 'before-05' : 'fixed-05',
      'operation': _operation,
      'anchorRetained': original?.textOffset != null && original?.textOffset == engine.getCurrentPosition()?.textOffset,""")
s = s.replace('return _horizontal\n                  ? SmoothPageReader(', '''if (_reference) {
                return _horizontal ? oldsmooth.SmoothPageReader(
                  key: _oldSmoothKey, onPreviousTap: () {}, onNextTap: () {},
                  onCenterTap: () {}, child: child) : child;
              }
              return true
                  ? SmoothPageReader(enabled: _horizontal,''')
s = s.replace('''        await _smoothKey.currentState!
            .playTurn(forward: true, dispatchTurn: dispatch);''', '''        if (_reference) {
          await _oldSmoothKey.currentState!.playTurn(forward: true, dispatchTurn: dispatch);
        } else {
          await _smoothKey.currentState!.playTurn(forward: true, dispatchTurn: dispatch);
        }''')
(out / 'profile_pair.dart').write_text(s, encoding='utf-8')
print('Generated paired reflow target.')
