"""Separate heavy tracing; never merge its timings into light acceptance runs."""
import json
import re
import time
from urllib.parse import urlencode
from urllib.request import urlopen


class HeavyTrace:
    def __init__(self, adb, package, target):
        self.adb, self.package, self.target = adb, package, target
        self.remote = '/data/misc/perfetto-traces/nyan13a.pftrace'
        self.perfetto_pid = None
        self.base = None
        self.forward = None

    def start_system(self):
        # Starting ATrace before Flutter makes Android force the VM recorder to
        # systrace. Attach to the in-memory VM recorder before starting ATrace.
        response = self.adb('shell', 'perfetto', '--background-wait', '-t', '90s',
            '-b', '128mb', '-o', self.remote, '-a', self.package,
            'sched', 'freq', 'idle', 'gfx', 'view', 'am', 'wm', 'dalvik', 'memory')
        (self.target / 'perfetto-start.txt').write_text(response.stdout + response.stderr, encoding='utf-8')
        lines = response.stdout.strip().splitlines()
        self.perfetto_pid = next((line.strip() for line in reversed(lines) if line.strip().isdigit()), None)
        if self.perfetto_pid is None:
            raise RuntimeError('Perfetto did not return an owned process ID; inspect perfetto-start.txt')

    def attach_vm(self):
        for _ in range(80):
            pid = self.adb('shell', 'pidof', self.package, check=False).stdout.strip()
            if pid and len(pid.split()) == 1:
                logs = self.adb('logcat', '-d', '-v', 'raw', f'--pid={pid}', '-s', 'flutter:I').stdout
                match = re.search(r'The Dart VM service is listening on http://127.0.0.1:(\d+)/(\S+)/', logs)
                if match:
                    self.forward = self.adb('forward', 'tcp:0', f'tcp:{match[1]}').stdout.strip()
                    self.base = f'http://127.0.0.1:{self.forward}/{match[2]}/'
                    flags = self.rpc('getVMTimelineFlags')
                    (self.target / 'vm-flags.json').write_text(json.dumps(flags), encoding='utf-8')
                    recorded = flags['result']['recordedStreams']
                    if not {'Dart', 'Embedder', 'GC'}.issubset(recorded):
                        raise RuntimeError('Required timeline streams are unavailable')
                    if flags['result']['recorderName'] == 'Systrace':
                        raise RuntimeError('VM uses system-only tracing; an in-memory recorder is required')
                    return
            time.sleep(.25)
        raise RuntimeError('VM timeline service unavailable')

    def rpc(self, name, **params):
        with urlopen(self.base + name + ('?' + urlencode(params) if params else ''), timeout=20) as response:
            result = json.load(response)
        if 'error' in result: raise RuntimeError(str(result['error']))
        return result

    def stop(self):
        # Only the exact PID returned by our trace launch is eligible to stop.
        if self.perfetto_pid is not None:
            self.adb('shell', 'kill', '-TERM', self.perfetto_pid, check=False)
            time.sleep(2)
            self.adb('pull', self.remote, str(self.target / 'system.pftrace'))
        if self.forward:
            self.adb('forward', '--remove', f'tcp:{self.forward}')
            self.forward = None

    def finish(self):
        try:
            timeline = self.rpc('getVMTimeline')
            (self.target / 'flutter-timeline.json').write_text(json.dumps(timeline), encoding='utf-8')
        finally:
            self.stop()
