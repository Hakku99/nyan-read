"""Link existing Android buffer IDs; never confuse them with Flutter frame IDs.

Inputs are local Perfetto CSV exports. This script does not collect a trace.
FenceMonitor sequence numbers are deliberately not joined to buffer numbers.
"""
import argparse
from bisect import bisect_right
from collections import Counter, defaultdict
import csv
import json
from pathlib import Path
import re

from analyze_13a import analyze, stats


def read_csv(path):
    with path.open(encoding='utf-8-sig', newline='') as stream:
        return list(csv.DictReader(stream))


def latest_before(rows, timestamp):
    index = bisect_right([r['ts'] for r in rows], timestamp) - 1
    return rows[index] if index >= 0 else None


def buffer_event(name):
    patterns = [('submit', r'^acquireNextBufferLocked - .*SurfaceView.*frame=(\d+)$'),
                ('release', r'^releaseBuffer - .*SurfaceView.*frame=(\d+)$'),
                ('latch', r'^latchBuffer .*SurfaceView.* - (\d+)$'),
                ('pendingRelease', r'^releasePendingBuffer .*SurfaceView.* - (\d+)$')]
    for kind, pattern in patterns:
        match = re.match(pattern, name)
        if match:
            return kind, int(match[1])
    return None


def link_wait(wait, releases, buffers, latches, presents, compose):
    end = wait['ts'] + wait['dur']
    # A local BLAST release is often processed synchronously inside the wait.
    # A release starting after the wait cannot establish its cause.
    candidates = [r for r in releases if wait['ts'] <= r['ts'] <= end]
    if len(candidates) != 1:
        return {'linked': False, 'reason': 'ambiguous/missing release',
                'releaseCandidates': len(candidates)}
    release = candidates[0]
    number = buffer_event(release['name'])[1]
    chain = buffers[number]
    if any(len(chain.get(k, [])) != 1 for k in ('submit', 'latch', 'pendingRelease')):
        return {'linked': False, 'reason': 'incomplete/duplicate buffer identity'}
    submit, latch, pending = (chain[k][0] for k in ('submit', 'latch', 'pendingRelease'))
    successor = latest_before(latches, pending['ts'])
    if successor is None or successor['ts'] <= latch['ts']:
        return {'linked': False, 'reason': 'missing successor latch'}
    successor_number = buffer_event(successor['name'])[1]
    successor_submits = buffers[successor_number].get('submit', [])
    if len(successor_submits) != 1:
        return {'linked': False, 'reason': 'missing/duplicate successor submit'}
    successor_submit = successor_submits[0]
    display_calls = [p for p in presents if successor['ts'] <= p['ts'] and
                     p['ts'] + p['dur'] <= pending['ts']]
    if len(display_calls) != 1:
        return {'linked': False, 'reason': 'ambiguous/missing display present'}
    present = display_calls[0]
    rc = [c for c in compose if present['ts'] <= c['ts'] and
          c['ts'] + c['dur'] <= present['ts'] + present['dur']]
    if len(rc) != 1:
        return {'linked': False, 'reason': 'ambiguous/missing host compose'}
    if not submit['ts'] <= latch['ts'] < successor['ts'] <= pending['ts'] <= release['ts']:
        return {'linked': False, 'reason': 'invalid chain ordering'}
    return {'linked': True, 'buffer': number, 'successorBuffer': successor_number,
            'submitTs': submit['ts'], 'latchTs': latch['ts'],
            'successorSubmitTs': successor_submit['ts'], 'successorLatchTs': successor['ts'],
            'presentTs': present['ts'], 'presentEndTs': present['ts'] + present['dur'],
            'pendingReleaseTs': pending['ts'], 'releaseTs': release['ts'],
            'submitToLatchMs': (latch['ts'] - submit['ts']) / 1e6,
            'successorSubmitToLatchMs': (successor['ts'] - successor_submit['ts']) / 1e6,
            'latchIntervalMs': (successor['ts'] - latch['ts']) / 1e6,
            'presentMs': present['dur'] / 1e6, 'hostComposeMs': rc[0]['dur'] / 1e6,
            'releaseCallbackLagMs': (release['ts'] - pending['ts']) / 1e6,
            'releaseToWaitEndMs': (end - release['ts']) / 1e6,
            'presentSlice': present['id'], 'hostComposeSlice': rc[0]['id']}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path, help='Original heavy trace directory')
    parser.add_argument('--slices', type=Path, required=True)
    parser.add_argument('--offset', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    rows = read_csv(args.slices)
    for row in rows:
        for key in ('id', 'ts', 'dur'):
            row[key] = int(row[key])
    buffers = defaultdict(lambda: defaultdict(list))
    surfaces = {r['name'].rsplit(' - ', 1)[0] for r in rows
                if r['name'].startswith('latchBuffer ')}
    if len(surfaces) != 1:
        raise ValueError('Export exactly one reader SurfaceView; buffer IDs are surface-local')
    for row in rows:
        event = buffer_event(row['name'])
        if event:
            buffers[event[1]][event[0]].append(row)
    releases = [r for r in rows if buffer_event(r['name']) and buffer_event(r['name'])[0] == 'release']
    latches = [r for r in rows if buffer_event(r['name']) and buffer_event(r['name'])[0] == 'latch']
    presents = [r for r in rows if r['name'] == 'presentDisplay display:0']
    compose = [r for r in rows if r['name'] == 'rcCompose()']
    waits = [r for r in rows if r['name'] == 'waitForBufferRelease' and r['dur'] > 0]
    submits = [r for r in rows if buffer_event(r['name']) and buffer_event(r['name'])[0] == 'submit']
    swaps = [r for r in rows if r['name'] == 'eglSwapBuffers']
    offset = float(read_csv(args.offset)[0]['offset_ns'])
    frames = []
    for path in args.directory.glob('*.json'):
        if path.name in ('flutter-timeline.json', 'timeline-analysis.json'):
            continue
        data = json.loads(path.read_text(encoding='utf-8'))
        if not isinstance(data, dict) or 'frames' not in data:
            continue
        _, measured = analyze(data)
        raw = {f['id']: f for f in data['frames']}
        for frame in measured:
            frames.append({**frame, 'scene': data['scene'], 'temperature': data['temperature'],
                'begin': raw[frame['frame']]['rasterStart'] * 1000 + offset,
                'end': raw[frame['frame']]['rasterFinish'] * 1000 + offset})
    linked = []
    for wait in waits:
        matched = [f for f in frames if f['begin'] <= wait['ts'] < f['end']]
        if len(matched) != 1:
            continue
        frame = matched[0]
        submitted = latest_before(submits, wait['ts'])
        previous = latest_before(submits, submitted['ts'] - 1) if submitted else None
        swap = latest_before(swaps, wait['ts'])
        linked.append({'flutterFrame': frame['frame'], 'scene': frame['scene'],
            'temperature': frame['temperature'], 'stage': frame['stage'], 'slow': frame['slow'],
            'rasterMs': frame['rasterUs'] / 1000, 'waitMs': wait['dur'] / 1e6,
            'waitTs': wait['ts'], 'waitEndTs': wait['ts'] + wait['dur'],
            'submitGapMs': (submitted['ts'] - previous['ts']) / 1e6 if previous else None,
            'preSwapMs': (swap['ts'] - frame['begin']) / 1e6
                if swap and frame['begin'] <= swap['ts'] else None,
            **link_wait(wait, releases, buffers, latches, presents, compose)})
    groups = {}
    for scene in sorted({r['scene'] for r in linked}):
        for slow in (False, True):
            selected = [r for r in linked if r['scene'] == scene and r['slow'] == slow and r['temperature'] == 'warm']
            complete = [r for r in selected if r['linked']]
            groups[f'{scene}/slow={slow}'] = {'waits': len(selected), 'linked': len(complete),
                'rejections': dict(Counter(r['reason'] for r in selected if not r['linked'])),
                'presentOverBudget': sum(r['presentMs'] > 1000/60 for r in complete),
                'successorQueuedOverBudgetBeforeLatch': sum(r['successorSubmitToLatchMs'] > 1000/60 for r in complete),
                **{key: stats([r[key] for r in complete]) for key in
                   ('waitMs', 'presentMs', 'hostComposeMs', 'latchIntervalMs',
                    'successorSubmitToLatchMs', 'releaseCallbackLagMs', 'releaseToWaitEndMs')}}
    result = {'offsetNs': offset, 'measuredWaits': len(linked), 'groups': groups, 'waits': linked}
    args.output.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({'measuredWaits': len(linked), 'groups': groups}, indent=2))


if __name__ == '__main__':
    main()
