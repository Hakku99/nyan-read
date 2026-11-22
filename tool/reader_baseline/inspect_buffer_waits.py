"""Reuse a recorded trace to compare buffer waits in fast and slow frames."""
import argparse
import csv
import io
import json
from pathlib import Path
import subprocess
import sys

from analyze_13a import analyze


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--processor', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    values = []
    for path in args.directory.glob('*.json'):
        if path.name in ('flutter-timeline.json', 'timeline-analysis.json'):
            continue
        raw = json.loads(path.read_text(encoding='utf-8'))
        if not isinstance(raw, dict) or 'frames' not in raw:
            continue
        _, rows = analyze(raw)
        frames = {f['id']: f for f in raw['frames']}
        for row in rows:
            frame = frames[row['frame']]
            values.append(f"({row['frame']},'{raw['scene']}','{raw['temperature']}',"
                f"'{row['stage']}',{int(row['slow'])},{frame['rasterStart']*1000},"
                f"{frame['rasterFinish']*1000})")
    sql = '''CREATE PERFETTO TABLE measured AS
WITH raw(frame,scene,temperature,stage,slow,start_ns,end_ns) AS (VALUES
''' + ',\n'.join(values) + ''') SELECT *,
start_ns+(SELECT AVG(ts-clock_value) FROM clock_snapshot WHERE clock_name='MONOTONIC') AS begin,
end_ns+(SELECT AVG(ts-clock_value) FROM clock_snapshot WHERE clock_name='MONOTONIC') AS finish FROM raw;
CREATE PERFETTO TABLE raster_slices AS
SELECT s.* FROM slice s JOIN thread_track tt ON s.track_id=tt.id
JOIN thread t USING(utid) JOIN process p USING(upid)
WHERE p.name LIKE '%perf13a%' AND t.name LIKE '%raster%' AND s.dur>0;
CREATE PERFETTO TABLE raster_states AS
SELECT s.* FROM thread_state s JOIN thread t USING(utid) JOIN process p USING(upid)
WHERE p.name LIKE '%perf13a%' AND t.name LIKE '%raster%' AND s.dur>0;
SELECT f.frame,f.scene,f.temperature,f.stage,f.slow,(f.finish-f.begin)/1e6 AS raster_ms,
''' + ',\n'.join(
        f"COALESCE((SELECT SUM(MIN(s.ts+s.dur,f.finish)-MAX(s.ts,f.begin))/1e6 "
        f"FROM {table} s WHERE {predicate} AND s.ts<f.finish AND s.ts+s.dur>f.begin),0) AS {alias}"
        for table, predicate, alias in [
            ('raster_slices', "s.name='eglSwapBuffers'", 'swap_ms'),
            ('raster_slices', "s.name='waitForBufferRelease'", 'wait_ms'),
            ('raster_states', "s.state='Running'", 'running_ms'),
            ('raster_states', "s.state='S'", 'sleeping_ms')]) + '\nFROM measured f ORDER BY f.frame;\n'
    query = args.output / 'all-frames.sql'
    query.write_text(sql, encoding='utf-8')
    result = subprocess.run([sys.executable, str(args.processor), 'query', '--format', 'csv',
        '-f', str(query), str(args.directory / 'system.pftrace')],
        capture_output=True, encoding='utf-8', check=True)
    (args.output / 'all-frames.csv').write_text(result.stdout, encoding='utf-8')
    (args.output / 'query.log').write_text(result.stderr, encoding='utf-8')
    rows = list(csv.DictReader(io.StringIO(result.stdout)))
    groups = {}
    for row in rows:
        key = '/'.join(row[k] for k in ('temperature', 'stage', 'slow'))
        group = groups.setdefault(key, {'frames': 0, 'waitOverHalf': 0,
            'waitOver16ms': 0, 'rasterMs': 0, 'waitMs': 0, 'runningMs': 0})
        group['frames'] += 1
        group['waitOverHalf'] += float(row['wait_ms']) > float(row['raster_ms']) / 2
        group['waitOver16ms'] += float(row['wait_ms']) > 16.667
        for column, metric in [('raster_ms', 'rasterMs'), ('wait_ms', 'waitMs'), ('running_ms', 'runningMs')]:
            group[metric] += float(row[column])
    (args.output / 'summary.json').write_text(json.dumps(groups, indent=2), encoding='utf-8')
    print(json.dumps(groups, indent=2))


if __name__ == '__main__':
    main()
