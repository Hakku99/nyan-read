-- Export one reader SurfaceView from the original 13A system traces.
-- FenceMonitor sequence numbers are not buffer frame numbers.
SELECT s.id, s.ts, s.dur, s.name, t.name AS thread, p.name AS process
FROM slice s JOIN thread_track tt ON tt.id=s.track_id
JOIN thread t USING(utid) JOIN process p USING(upid)
WHERE (p.name LIKE '%perf13a%' AND (
  s.name IN ('waitForBufferRelease','dequeueBuffer','eglSwapBuffers') OR
  s.name LIKE 'acquireNextBufferLocked - %SurfaceView%frame=%' OR
  s.name LIKE 'releaseBuffer - %SurfaceView%frame=%'))
OR (p.name='/system/bin/surfaceflinger' AND (
  s.name LIKE 'latchBuffer %SurfaceView%nyan_read%' OR
  s.name LIKE 'releasePendingBuffer %SurfaceView%nyan_read%'))
OR (p.name LIKE '%composer3%' AND s.name IN (
  'presentDisplay display:0','rcCompose()','Create Sync','Wait for Previous Composition'))
ORDER BY s.ts;
