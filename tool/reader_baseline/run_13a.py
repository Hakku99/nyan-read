"""Run isolated processes; retain raw results, including failed runs."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / '.dart_tool/perf13a'
ADB = Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe'
SAMPLES = Path.home() / 'Downloads/Mobile Devices'
PACKAGE = 'com.example.nyan_read.perf13a'
REMOTE = f'/sdcard/Android/data/{PACKAGE}/files'
SCENES = ['txt_normal', 'epub_normal', 'pdf_normal', 'txt_long', 'epub_long', 'epub_image']


def adb(*args, check=True):
    result = subprocess.run([str(ADB), '-s', 'emulator-5554', *args],
        capture_output=True, encoding='utf-8', errors='replace')
    if check and result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result


def execute(config, timeout=600, install=True):
    ident = config['id']
    config['windowCondition'] = 'foreground' if ident.startswith('foreground') else 'recorded-separately'
    config['incrementalPull'] = config.get('stressSeconds', 0) > 0
    target = OUT / 'results' / ident
    target.mkdir(parents=True, exist_ok=False)
    apk = OUT / config.get('apkName', f"{config['variant']}.apk")
    config['apkSha256'] = hashlib.sha256(apk.read_bytes()).hexdigest()
    (target / 'config.json').write_text(json.dumps(config, indent=2), encoding='utf-8')
    adb('shell', 'am', 'force-stop', PACKAGE)
    if config.get('fullApp') and not config.get('freshInstall'):
        # Reset only the dedicated test package so prior A/B progress cannot
        # seed a different initial restore or image cache.
        adb('shell', 'pm', 'clear', PACKAGE)
    if install:
        # A small emulator partition needs room for the temporary APK update.
        # Only this runner's reproducible sample copy is removed and restored.
        adb('shell', 'rm', '-f', f'{REMOTE}/sample.epub')
        adb('install', '-r', str(apk))
        sample = next(p for p in SAMPLES.glob('*.epub') if p.stat().st_size == 193460451)
    adb('shell', 'mkdir', '-p', REMOTE)
    adb('shell', 'chmod', '777', f'/sdcard/Android/data/{PACKAGE}', REMOTE)
    if install: adb('push', str(sample), f'{REMOTE}/sample.epub')
    if config.get('fullApp'):
        txt = next(p for p in SAMPLES.glob('*.txt') if p.stat().st_size == 9190763)
        adb('push', str(txt), f'{REMOTE}/sample.txt')
    adb('push', str(target / 'config.json'), f'{REMOTE}/config.json')
    heavy = None
    if config.get('heavy'):
        from perf13a_heavy import HeavyTrace
        heavy = HeavyTrace(adb, PACKAGE, target)
    trace_args = ['--ez', 'trace-systrace', 'false', '--ez', 'trace-startup', 'true'] if heavy else []
    adb('shell', 'am', 'start', '-n', f'{PACKAGE}/com.example.nyan_read.MainActivity', *trace_args)
    if heavy:
        try:
            heavy.attach_vm()
            heavy.start_system()
        except Exception:
            heavy.stop()
            adb('shell', 'am', 'force-stop', PACKAGE)
            raise
    started = time.monotonic()
    last_count = -1
    while time.monotonic() - started < timeout:
        time.sleep(5)
        listing = adb('shell', 'ls', f'{REMOTE}/results', check=False).stdout.splitlines()
        files = [f for f in listing if f.startswith(ident + '-')]
        if config['incrementalPull']:
            # A visible name may still be written or waiting for chmod. Validate
            # a temporary local copy before publishing a durable checkpoint.
            # Do not use these extra reads during A/B timing measurements.
            for name in files:
                if not (target / name).exists():
                    temporary = target / (name + '.partial')
                    pulled = adb('pull', f'{REMOTE}/results/{name}', str(temporary), check=False)
                    if pulled.returncode: continue
                    try: json.loads(temporary.read_text(encoding='utf-8'))
                    except (ValueError, UnicodeError): continue
                    temporary.replace(target / name)
            (target / 'checkpoint.json').write_text(json.dumps({
                'id': ident, 'elapsedSeconds': time.monotonic()-started,
                'pulledFiles': len(files), 'complete': f'{ident}-complete.json' in files}), encoding='utf-8')
        if len(files) != last_count:
            print(f'{ident}: {len(files)} result files, {time.monotonic()-started:.0f}s', flush=True)
            last_count = len(files)
        if f'{ident}-complete.json' in files or f'{ident}-error.json' in files:
            for name in files:
                if not config['incrementalPull'] or not (target / name).exists():
                    adb('pull', f'{REMOTE}/results/{name}', str(target / name))
            pid = adb('shell', 'pidof', PACKAGE).stdout.strip()
            log = adb('logcat', '-d', '-v', 'threadtime', f'--pid={pid}', '-s', 'flutter:I').stdout
            (target / 'logcat.log').write_text(log, encoding='utf-8')
            if heavy: heavy.finish()
            adb('shell', 'am', 'force-stop', PACKAGE)
            if f'{ident}-error.json' in files:
                raise RuntimeError(f'{ident} failed; preserved diagnostic output')
            return
    if heavy: heavy.finish()
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('pull', f'{REMOTE}/results', str(target / 'incomplete'), check=False)
    raise TimeoutError(ident)


def main():
    global ADB, SAMPLES
    parser = argparse.ArgumentParser()
    parser.add_argument('--mode', choices=['pilot', 'matrix', 'overhead', 'full', 'stress', 'heavy', 'input'], default='pilot')
    parser.add_argument('--variant', choices=['A', 'B'], default='A')
    parser.add_argument('--prefix', default='run1')
    parser.add_argument('--setup', action='store_true')
    parser.add_argument('--adb', type=Path, default=ADB)
    parser.add_argument('--samples', type=Path, default=SAMPLES)
    parser.add_argument('--scenes', nargs='+', choices=SCENES,
        help='Override scenes for a single pilot/heavy run; not a formal matrix.')
    parser.add_argument('--full-app', action='store_true',
        help='Use the full application for a single heavy/pilot run.')
    args = parser.parse_args()
    ADB, SAMPLES = args.adb, args.samples
    if args.setup:
        adb('install', '-r', str(OUT / f'{args.variant}.apk'))
        adb('shell', 'mkdir', '-p', REMOTE)
        hashes = {}
        for ext, size in [('txt', 9190763), ('epub', 193460451)]:
            sample = next(p for p in SAMPLES.glob(f'*.{ext}') if p.stat().st_size == size)
            hashes[ext] = hashlib.sha256(sample.read_bytes()).hexdigest()
            adb('push', str(sample), f'{REMOTE}/sample.{ext}')
        (OUT / 'samples.json').write_text(json.dumps(hashes, indent=2), encoding='utf-8')
    if args.mode in ['matrix', 'full']:
        for pair in range(4):
            for variant in (['A', 'B'] if pair % 2 == 0 else ['B', 'A']):
                scenes = SCENES[pair:] + SCENES[:pair]
                if args.mode == 'full': scenes = [s for s in scenes if s != 'pdf_normal']
                execute({'id': f'{args.prefix}-{args.mode}-{pair+1}-{variant}', 'variant': variant,
                    'pair': pair+1, 'scenes': scenes, 'trace': True, 'fullApp': args.mode == 'full',
                    'inputChecks': False, 'turns': 12})
    elif args.mode == 'overhead':
        for pair in range(4):
            for enabled in ([False, True] if pair % 2 == 0 else [True, False]):
                execute({'id': f'{args.prefix}-overhead-{pair+1}-{enabled}', 'variant': 'A',
                    'pair': pair+1, 'scenes': ['txt_normal', 'epub_long'], 'trace': enabled, 'turns': 12})
    elif args.mode == 'input':
        execute({'id': f'{args.prefix}-input-{args.variant}', 'variant': args.variant,
            'apkName': f'input-{args.variant}.apk', 'fullApp': True, 'trace': True,
            'scenes': args.scenes or ['txt_normal', 'txt_long', 'epub_normal', 'epub_long', 'epub_image']})
    else:
        execute({'id': f'{args.prefix}-{args.mode}-{args.variant}', 'variant': args.variant,
            'scenes': args.scenes or (['txt_long', 'epub_long'] if args.mode == 'stress' else ['txt_long'] if args.mode == 'pilot' else ['epub_long']),
            'trace': True, 'heavy': args.mode == 'heavy', 'turns': 12,
            'fullApp': args.full_app,
            'stressSeconds': 600 if args.mode == 'stress' else 0}, timeout=1500)


if __name__ == '__main__':
    main()
