"""Keep target-capture diagnostics compatible with readiness-frame reuse."""
from pathlib import Path
import unittest

from prepare_13a import instrument


class CaptureInstrumentationTest(unittest.TestCase):
    def setUp(self):
        root = Path(__file__).resolve().parents[2]
        self.source = (root / 'lib/modules/reader/widgets/smooth_page_reader.dart').read_text(encoding='utf-8')

    def test_old_and_reused_readiness_frames_have_one_capture_marker(self):
        old = self.source.replace('_captureFor(turn, frameReady: true);', '_captureFor(turn);')
        for source in (old, self.source):
            traced = instrument(source)
            self.assertEqual(traced.count("PerfTrace.mark('captureNew');"), 1)
            self.assertEqual(traced.count("PerfTrace.mark('captureOld');"), 1)

    def test_unknown_capture_form_fails_instead_of_silently_missing_marker(self):
        unknown = self.source.replace('_captureFor(turn, frameReady: true);',
                                      '_captureFor(turn, frameReady: false);')
        with self.assertRaisesRegex(ValueError, 'Unrecognized incoming capture'):
            instrument(unknown)


if __name__ == '__main__':
    unittest.main()
