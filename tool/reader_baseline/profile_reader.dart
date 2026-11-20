// Development-only entry point. Never use this target for a shipping build.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/core/theme/nyan_colors.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_reader.dart';
import 'package:nyan_read/modules/reader/reader_engine/pdf/pdf_reader.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';
import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kProfileMode && !kReleaseMode) {
    throw StateError('Run this target in profile or release mode.');
  }
  runApp(const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: _ProfileReader(),
  ));
}

// Fixture creation and all disk writes run outside the UI isolate.
Future<Map<String, String>> _createSources() async {
  final dir = await Directory.systemTemp.createTemp('nyan_profile_');
  final paragraphs = List.generate(1000,
      (i) => 'Paragraph $i. A quiet afternoon, a book, and time to read. ' * 4);
  final txt = File('${dir.path}/fixture.txt');
  await txt.writeAsString(paragraphs.join('\n'));
  final archive = Archive();
  void add(String name, String value) {
    final bytes = utf8.encode(value);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('mimetype', 'application/epub+zip');
  add('META-INF/container.xml',
      '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>');
  add('content.opf',
      '<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">profile</dc:identifier><dc:title>Profile</dc:title><dc:language>en</dc:language></metadata><manifest><item id="body" href="body.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="body"/></spine></package>');
  add('body.xhtml',
      '<html xmlns="http://www.w3.org/1999/xhtml"><body>${paragraphs.map((p) => '<p>$p</p>').join()}</body></html>');
  final epub = File('${dir.path}/fixture.epub');
  await epub.writeAsBytes(ZipEncoder().encode(archive));
  // Minimal text PDF exercises the real native renderer, without copyrighted
  // samples or a new dependency. It is not a scanned/image-heavy PDF workload.
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'
  ];
  final pages = <int>[];
  for (var i = 1; i <= 100; i++) {
    pages.add(objects.length + 1);
    final stream = 'BT /F1 20 Tf 40 700 Td (Baseline page $i) Tj ET';
    objects.add(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 800] /Resources << /Font << /F1 3 0 R >> >> /Contents ${objects.length + 2} 0 R >>');
    objects.add('<< /Length ${stream.length} >>\nstream\n$stream\nendstream');
  }
  objects[1] =
      '<< /Type /Pages /Count ${pages.length} /Kids [${pages.map((p) => '$p 0 R').join(' ')}] >>';
  final pdfData = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(pdfData.length);
    pdfData.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = pdfData.length;
  pdfData.write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    pdfData.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  pdfData.write(
      'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  final pdf = File('${dir.path}/fixture.pdf');
  await pdf.writeAsString(pdfData.toString());
  return {'txt': txt.path, 'epub': epub.path, 'pdf': pdf.path};
}

Future<void> _deleteSources(List<String> paths) async {
  for (final path in paths) {
    await File(path).delete();
  }
  await File(paths.first).parent.delete();
}

class _ProfileReader extends StatefulWidget {
  const _ProfileReader();
  @override
  State<_ProfileReader> createState() => _ProfileReaderState();
}

class _ProfileReaderState extends State<_ProfileReader> {
  final _smoothKey = GlobalKey<SmoothPageReaderState>();
  ReaderEngine? _engine;
  bool _horizontal = false;
  int _failedScenarios = 0;

  @override
  void initState() {
    super.initState();
    // The harness starts after layout, and reports any failure explicitly.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  Future<void> _pause(int milliseconds) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));

  Future<void> _run() async {
    Map<String, String>? sources;
    try {
      final generated = await Isolate.run(_createSources);
      sources = generated;
      if (!mounted) return;
      final view = View.of(context);
      _emit({
        'event': 'environment',
        'profile': kProfileMode,
        'physicalWidth': view.physicalSize.width,
        'physicalHeight': view.physicalSize.height,
        'dpr': view.devicePixelRatio,
        'refreshHz': view.display.refreshRate
      });
      const smoke = bool.fromEnvironment('BASELINE_SMOKE');
      for (final format in ['txt', 'epub', 'pdf']) {
        for (final mode in smoke
            ? [PageTurnMode.tap]
            : [PageTurnMode.tap, PageTurnMode.swipe]) {
          await _recordScenario(format, generated[format]!, mode);
        }
        if (!smoke && format != 'pdf') {
          await _recordScenario(
              format, generated[format]!, PageTurnMode.disabled,
              continuousScroll: true);
        }
      }
      const external = String.fromEnvironment('BASELINE_TXT');
      if (external.isNotEmpty) {
        for (final mode in [PageTurnMode.tap, PageTurnMode.swipe]) {
          await _recordScenario('txt', external, mode, external: true);
        }
        await _recordScenario('txt', external, PageTurnMode.disabled,
            external: true, continuousScroll: true);
      }
      _emit({'event': 'complete', 'failedScenarios': _failedScenarios});
    } catch (error, stack) {
      // Avoid logging user paths or content even when a source cannot open.
      _emit({
        'event': 'error',
        'type': error.runtimeType.toString(),
        'stack': stack.toString().split('\n').take(6).join('\n')
      });
    } finally {
      final previous = _engine;
      if (mounted) setState(() => _engine = null);
      await _pause(100);
      previous?.dispose();
      if (sources != null) {
        final paths = sources.values.toList();
        try {
          await compute(_deleteSources, paths);
        } catch (error) {
          _emit(
              {'event': 'cleanup-error', 'type': error.runtimeType.toString()});
        }
      }
    }
  }

  Future<void> _recordScenario(String format, String path, PageTurnMode mode,
      {bool external = false, bool continuousScroll = false}) async {
    try {
      await _scenario(format, path, mode,
          external: external, continuousScroll: continuousScroll);
    } catch (error, stack) {
      _failedScenarios++;
      _emit({
        'event': 'scenario-error',
        'format': format,
        'mode': mode.name,
        'source': external ? 'external' : 'synthetic',
        'interaction': continuousScroll ? 'relative-scroll' : 'page-turn',
        'type': error.runtimeType.toString(),
        'stack': stack.toString().split('\n').take(6).join('\n')
      });
    }
  }

  ScrollableState _verticalScrollable() {
    ScrollableState? found;
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        if (state.widget.axisDirection == AxisDirection.down) found ??= state;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found ?? (throw StateError('No vertical scrollable'));
  }

  Future<void> _scenario(String format, String path, PageTurnMode mode,
      {bool external = false, bool continuousScroll = false}) async {
    final previous = _engine;
    setState(() => _engine = null);
    await _pause(100);
    previous?.dispose();
    final book = Book(
        id: 'profile',
        title: 'Profile',
        author: '',
        filePath: path,
        format: format);
    final ReaderEngine engine = switch (format) {
      'txt' => TxtReaderEngine(book),
      'epub' => EpubReaderEngine(book),
      _ => PdfReaderEngine(book),
    };
    try {
      await engine.initialize();
    } catch (_) {
      engine.dispose();
      rethrow;
    }
    engine.setConfig(ReaderConfig(
        backgroundColor: NyanColors.creamBackground,
        textColor: NyanColors.creamTextMain,
        fontSize: 18,
        lineHeight: 1.5,
        pageTurnMode: mode));
    setState(() {
      _engine = engine;
      _horizontal = mode == PageTurnMode.tap;
    });
    await _pause(2000);
    for (var i = 0; engine.getCurrentPosition() == null && i < 100; i++) {
      await _pause(100);
    }
    if (engine.getCurrentPosition() == null) {
      throw StateError('Source not ready');
    }
    await engine.goToPosition(
        ReadingPosition(paragraphIndex: external ? 12544 : 20, pageNumber: 10));
    await _pause(500);
    var dispatchedTurns = 0;
    Future<void> dispatch() async {
      dispatchedTurns++;
      await engine.nextPage();
    }

    Future<void> turn() async {
      if (continuousScroll) {
        final position = _verticalScrollable().position;
        await position.animateTo(
            position.pixels + position.viewportDimension * .92,
            duration: const Duration(milliseconds: 300),
            curve: Curves.linear);
      } else if (_horizontal) {
        await _smoothKey.currentState!
            .playTurn(forward: true, dispatchTurn: dispatch);
      } else {
        await dispatch();
      }
      await SchedulerBinding.instance.endOfFrame;
    }

    const smoke = bool.fromEnvironment('BASELINE_SMOKE');
    final warmupTurns = smoke ? 1 : 5;
    final measuredTurns = smoke ? 3 : 30;
    for (var i = 0; i < warmupTurns; i++) {
      await turn();
      await _pause(150);
    }
    // FrameTiming delivery can be batched for about a second in profile mode.
    await _pause(1500);
    final frames = <FrameTiming>[];
    void collect(List<FrameTiming> timings) => frames.addAll(timings);
    final latency = <double>[];
    final rssBefore = ProcessInfo.currentRss;
    SchedulerBinding.instance.addTimingsCallback(collect);
    try {
      for (var i = 0; i < measuredTurns; i++) {
        final timer = Stopwatch()..start();
        await turn();
        latency.add(timer.elapsedMicroseconds / 1000);
        await _pause(150);
      }
      await _pause(1500);
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(collect);
    }
    if (!mounted) return;
    final budget = 1000 / View.of(context).display.refreshRate;
    _emit({
      'event': 'scenario',
      'format': format,
      'mode': mode.name,
      'source': external ? 'external' : 'synthetic',
      'interaction': continuousScroll ? 'relative-scroll' : 'page-turn',
      'warmupTurns': warmupTurns,
      'measuredTurns': measuredTurns,
      'dispatchedTurns': dispatchedTurns,
      'frames': frames.length,
      'budgetMs': budget,
      'buildMs':
          _stats(frames.map((f) => f.buildDuration.inMicroseconds / 1000)),
      'rasterMs':
          _stats(frames.map((f) => f.rasterDuration.inMicroseconds / 1000)),
      'overBudgetFrames': frames
          .where((f) =>
              math.max(f.buildDuration.inMicroseconds,
                      f.rasterDuration.inMicroseconds) /
                  1000 >
              budget)
          .length,
      'completionMs': _stats(latency),
      'rssBeforeBytes': rssBefore,
      'rssAfterBytes': ProcessInfo.currentRss
    });
  }

  Map<String, double> _stats(Iterable<double> input) {
    final values = input.toList()..sort();
    if (values.isEmpty) throw StateError('No samples');
    double percentile(double p) => values[(values.length * p).ceil() - 1];
    return {
      'p50': percentile(.5),
      'p95': percentile(.95),
      'p99': percentile(.99),
      'max': values.last
    };
  }

  void _emit(Map<String, Object> data) =>
      debugPrint('NYAN_PROFILE ${jsonEncode(data)}');

  @override
  Widget build(BuildContext context) => Scaffold(
      body: _engine == null
          ? const SizedBox.shrink()
          : Builder(builder: (context) {
              final child = _engine!.buildReader(context);
              return _horizontal
                  ? SmoothPageReader(
                      key: _smoothKey,
                      onPreviousTap: () {},
                      onNextTap: () {},
                      onCenterTap: () {},
                      child: child)
                  : child;
            }));
}
