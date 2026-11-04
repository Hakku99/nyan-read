"""Collect diagnostic evidence without mixing heavy, functional and light runs."""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
from analyze_13a import position_equal, stats


def input_audit(data):
    events = data['events']
    counts = Counter(e['phase'] for e in events)
    attempts = {e['request'] for e in events if e['phase'] == 'attempt'}
    accepted = {e['request'] for e in events if e['phase'] == 'inputAccepted'}
    ignored = {e['request'] for e in events if e['phase'] == 'ignored'}
    ended = Counter(e['request'] for e in events if e['phase'] == 'requestEnded')
    return {'scene': data['scene'], 'passed': data['passed'], 'overflow': data['overflow'],
        'counts': dict(counts), 'ignoredReasons': dict(Counter(e['reason'] for e in events if e['phase'] == 'ignored')),
        'unexplainedAttempts': sorted(attempts - accepted - ignored),
        'overlappingDisposition': sorted(accepted & ignored),
        'acceptedWithoutOneEnd': sorted(i for i in accepted if ended[i] != 1),
        'imageLayoutEvents': [e for e in events if e['phase'] == 'imageLayout'],
        'positionChecks': [e for e in events if e['phase'] == 'positionCheck'],
        'inputs': data['inputs']}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    analysis = json.loads((args.directory.parent / 'analysis.json').read_text(encoding='utf-8'))
    phases = defaultdict(lambda: {'frames': Counter(), 'slow': Counter(), 'slowUI': 0, 'slowRaster': 0})
    examples = defaultdict(list)
    durations = defaultdict(lambda: defaultdict(list))
    for row in analysis['runs']:
        ident = row['config']['id']
        if not ident.startswith('foreground-') or row['temperature'] != 'warm': continue
        experiment = 'matrix' if '-matrix-' in ident else 'full' if '-full-' in ident else None
        if not experiment: continue
        key = experiment + '-' + row['config']['variant']
        raw = json.loads((args.directory / row['source']).read_text(encoding='utf-8'))
        for turn in raw['turns']:
            marks = {e['phase']: e['us'] for e in raw['events'] if e['request'] == turn['id']}
            for start, end in [('captureOld', 'coverOld'), ('navigate', 'ready'),
                               ('ready', 'readyFrame'), ('captureNew', 'motion'),
                               ('release', 'revealScheduled')]:
                if start in marks and end in marks:
                    durations[key + '-' + row['scene']][start].append((marks[end]-marks[start])/1000)
        phases[key]['frames'].update(row['allStages'])
        phases[key]['slow'].update(row['slowStages'])
        import csv
        with (args.directory / row['source']).with_suffix('.frames.csv').open(encoding='utf-8') as stream:
            for frame in csv.DictReader(stream):
                phases[key]['slowUI'] += int(frame['buildUs']) > 16666.6667
                phases[key]['slowRaster'] += int(frame['rasterUs']) > 16666.6667
                examples[key].append({'source': row['source'], **frame})
    for key, values in examples.items():
        examples[key] = sorted(values, key=lambda f: max(int(f['buildUs']), int(f['rasterUs'])), reverse=True)[:20]
    audits = []
    stress = defaultdict(list)
    partial_stress = defaultdict(list)
    malformed = []
    for path in args.directory.rglob('*.json'):
        if path.name in {'flutter-timeline.json', 'timeline-analysis.json', 'system-correlation.json', 'vm-flags.json'}:
            continue
        try:
            data = json.loads(path.read_text(encoding='utf-8-sig'))
        except json.JSONDecodeError as error:
            malformed.append({'source': str(path.relative_to(args.directory)), 'error': str(error)})
            continue
        if not isinstance(data, dict): continue
        if data.get('kind') == 'inputAudit':
            audits.append({'source': str(path.relative_to(args.directory)), **input_audit(data)})
        if str(data.get('temperature', '')).startswith('stress'):
            ident = data['config']['id']
            if not (path.parent / f'{ident}-complete.json').exists() or (path.parent / f'{ident}-error.json').exists():
                partial_stress[(ident, data['scene'])].append(data)
                continue
            stress[data['scene']].append(data)
    def summarize_stress(blocks):
        blocks.sort(key=lambda d: d['turns'][0]['start'])
        turns = [t for b in blocks for t in b['turns']]
        resources = [e for b in blocks for e in b['events'] if e['phase'] == 'resources']
        final_resources = [next((e for e in reversed(b['events'])
            if e['phase'] == 'resources' and e['request'] == t['id']), None)
            for b in blocks for t in b['turns']]
        return {'blocks': len(blocks), 'turns': len(turns),
            'seconds': (turns[-1]['returned'] - turns[0]['start']) / 1e6,
            'overflow': any(b['overflow'] for b in blocks),
            'roundTripMismatches': sum(not position_equal(b['turns'][0]['before'], b['turns'][-1]['after']) for b in blocks),
            'trajectoryMismatches': sum(not position_equal(t['after'], blocks[0]['turns'][i]['after'])
                for b in blocks for i,t in enumerate(b['turns'])),
            'rssFirst': blocks[0]['rssBefore'], 'rssLast': blocks[-1]['rssAfter'],
            'rssMaxSample': max(t['rss'] for t in turns),
            'rssByBlock': [{'start': b['turns'][0]['start'], 'before': b['rssBefore'], 'after': b['rssAfter']} for b in blocks],
            'maxImageReferences': max(e['images'] for e in resources),
            'maxSnapshotPixels': max(e['pixels'] for e in resources),
            'unclearedAfterRelease': sum(e is None or e['images'] != 0 or e['capturePending'] for e in final_resources),
            'maxImageCacheBytes': max(b['cacheBytes'] for b in blocks)}
    stress_result = {scene: summarize_stress(blocks) for scene, blocks in stress.items()}
    partial_result = [{'run': ident, 'scene': scene, 'status': 'incomplete-observations-only',
        **summarize_stress(blocks)} for (ident, scene), blocks in sorted(partial_stress.items())]
    result = {'phases': dict(phases), 'stageDurationMs': {key: {name: stats(v) for name, v in group.items()} for key, group in durations.items()},
        'slowFrameExamples': dict(examples), 'inputAudits': audits, 'stress': stress_result,
        'partialStress': partial_result, 'malformedFiles': malformed}
    (args.directory.parent / 'evidence.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({'phaseGroups': len(phases), 'inputAudits': len(audits), 'stressScenes': list(stress)}, indent=2))


if __name__ == '__main__': main()
