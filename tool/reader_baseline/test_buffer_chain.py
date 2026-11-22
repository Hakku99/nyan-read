"""Guard buffer identity and ambiguity handling in causal trace analysis."""
from collections import defaultdict
from pathlib import Path
import unittest

from analyze_buffer_chain import buffer_event, link_wait
from prepare_13a import instrument


def event(name, ms, duration=0, ident=1):
    return {'name': name, 'ts': int(ms * 1e6), 'dur': int(duration * 1e6), 'id': ident}


class BufferChainTest(unittest.TestCase):
    def setUp(self):
        self.submit = event('acquireNextBufferLocked - SurfaceView reader frame=10', 0)
        self.latch = event('latchBuffer SurfaceView reader - 10', 3)
        self.next_submit = event('acquireNextBufferLocked - SurfaceView reader frame=11', 4)
        self.next_latch = event('latchBuffer SurfaceView reader - 11', 20)
        self.pending = event('releasePendingBuffer SurfaceView reader - 10', 29)
        self.release = event('releaseBuffer - SurfaceView reader frame=10', 29.2, .02)
        self.buffers = defaultdict(lambda: defaultdict(list))
        for row in [self.submit, self.latch, self.next_submit, self.next_latch, self.pending, self.release]:
            kind, number = buffer_event(row['name'])
            self.buffers[number][kind].append(row)
        self.wait = event('waitForBufferRelease', 5, 24.5)
        self.present = event('presentDisplay display:0', 21, 7)
        self.compose = event('rcCompose()', 22, 5)

    def link(self, releases=None):
        return link_wait(self.wait, releases or [self.release], self.buffers,
                         [self.latch, self.next_latch], [self.present], [self.compose])

    def test_complete_chain_separates_consumer_and_callback_delay(self):
        result = self.link()
        self.assertTrue(result['linked'])
        self.assertEqual(result['buffer'], 10)
        self.assertEqual(result['successorBuffer'], 11)
        self.assertEqual(result['presentMs'], 7)
        self.assertEqual(result['successorSubmitToLatchMs'], 16)
        self.assertAlmostEqual(result['releaseCallbackLagMs'], .2)

    def test_multiple_releases_are_not_forced_into_one_cause(self):
        result = self.link([self.release, event('releaseBuffer - SurfaceView reader frame=9', 29.3)])
        self.assertFalse(result['linked'])

    def test_release_after_wait_is_not_its_cause(self):
        result = self.link([event('releaseBuffer - SurfaceView reader frame=10', 29.6)])
        self.assertFalse(result['linked'])

    def test_missing_or_duplicate_identity_is_rejected(self):
        self.buffers[10]['pendingRelease'].append(self.pending)
        self.assertFalse(self.link()['linked'])

    def test_fence_monitor_sequence_is_not_a_buffer_number(self):
        self.assertIsNone(buffer_event('waiting for GPU completion 10'))
        self.assertIsNone(buffer_event('HWC release fence 10 has signaled'))

    def test_capture_instrumentation_supports_both_wait_policies(self):
        root = Path(__file__).resolve().parents[2]
        source = (root / 'lib/modules/reader/widgets/smooth_page_reader.dart').read_text(encoding='utf-8')
        old = source.replace('_captureFor(turn, frameReady: true);', '_captureFor(turn);')
        for version in (source, old):
            traced = instrument(version)
            self.assertEqual(traced.count("PerfTrace.mark('captureNew');"), 1)
            self.assertEqual(traced.count("PerfTrace.mark('captureOld');"), 1)


if __name__ == '__main__':
    unittest.main()
