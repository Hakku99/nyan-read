"""Two short AB/BA pairs; no endurance test or concurrent heavy tracing."""
import argparse
from pathlib import Path
import run_13a as runner


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--prefix', required=True)
    parser.add_argument('--start-pair', type=int, choices=[1, 2], default=1)
    parser.add_argument('--pairs', type=int, choices=[1, 2], default=2)
    parser.add_argument('--scenes', nargs='+',
        choices=['txt_long', 'epub_long', 'epub_image'],
        default=['txt_long', 'epub_long', 'epub_image'])
    parser.add_argument('--output', type=Path,
        default=Path(__file__).resolve().parents[2] / '.dart_tool/perf13b1')
    parser.add_argument('--turns', type=int, choices=range(2, 13), default=12)
    parser.add_argument('--input-checks', action='store_true',
        help='Exercise cancellation and gestures equally in the first A/B pair.')
    args = parser.parse_args()
    if args.start_pair > args.pairs:
        parser.error('--start-pair must not exceed --pairs')
    runner.OUT = args.output.resolve()
    scenes = args.scenes
    for pair, order in enumerate([['A', 'B'], ['B', 'A']][:args.pairs], start=1):
        if pair < args.start_pair:
            continue
        for variant in order:
            # Completed results are already on the host. Removing only the
            # disposable install avoids APK replacement peaks on small AVDs.
            runner.adb('uninstall', runner.PACKAGE, check=False)
            if runner.adb('shell', 'pm', 'path', runner.PACKAGE, check=False).stdout.strip():
                raise RuntimeError('Dedicated package was not removed')
            runner.execute({'id': f'{args.prefix}-full-{pair}-{variant}',
                'pair': pair, 'variant': variant, 'fullApp': True,
                'freshInstall': True,
                'trace': True, 'inputChecks': args.input_checks and pair == 1,
                'turns': args.turns,
                'scenes': scenes if pair == 1 else list(reversed(scenes))}, timeout=180)


if __name__ == '__main__':
    main()
