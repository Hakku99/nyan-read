"""Summarize each experiment separately; never hide a worst round."""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import statistics


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('analysis', type=Path)
    args = parser.parse_args()
    data = json.loads(args.analysis.read_text(encoding='utf-8'))
    groups = defaultdict(list)
    for row in data['runs']:
        cfg = row['config']
        if not cfg['id'].startswith('foreground-') or row['temperature'] != 'warm': continue
        if '-matrix-' in cfg['id']: experiment = 'matrix'
        elif '-full-' in cfg['id']: experiment = 'full'
        elif '-overhead-' in cfg['id']: experiment = 'overhead'
        else: continue
        variant = str(cfg['trace']) if experiment == 'overhead' else cfg['variant']
        groups[(experiment, row['scene'], variant)].append(row)
    summary = []
    for (experiment, scene, variant), rows in sorted(groups.items()):
        slow = sum(r['slow'] for r in rows)
        frames = sum(r['frames'] for r in rows)
        turns = sum(r['turns'] for r in rows)
        slow_stages, all_stages = Counter(), Counter()
        for r in rows:
            slow_stages.update(r['slowStages']); all_stages.update(r['allStages'])
        def p95_range(key):
            values = [r[key]['p95'] for r in rows if r[key]]
            return {'min': min(values), 'max': max(values), 'median': statistics.median(values)} if values else None
        item = {'experiment': experiment, 'scene': scene, 'variant': variant,
            'rounds': len(rows), 'turns': turns, 'frames': frames, 'slow': slow,
            'slowPercent': slow*100/frames, 'slowPerTurn': slow/turns,
            'worstRoundSlowPercent': max(r['slowPercent'] for r in rows),
            'maxConsecutiveSlow': max(r['maxConsecutiveSlow'] for r in rows),
            'buildP95Ms': p95_range('buildMs'), 'rasterP95Ms': p95_range('rasterMs'),
            'firstMoveP95Ms': p95_range('firstMoveMs'), 'completionP95Ms': p95_range('completionMs'),
            'slowStages': dict(slow_stages), 'allStages': dict(all_stages),
            'perRound': [{'id': r['config']['id'], 'slow': r['slow'], 'frames': r['frames'],
                'slowPercent': r['slowPercent'], 'rasterP95': r['rasterMs']['p95'],
                'firstMoveP95': r['firstMoveMs']['p95'] if r['firstMoveMs'] else None,
                'completionP95': r['completionMs']['p95']} for r in rows]}
        summary.append(item)
        print(f"{experiment:8} {scene:12} {variant:5} n={len(rows)} slow={slow}/{frames} ({slow*100/frames:.2f}%) perTurn={slow/turns:.2f} worst={item['worstRoundSlowPercent']:.2f}% rasterP95={item['rasterP95Ms']['median']:.2f}")
    args.analysis.with_name('summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')


if __name__ == '__main__': main()
