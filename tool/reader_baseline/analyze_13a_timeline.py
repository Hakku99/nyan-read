"""Inspect a separate VM trace; its timings never enter light acceptance."""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
from analyze_13a import analyze, stats


def overlaps_frame(span, frame):
    return (frame['rasterStart']-500 <= span['start'] < frame['rasterFinish']
            and span['end'] > frame['rasterStart'])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    data = json.loads((args.directory / 'flutter-timeline.json').read_text(encoding='utf-8'))['result']
    events = data['traceEvents']
    names, stacks, spans = {}, defaultdict(list), []
    for e in events:
        key = (e.get('pid'), e.get('tid'))
        if e['ph'] == 'M' and e.get('name') == 'thread_name': names[key] = e['args']['name']
        elif e['ph'] == 'B': stacks[key].append(e)
        elif e['ph'] == 'E' and stacks[key]:
            start = stacks[key].pop()
            spans.append({'name': start['name'], 'start': start['ts'], 'end': e['ts'], 'thread': key,
                'duration': e['ts']-start['ts']})
        elif e['ph'] == 'X':
            spans.append({'name': e['name'], 'start': e['ts'], 'end': e['ts']+e['dur'],
                'duration': e['dur'], 'thread': key})
    grouped = defaultdict(list)
    for s in spans:
        grouped[(names.get(s['thread'], str(s['thread'])), s['name'])].append(s['duration']/1000)
    top = sorted([{'thread': k[0], 'name': k[1], 'totalMs': sum(v), **stats(v)}
        for k, v in grouped.items()], key=lambda s: s['totalMs'], reverse=True)[:70]
    markers = defaultdict(list)
    for e in events:
        if e.get('name', '').startswith('13A.'):
            markers[(e['name'][4:], e.get('args', {}).get('request'))].append(e['ts'])
    differences, frames = [], []
    for path in args.directory.glob('*.json'):
        if path.name == 'flutter-timeline.json': continue
        raw = json.loads(path.read_text(encoding='utf-8'))
        if not isinstance(raw, dict) or 'frames' not in raw: continue
        _, rows = analyze(raw)
        for e in raw['events']:
            candidates = markers.get((e['phase'], e['request']), [])
            if candidates: differences.append(min(abs(t-e['us']) for t in candidates))
        for f in rows:
            if not f['slow']: continue
            frame = next(x for x in raw['frames'] if x['id'] == f['frame'])
            relevant = [s for s in spans if 'raster' in names.get(s['thread'], '').lower() and
                overlaps_frame(s, frame)]
            relevant.sort(key=lambda s: s['duration'], reverse=True)
            frames.append({'scene': raw['scene'], 'temperature': raw['temperature'], **f,
                'rasterStart': frame['rasterStart'],
                'spans': [{'name': s['name'], 'start': s['start'], 'end': s['end'], 'durationUs': s['duration']}
                    for s in relevant[:12]]})
    result = {'eventCount': len(events), 'eventTypes': dict(Counter(e['ph'] for e in events)),
        'spanCount': len(spans), 'unclosedStacks': sum(len(s) for s in stacks.values()),
        'markerClockDifferenceUs': stats(differences), 'topSpans': top, 'slowFrames': frames}
    (args.directory / 'timeline-analysis.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({k: result[k] for k in ['eventCount', 'eventTypes', 'spanCount', 'unclosedStacks', 'markerClockDifferenceUs']}, indent=2))
    for s in top[:20]: print(s['thread'], s['name'], round(s['totalMs'], 2), s['p95'])


if __name__ == '__main__': main()
