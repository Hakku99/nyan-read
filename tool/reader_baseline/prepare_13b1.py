"""Prepare one-variable 13B-1 comparisons without replacing 13A evidence."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

from prepare_13a import instrument, replace_once

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / '.dart_tool/perf13b1'
FILES = ['lib/modules/reader/widgets/smooth_page_reader.dart',
         'lib/modules/reader/reader_page.dart']


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    global OUT
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=OUT)
    parser.add_argument('--variant', choices=['A', 'B'], required=True)
    parser.add_argument('--freeze', action='store_true', help='Freeze the current pre-change working tree once.')
    parser.add_argument('--candidate-file', type=Path,
        help='Replay a preserved SmoothPageReader candidate without modifying production sources.')
    args = parser.parse_args()
    OUT = args.output.resolve()
    OUT.mkdir(exist_ok=True)
    if args.freeze:
        if (OUT / 'frozen.json').exists():
            raise ValueError('Baseline already frozen')
        hashes = {}
        for name in FILES:
            data = (ROOT / name).read_bytes()
            target = OUT / 'baseline' / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            hashes[name] = digest(data)
        frozen = {'base': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip(),
            'baselineFiles': hashes}
        (OUT / 'frozen.json').write_text(json.dumps(frozen, indent=2), encoding='utf-8')
    frozen = json.loads((OUT / 'frozen.json').read_text(encoding='utf-8'))
    project = OUT / 'project'
    project.mkdir(exist_ok=True)
    archive = subprocess.check_output(['git', 'archive', '--format=zip', frozen['base'],
        'lib', 'android', 'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml'], cwd=ROOT)
    with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
        bundle.extractall(project)
    for name in FILES:
        original = (OUT / 'baseline' / name).read_bytes()
        if digest(original) != frozen['baselineFiles'][name]:
            raise ValueError('Frozen baseline drift')
        candidate = args.candidate_file if name == FILES[0] and args.candidate_file else ROOT / name
        data = original if args.variant == 'A' else candidate.read_bytes()
        if args.variant == 'B' and name == FILES[0] and data == original:
            raise ValueError('No distinct 13B-1 candidate; do not compare the baseline with itself')
        if name.endswith('reader_page.dart') and data != original:
            raise ValueError('ReaderPage must be identical in both variants')
        (project / name).write_bytes(data)
    shutil.copytree(ROOT / 'assets', project / 'assets', dirs_exist_ok=True)
    shutil.copy2(ROOT / 'android/local.properties', project / 'android/local.properties')
    gradle = project / 'android/app/build.gradle.kts'
    gradle.write_text(replace_once(gradle.read_text(encoding='utf-8'),
        'applicationId = "com.example.nyan_read"',
        'applicationId = "com.example.nyan_read.perf13a"'), encoding='utf-8')
    smooth = project / FILES[0]
    source = smooth.read_text(encoding='utf-8')
    before = digest(smooth.read_bytes())
    smooth.write_text(instrument(source), encoding='utf-8')
    for name in ['perf13a_trace.dart', 'perf13a_main.dart']:
        suffix = '.template' if name.endswith('_main.dart') else ''
        shutil.copy2(ROOT / 'tool/reader_baseline' / (name + suffix), project / 'lib' / name)
    profile = (ROOT / 'tool/reader_baseline/profile_reader.dart').read_text(encoding='utf-8')
    start = profile.index('Future<Map<String, String>> _createSources()')
    end = profile.index('class _ProfileReader extends', start)
    fixture = profile[start:end].replace('_createSources', 'createSources').replace('_deleteSources', 'deleteSources')
    fixture = fixture.replace("Directory.systemTemp.createTemp('nyan_profile_')",
        "Directory('/sdcard/Android/data/com.example.nyan_read.perf13a/files').createTemp('fixture_')")
    (project / 'lib/perf13a_fixtures.dart').write_text(
        "import 'dart:io';\nimport 'dart:convert';\nimport 'package:archive/archive.dart';\n" + fixture, encoding='utf-8')
    shutil.copy2(ROOT / 'tool/reader_baseline/turn_input_probe.dart', project / 'lib/perf13a_input_probe.dart')
    manifest = {'base': frozen['base'], 'variant': args.variant, 'smoothBeforeInstrumentation': before,
        'sourceHashes': {str(p.relative_to(project)).replace('\\', '/'): digest(p.read_bytes())
            for p in sorted((project / 'lib').rglob('*.dart'))}}
    (OUT / f'manifest-{args.variant}.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(f'Prepared 13B-1 {args.variant}')


if __name__ == '__main__':
    main()
