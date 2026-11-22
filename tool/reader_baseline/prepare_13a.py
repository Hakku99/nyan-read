"""Build disposable source trees with a pinned baseline and frozen candidate."""
import argparse
import hashlib
import io
import json
import re
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / '.dart_tool/perf13a'
BASE = 'ae5a630'
FILES = ['lib/modules/reader/widgets/smooth_page_reader.dart',
         'lib/modules/reader/reader_page.dart']


def sha(data):
    return hashlib.sha256(data).hexdigest()


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError(f'Instrumentation anchor changed: {old[:70]}')
    return source.replace(old, new)


def instrument(source):
    source = "import 'package:nyan_read/perf13a_trace.dart';\n" + source
    hooks = {
        '    final turn = request ?? PageTurnRequest();': "    PerfTrace.mark('accepted');\n    final turn = request ?? PageTurnRequest();",
        '      _outgoingImage = await _captureFor(turn);': "      PerfTrace.mark('captureOld');\n      _outgoingImage = await _captureFor(turn);\n      PerfTrace.mark('coverOld');",
        '      final dispatched = Future<void>.sync(dispatchTurn);': "      PerfTrace.mark('navigate');\n      final dispatched = Future<void>.sync(dispatchTurn);",
        '      bool ready;': "      PerfTrace.mark('ready');\n      bool ready;",
        "      metrics['readyMs'] = phase.elapsedMicroseconds / 1000;": "      PerfTrace.mark('readyFrame');\n      metrics['readyMs'] = phase.elapsedMicroseconds / 1000;",
        '      _controller.value = 0;': "      PerfTrace.mark('motion');\n      _controller.value = 0;",
        "      metrics['animationMs'] = phase.elapsedMicroseconds / 1000;": "      PerfTrace.mark('finishMotion');\n      metrics['animationMs'] = phase.elapsedMicroseconds / 1000;",
        '      turn.cancel();': "      PerfTrace.mark('release');\n      turn.cancel();",
        '      if (mounted) setState(() {});': "      if (mounted) setState(() {});\n      PerfTrace.mark('revealScheduled');",
    }
    for old, new in hooks.items():
        source = replace_once(source, old, new)
    incoming_calls = re.findall(r'        _incomingImage = await _captureFor\(turn(?:, frameReady: true)?\);', source)
    if len(incoming_calls) > 1:
        raise ValueError('Ambiguous incoming capture instrumentation')
    if not incoming_calls and '_incomingImage = await' in source:
        raise ValueError('Unrecognized incoming capture instrumentation')
    if incoming_calls:
        source = replace_once(source, incoming_calls[0], "        PerfTrace.mark('captureNew');\n" + incoming_calls[0])
    incoming = '_incomingImage' if '_incomingImage' in source else 'null'
    source = source.replace("      PerfTrace.mark('release');", f"      PerfTrace.resources(_outgoingImage, {incoming}, _capturePending);\n      PerfTrace.mark('release');")
    source = source.replace("      PerfTrace.mark('revealScheduled');", f"      PerfTrace.resources(_outgoingImage, {incoming}, _capturePending);\n      PerfTrace.mark('revealScheduled');")
    # A render-frame identifier lets the collector join motion ticks to actual
    # timings without interpreting delayed timing-callback delivery as paint.
    source = replace_once(source, '              final t = widget.curve.transform(_controller.value);',
                          "              PerfTrace.motion(_controller.value, _preparing, _outgoingImage != null);\n              final t = widget.curve.transform(_controller.value);")
    return source


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--freeze', action='store_true')
    parser.add_argument('--variant', choices=['A', 'B'], default='A')
    parser.add_argument('--input-audit', action='store_true')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    commit = subprocess.check_output(['git', 'rev-parse', BASE], cwd=ROOT).decode().strip()
    patch = subprocess.check_output(['git', 'diff', BASE, '--', *FILES], cwd=ROOT)
    manifest_path = OUT / 'frozen.json'
    if args.freeze:
        if manifest_path.exists():
            raise ValueError('Frozen run already exists; use its manifest or a new run directory')
        (OUT / 'candidate.patch').write_bytes(patch)
        manifest_path.write_text(json.dumps({'base': commit, 'patchSha256': sha(patch),
            'files': {p: sha((ROOT / p).read_bytes()) for p in FILES}}, indent=2), encoding='utf-8')
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    if manifest['base'] != commit or manifest['patchSha256'] != sha(patch):
        raise ValueError('Candidate drift')
    for path, digest in manifest['files'].items():
        if sha((ROOT / path).read_bytes()) != digest:
            raise ValueError(f'Candidate drift: {path}')
    project = OUT / 'project'
    project.mkdir(exist_ok=True)
    # Archive only tracked sources; private books and local databases never enter
    # the test project. Assets are copied separately because fonts are untracked.
    archive = subprocess.check_output(['git', 'archive', '--format=zip', BASE,
        'lib', 'android', 'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml'], cwd=ROOT)
    with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
        bundle.extractall(project)
    if not args.input_audit:
        (project / 'lib/perf13a_input_audit.dart').unlink(missing_ok=True)
    shutil.copytree(ROOT / 'assets', project / 'assets', dirs_exist_ok=True)
    shutil.copy2(ROOT / 'android/local.properties', project / 'android/local.properties')
    if args.variant == 'B':
        subprocess.run(['git', 'apply', '--directory=.dart_tool/perf13a/project', str(OUT / 'candidate.patch')], cwd=ROOT, check=True)
    gradle = project / 'android/app/build.gradle.kts'
    gradle.write_text(replace_once(gradle.read_text(encoding='utf-8'), 'applicationId = "com.example.nyan_read"',
        'applicationId = "com.example.nyan_read.perf13a"'), encoding='utf-8')
    smooth = project / FILES[0]
    source = smooth.read_text(encoding='utf-8')
    manifest['variant'] = args.variant
    manifest['smoothBeforeInstrumentation'] = sha(source.encode())
    smooth.write_text(instrument(source), encoding='utf-8')
    for name in ['perf13a_trace.dart', 'perf13a_main.dart']:
        shutil.copy2(ROOT / 'tool/reader_baseline' / (name + ('.template' if name.endswith('_main.dart') else '')), project / 'lib' / name)
    if args.variant == 'B':
        entry = project / 'lib/perf13a_main.dart'
        entry.write_text(entry.read_text(encoding='utf-8').replace('SmoothPageReader(key: key,', "SmoothPageReader(snapshotIncoming: engine is! PdfReaderEngine, key: key,"), encoding='utf-8')
    # Reuse the exact synthetic fixture generator from the earlier baseline.
    profile = (ROOT / 'tool/reader_baseline/profile_reader.dart').read_text(encoding='utf-8')
    start = profile.index('Future<Map<String, String>> _createSources()')
    end = profile.index('class _ProfileReader extends', start)
    fixture = profile[start:end].replace('_createSources', 'createSources').replace('_deleteSources', 'deleteSources')
    fixture = fixture.replace("Directory.systemTemp.createTemp('nyan_profile_')", "Directory('/sdcard/Android/data/com.example.nyan_read.perf13a/files').createTemp('fixture_')")
    (project / 'lib/perf13a_fixtures.dart').write_text("import 'dart:io';\nimport 'dart:convert';\nimport 'package:archive/archive.dart';\n" + fixture, encoding='utf-8')
    shutil.copy2(ROOT / 'tool/reader_baseline/turn_input_probe.dart', project / 'lib/perf13a_input_probe.dart')
    if args.input_audit:
        shutil.copy2(ROOT / 'tool/reader_baseline/perf13a_input_audit.dart.template', project / 'lib/perf13a_input_audit.dart')
        probe = project / 'lib/perf13a_input_probe.dart'
        content = "import 'perf13a_input_audit.dart';\n" + probe.read_text(encoding='utf-8')
        content = replace_once(content, 'Future<void> _tap(double x) async {', "Future<void> _tap(double x) async {\n  InputAudit.detail('tapProbe', {'x': x});")
        content = replace_once(content, 'Future<void> _swipe({double startRatio = .98}) async {', "Future<void> _swipe({double startRatio = .98}) async {\n  InputAudit.detail('swipeProbe', {'x': startRatio});")
        content = replace_once(content, 'void _same(ReadingPosition expected, ReadingPosition actual) {', "void _same(ReadingPosition expected, ReadingPosition actual) {\n  InputAudit.detail('positionCheck', {'expected': expected.toJson(), 'actual': actual.toJson()});")
        probe.write_text(content, encoding='utf-8')
        page = project / 'lib/modules/reader/reader_page.dart'
        page.write_text("import 'package:nyan_read/perf13a_input_audit.dart';\n" + page.read_text(encoding='utf-8'), encoding='utf-8')
        handler = project / 'lib/modules/reader/reader_page_gesture_handler.dart'
        content = handler.read_text(encoding='utf-8')
        start = content.index('  void _triggerPageTurn(')
        end = content.index('  Future<void> _completePageTurn', start)
        part = content[start:end]
        part = replace_once(part, '  }) {', '  }) {\n    final probe = InputAudit.attempt();')
        part = replace_once(part, '      FocusScope.of(context).unfocus();', "      InputAudit.note(probe, 'ignored', 'selection');\n      FocusScope.of(context).unfocus();")
        for anchor, reason in [('_ReaderPageState._tapLogicDedupWindow) {', 'dedup'),
                               ('if (_isPageTurning) {', 'busy'),
                               ('_ReaderPageState._pageTurnMinInterval) {', 'minInterval')]:
            part = replace_once(part, anchor, anchor + f"\n      InputAudit.note(probe, 'ignored', '{reason}');")
        part = replace_once(part, '    _lastTapLogicAt = at;', '    InputAudit.accept(probe);\n    _lastTapLogicAt = at;')
        content = content[:start] + part + content[end:]
        content = replace_once(content, '      PageTurnRequest request) async {\n    try {', '      PageTurnRequest request) async {\n    final probe = InputAudit.active;\n    try {')
        content = replace_once(content, '    } on PageTurnCancelled {', "    } on PageTurnCancelled {\n      InputAudit.note(probe, 'cancelled');")
        content = replace_once(content, '    } finally {\n      request.cancel();', "    } finally {\n      InputAudit.end(probe);\n      request.cancel();")
        handler.write_text(content, encoding='utf-8')
        epub = project / 'lib/modules/reader/reader_engine/epub/epub_reader.dart'
        content = "import 'package:nyan_read/perf13a_input_audit.dart';\n" + epub.read_text(encoding='utf-8')
        content = replace_once(content, '          child: SizeChangedLayoutNotifier(', '''          child: Builder(builder: (imageContext) => NotificationListener<SizeChangedLayoutNotification>(
            onNotification: (_) {
              final box = imageContext.findRenderObject() as RenderBox?;
              InputAudit.imageLayout(index, box != null && box.hasSize ? box.size.height : null);
              return false;
            },
            child: SizeChangedLayoutNotifier(''')
        content = replace_once(content, '            config: config,\n          )),', '            config: config,\n          )))),')
        content = replace_once(content, '  void _invalidateLayout({bool preservePaint = false}) {', "  void _invalidateLayout({bool preservePaint = false}) {\n    InputAudit.detail('layoutInvalidated', {'history': _turns.length, 'pixels': _scrollPosition?.pixels, 'position': getCurrentPosition()?.toJson()});")
        content = replace_once(content, '    final reverse = _turns.isNotEmpty && _turns.last.forward != forward;', "    InputAudit.detail('epubStep', {'forward': forward, 'history': _turns.length, 'pixels': start, 'position': before.toJson()});\n    final reverse = _turns.isNotEmpty && _turns.last.forward != forward;")
        epub.write_text(content, encoding='utf-8')
        entry = project / 'lib/perf13a_main.dart'
        content = "import 'perf13a_input_audit.dart';\n" + entry.read_text(encoding='utf-8')
        start = content.index('    await measure(scene, controller.engine, touchTurn, await sceneIndex(scene));')
        end = content.index("    appRouter.go('/');", start)
        content = content[:start] + '''    await controller.engine.goToPosition(ReadingPosition(paragraphIndex: await sceneIndex(scene)));
    await pause(1500);
    // Match the image navigation/cache history of the preserved failed run.
    if (scene == 'epub_image') {
      await measure(scene, controller.engine, touchTurn, await sceneIndex(scene));
    }
    PerfTrace.begin();
    InputAudit.enabled = true;
    Map<String, Object>? inputs;
    Object? inputError;
    try { inputs = await verifyTurnInputs(controller); }
    catch (error) { inputError = error; }
    await pause(1500);
    InputAudit.enabled = false;
    await writeResult('$scene-inputAudit', {'kind': 'inputAudit', 'scene': scene,
      'passed': inputError == null, 'errorType': inputError?.runtimeType.toString(),
      'inputs': inputs, 'config': config, ...PerfTrace.end()});
    if (inputError != null) throw inputError;
''' + content[end:]
        entry.write_text(content, encoding='utf-8')
    manifest['sourceHashes'] = {str(p.relative_to(project)).replace('\\', '/'): sha(p.read_bytes())
        for p in sorted((project / 'lib').rglob('*.dart'))}
    tag = f'input-{args.variant}' if args.input_audit else args.variant
    (OUT / f'manifest-{tag}.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(f'Prepared {args.variant}: {project}')


if __name__ == '__main__':
    main()
