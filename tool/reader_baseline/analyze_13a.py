"""Join raw frame identifiers/timestamps to stages, retaining crossing frames."""
import argparse
from collections import Counter, defaultdict
import csv
import json
import math
from pathlib import Path
import statistics

BUDGET = 1000000 / 60


def stats(values):
    values = sorted(values)
    if not values:
        return None
    return {'n': len(values), **{k: values[max(0, math.ceil(len(values)*p)-1)]
        for k, p in [('p50', .5), ('p95', .95), ('p99', .99), ('max', 1)]}}


def analyze(data, *, target_capture_variants=('B',)):
    if data['overflow']:
        raise ValueError('Trace overflow')
    cfg = data['config']
    if cfg.get('compiledVariant') is not None and cfg['compiledVariant'] != cfg['variant']:
        raise ValueError('Compiled variant mismatch')
    frames = sorted(data['frames'], key=lambda f: f['buildStart'])
    if len({f['id'] for f in frames}) != len(frames):
        raise ValueError('Duplicate frame identifiers')
    if any(a['us'] > b['us'] for a, b in zip(data['events'], data['events'][1:])):
        raise ValueError('Non-monotonic event timestamps')
    if any(not f['buildStart'] <= f['buildFinish'] <= f['rasterFinish'] or
           f['rasterStart'] > f['rasterFinish'] for f in frames):
        raise ValueError('Invalid frame timestamp ordering')
    by_id = {f['id']: f for f in frames}
    paint = [e for e in data['events'] if e['phase'] == 'paintState']
    # A paint-state mark must occur during its own frame's UI build. This tests
    # the Timeline/engine epoch at runtime instead of assuming equal clocks.
    matched = [e for e in paint if e['frame'] in by_id]
    invalid = [e for e in matched if not by_id[e['frame']]['buildStart'] <= e['us'] <= by_id[e['frame']]['buildFinish']]
    if invalid:
        raise ValueError(f'Clock/frame mismatch: {len(invalid)} / {len(matched)}')
    if data['config']['trace'] and (not matched or len(matched) != len(paint)):
        raise ValueError('Missing motion-frame timing')
    rows, first_moves, counts, completions = [], [], [], []
    max_burst = 0
    for turn in data['turns']:
        events = sorted([e for e in data['events'] if e['request'] == turn['id']], key=lambda e: e['us'])
        marks = [e for e in events if e['phase'] not in ['paintState', 'resources']]
        if data['config']['trace']:
            names = [e['phase'] for e in marks]
            for name in ['input', 'accepted', 'motion', 'release', 'returned', 'postFrame', 'windowEnd']:
                if names.count(name) != 1: raise ValueError(f'Missing/duplicate {name}: {names}')
        if data['config']['trace'] and cfg.get('compiledVariant') is not None:
            incoming = sum(e['phase'] == 'captureNew' for e in events)
            expected = 1 if cfg['variant'] in target_capture_variants and not data['scene'].startswith('pdf') else 0
            if incoming != expected: raise ValueError('Target capture variant mismatch')
            resources = [e for e in events if e['phase'] == 'resources']
            if not resources or resources[-1]['images'] != 0 or resources[-1]['capturePending']:
                raise ValueError('Unreleased snapshot or pending capture')
        motion = {e['frame']: e for e in events if e['phase'] == 'paintState' and e['active'] and not e['preparing']}
        paint_by_frame = {e['frame']: e for e in events if e['phase'] == 'paintState'}
        release = next((e['us'] for e in marks if e['phase'] == 'release'), None)
        moving = [e for e in motion.values() if 0 < e['value'] < 1]
        if moving:
            first_moves.append((min(by_id[e['frame']]['buildStart'] for e in moving)-turn['start'])/1000)
        end = next((e['us'] for e in marks if e['phase'] == 'windowEnd'), turn['returned']+150000)
        selected = [f for f in frames if turn['start'] <= f['buildStart'] <= end]
        slow_count = burst = 0
        for f in selected:
            stage = 'untraced'
            overlaps = []
            if marks:
                overlaps = [a['phase'] for a, b in zip(marks, marks[1:])
                    if a['us'] < f['rasterFinish'] and b['us'] > f['buildStart']]
                stage = next((e['phase'] for e in reversed(marks) if e['us'] <= f['buildStart']), 'beforeInput')
                painted = paint_by_frame.get(f['id'])
                # Animation completion can clear snapshots during the same UI
                # frame, after buildStart but before the widget rebuild. The
                # actual paint state then identifies a reveal, not more motion.
                if painted and not painted['active'] and release is not None and painted['us'] >= release:
                    stage = 'revealOrAfter'
                elif f['id'] in motion:
                    value = motion[f['id']]['value']
                    stage = 'motionFirst' if value <= .1 else 'motionLast' if value >= .9 else 'motionMiddle'
                elif stage in ['finishMotion', 'release', 'revealScheduled', 'returned', 'postFrame']:
                    stage = 'revealOrAfter'
                if stage == 'motion': stage = 'motionBoundary'
            slow = max(f['buildUs'], f['rasterUs']) > BUDGET
            slow_count += slow
            burst = burst+1 if slow else 0
            max_burst = max(max_burst, burst)
            rows.append({'request': turn['id'], 'frame': f['id'], 'stage': stage,
                'crosses': '|'.join(overlaps) if len(overlaps) > 1 else '',
                'buildUs': f['buildUs'], 'rasterUs': f['rasterUs'], 'slow': slow,
                'buildStart': f['buildStart'], 'rasterFinish': f['rasterFinish']})
        counts.append(slow_count)
        completions.append((turn['returned']-turn['start'])/1000)
    slow = [r for r in rows if r['slow']]
    stages = Counter(r['stage'] for r in slow)
    all_stages = Counter(r['stage'] for r in rows)
    return {'scene': data['scene'], 'temperature': data['temperature'], 'config': data['config'],
        'turns': len(data['turns']), 'frames': len(rows), 'slow': len(slow),
        'slowPercent': len(slow)*100/len(rows) if rows else None,
        'slowPerTurn': stats(counts), 'meanSlowPerTurn': statistics.mean(counts),
        'maxConsecutiveSlow': max_burst, 'buildMs': stats([r['buildUs']/1000 for r in rows]),
        'rasterMs': stats([r['rasterUs']/1000 for r in rows]),
        'firstMoveMs': stats(first_moves), 'completionMs': stats(completions),
        'slowStages': dict(stages), 'allStages': dict(all_stages),
        'clockMatchedPaintMarks': len(matched), 'crossStageSlow': sum(bool(r['crosses']) for r in slow),
        'rssBefore': data['rssBefore'], 'rssAfter': data['rssAfter'], 'cacheBytes': data['cacheBytes']}, rows


