"""Join measured slow-frame raster intervals to local Android scheduling."""
import argparse
import csv
import io
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    parser.add_argument('--processor', type=Path, required=True)
    args = parser.parse_args()
    data = json.loads((args.directory / 'timeline-analysis.json').read_text(encoding='utf-8'))
    values = ',\n'.join(f"({f['frame']},'{f['scene']}','{f['temperature']}','{f['stage']}',{f['rasterStart']*1000},{f['rasterFinish']*1000})" for f in data['slowFrames'])
    sql = '''CREATE PERFETTO TABLE selected_frames AS
WITH raw(frame,scene,temperature,stage,start_ns,end_ns) AS (VALUES
''' + values + ''')
SELECT *, start_ns + (SELECT AVG(ts-clock_value) FROM clock_snapshot WHERE clock_name='MONOTONIC') AS begin,
end_ns + (SELECT AVG(ts-clock_value) FROM clock_snapshot WHERE clock_name='MONOTONIC') AS finish FROM raw;
CREATE PERFETTO TABLE raster_slices AS
SELECT s.* FROM slice s JOIN thread_track tt ON s.track_id=tt.id
JOIN thread t USING(utid) JOIN process p USING(upid)
WHERE p.name LIKE '%perf13a%' AND t.name LIKE '%raster%' AND s.dur>0;
CREATE PERFETTO TABLE raster_states AS
SELECT s.* FROM thread_state s JOIN thread t USING(utid) JOIN process p USING(upid)
WHERE p.name LIKE '%perf13a%' AND t.name LIKE '%raster%' AND s.dur>0;
SELECT f.frame,f.scene,f.temperature,f.stage,(f.finish-f.begin)/1e6 AS raster_ms,
''' + ',\n'.join(f"COALESCE((SELECT SUM(MIN(s.ts+s.dur,f.finish)-MAX(s.ts,f.begin))/1e6 FROM {table} s WHERE {predicate} AND s.ts<f.finish AND s.ts+s.dur>f.begin),0) AS {alias}"
    for table, predicate, alias in [
        ('raster_slices', "s.name='eglSwapBuffers'", 'swap_ms'),
        ('raster_slices', "s.name='waitForBufferRelease'", 'buffer_wait_ms'),
        ('raster_states', "s.state='Running'", 'running_ms'),
        ('raster_states', "s.state='S'", 'sleeping_ms'),
        ('raster_states', "s.state IN ('R','R+')", 'runnable_ms')]) + '\nFROM selected_frames f ORDER BY raster_ms DESC;\n'
    query = args.directory / 'frame-system-query.sql'
    query.write_text(sql, encoding='utf-8')
    result = subprocess.run([sys.executable, str(args.processor), 'query', '--format', 'csv', '-f', str(query),
        str(args.directory / 'system.pftrace')], capture_output=True, encoding='utf-8', check=True)
    (args.directory / 'frame-system.csv').write_text(result.stdout, encoding='utf-8')
    (args.directory / 'frame-system-query.log').write_text(result.stderr, encoding='utf-8')
    rows = list(csv.DictReader(io.StringIO(result.stdout)))
    groups = {}
    for temperature in ['first', 'warm']:
        frames = [r for r in rows if r['temperature'] == temperature]
        groups[temperature] = {'slowFrames': len(frames),
            'swapOverHalfOfRaster': sum(float(r['swap_ms']) > float(r['raster_ms'])/2 for r in frames),
            'bufferWaitOverHalfOfRaster': sum(float(r['buffer_wait_ms']) > float(r['raster_ms'])/2 for r in frames),
            'sleepOverHalfOfRaster': sum(float(r['sleeping_ms']) > float(r['raster_ms'])/2 for r in frames),
            'topFrames': frames[:10]}
    (args.directory / 'system-correlation.json').write_text(json.dumps(groups, indent=2), encoding='utf-8')
    print(json.dumps({k: {n: v for n,v in group.items() if n!='topFrames'} for k,group in groups.items()}, indent=2))


if __name__ == '__main__': main()
