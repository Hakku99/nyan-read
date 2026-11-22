-- Run locally with Perfetto; no trace upload is necessary.
SELECT name, value FROM stats WHERE value != 0 AND
  (name LIKE '%overwrit%' OR name LIKE '%lost%' OR severity = 'error');

SELECT clock_name, COUNT(*) AS samples,
  MIN(ts-clock_value) AS min_offset_ns, MAX(ts-clock_value) AS max_offset_ns
FROM clock_snapshot GROUP BY clock_name;

SELECT t.utid, t.tid, t.name, p.pid, p.name AS process
FROM thread t JOIN process p USING (upid)
WHERE p.name LIKE '%perf13a%' AND t.name LIKE '%raster%';

SELECT ts.state, COUNT(*) AS intervals, SUM(ts.dur)/1e6 AS total_ms
FROM thread_state ts JOIN thread t USING (utid) JOIN process p USING (upid)
WHERE p.name LIKE '%perf13a%' AND t.name LIKE '%raster%' AND ts.dur > 0
GROUP BY ts.state ORDER BY total_ms DESC;

SELECT s.name, COUNT(*) AS calls, SUM(s.dur)/1e6 AS total_ms, MAX(s.dur)/1e6 AS max_ms
FROM slice s JOIN thread_track tt ON s.track_id=tt.id JOIN thread t USING (utid)
JOIN process p USING (upid)
WHERE p.name LIKE '%perf13a%' AND t.name LIKE '%raster%' AND s.dur > 0
GROUP BY s.name ORDER BY total_ms DESC LIMIT 20;

SELECT COUNT(*) AS gpu_slices FROM gpu_slice;
SELECT COUNT(*) AS gpu_counter_tracks FROM gpu_counter_track;