def position_equal(a, b):
    if isinstance(a, str): a = json.loads(a)
    if isinstance(b, str): b = json.loads(b)
    if a.keys() != b.keys(): return False
    for key in a:
        if a[key] == b[key]: continue
        # Position leading edges are normalized fractions, not pixels. Keep a
        # conservative 2px/1000 logical-height equivalent, without rounding IDs.
        if key in ['paragraphLeadingEdge', 'paragraphTrailingEdge', 'textViewportOffset'] and isinstance(a[key], (int, float)) and isinstance(b[key], (int, float)):
            if abs(a[key]-b[key]) <= 2/1000: continue
        return False
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    parser.add_argument('--target-capture-variants', nargs='+', choices=['A', 'B'], default=['B'],
        help='13A captures the target only in B; 13B-1 requires it in both A and B.')
    args = parser.parse_args()
    reports = []
    trajectories = defaultdict(dict)
    errors = []
    rejected = []
    for path in sorted(args.directory.rglob('*.json')):
        if path.name in {'flutter-timeline.json', 'timeline-analysis.json', 'system-correlation.json', 'vm-flags.json'}:
            continue
        try:
            data = json.loads(path.read_text(encoding='utf-8-sig'))
        except json.JSONDecodeError as error:
            if any(path.parent.glob('*-complete.json')):
                errors.append({'source': str(path), 'error': str(error)})
            else:
                rejected.append(str(path.relative_to(args.directory)))
            continue
        if not isinstance(data, dict) or 'frames' not in data or data.get('kind') == 'inputAudit': continue
        ident = data['config']['id']
        if (path.parent / 'invalid-run.json').exists() or (path.parent / f'{ident}-error.json').exists() or not (path.parent / f'{ident}-complete.json').exists():
            rejected.append(str(path.relative_to(args.directory)))
            continue
        try:
            report, rows = analyze(data, target_capture_variants=args.target_capture_variants)
            report['source'] = str(path.relative_to(args.directory))
            reports.append(report)
            with path.with_suffix('.frames.csv').open('w', encoding='utf-8', newline='') as stream:
                writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
                writer.writeheader(); writer.writerows(rows)
            cfg = data['config']
            if 'pair' in cfg and 'overhead' not in cfg['id']:
                key = (cfg['id'].rsplit('-', 2)[0], cfg.get('fullApp', False), cfg['pair'], data['scene'], data['temperature'])
                trajectories[key][cfg['variant']] = data['turns']
        except (ValueError, KeyError, IndexError) as error:
            errors.append({'source': str(path), 'error': str(error)})
    mismatches = []
    paired = 0
    for key, variants in trajectories.items():
        if 'A' not in variants or 'B' not in variants: continue
        if len(variants['A']) != len(variants['B']): mismatches.append(str(key)); continue
        for a, b in zip(variants['A'], variants['B']):
            paired += 1
            if not position_equal(a['after'], b['after']): mismatches.append({'scene': key, 'turn': a['id'], 'A': a['after'], 'B': b['after']})
    result = {'runs': reports, 'errors': errors, 'pairedTurns': paired, 'positionMismatches': mismatches, 'rejectedIncompleteOrFailedBlocks': rejected}
    (args.directory.parent / 'analysis.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({'blocks': len(reports), 'errors': errors[:5], 'pairedTurns': paired, 'mismatches': len(mismatches)}, indent=2))


if __name__ == '__main__':
    main()
