import unittest
from analyze_13a import analyze, position_equal
from analyze_13a_timeline import overlaps_frame


class FrameAttributionTest(unittest.TestCase):
    def test_both_capture_policy_requires_target_in_baseline(self):
        data = self.fixture()
        data['config'].update(variant='A', compiledVariant='A')
        data['events'].append({'request': 0, 'phase': 'resources', 'us': 30500,
                               'images': 0, 'capturePending': False})
        data['events'].sort(key=lambda e: e['us'])
        with self.assertRaisesRegex(ValueError, 'Target capture variant mismatch'):
            analyze(data, target_capture_variants=('A', 'B'))
        data['events'].append({'request': 0, 'phase': 'captureNew', 'us': 190})
        data['events'].sort(key=lambda e: e['us'])
        analyze(data, target_capture_variants=('A', 'B'))
        with self.assertRaisesRegex(ValueError, 'Target capture variant mismatch'):
            analyze(data)

    def fixture(self):
        phases = [('input', 100), ('accepted', 110), ('motion', 200),
                  ('release', 30000), ('returned', 31000), ('postFrame', 32000), ('windowEnd', 190000)]
        events = [{'request': 0, 'phase': name, 'us': us} for name, us in phases]
        events.append({'request': 0, 'phase': 'paintState', 'us': 250, 'frame': 7,
                       'value': .5, 'preparing': False, 'active': True})
        events.sort(key=lambda e: e['us'])
        return {'overflow': False, 'frames': [{'id': 7, 'buildStart': 220, 'buildFinish': 500,
                'rasterStart': 600, 'rasterFinish': 40000, 'buildUs': 280, 'rasterUs': 39400}],
                'events': events, 'config': {'trace': True}, 'scene': 'txt_long', 'temperature': 'warm',
                'turns': [{'id': 0, 'start': 100, 'returned': 31000}],
                'rssBefore': 1, 'rssAfter': 2, 'cacheBytes': 0}

    def test_delayed_delivery_does_not_reassign_motion_to_release(self):
        result, rows = analyze(self.fixture())
        self.assertEqual(rows[0]['stage'], 'motionMiddle')
        self.assertIn('release', rows[0]['crosses'])
        self.assertEqual(result['crossStageSlow'], 1)
        self.assertEqual(result['slow'], 1)

    def test_incompatible_clock_is_rejected(self):
        data = self.fixture()
        next(e for e in data['events'] if e['phase'] == 'paintState')['us'] += 1000000
        data['events'].sort(key=lambda e: e['us'])
        with self.assertRaisesRegex(ValueError, 'Clock/frame mismatch'): analyze(data)

    def test_missing_frame_cannot_silently_pass(self):
        data = self.fixture()
        next(e for e in data['events'] if e['phase'] == 'paintState')['frame'] = 8
        with self.assertRaisesRegex(ValueError, 'Missing motion'): analyze(data)

    def test_overflow_invalidates_run(self):
        data = self.fixture(); data['overflow'] = True
        with self.assertRaisesRegex(ValueError, 'overflow'): analyze(data)

    def test_uncleared_snapshot_invalidates_run(self):
        data = self.fixture()
        data['config'].update({'variant': 'A', 'compiledVariant': 'A'})
        data['events'].append({'request': 0, 'phase': 'resources', 'us': 30500,
                               'images': 1, 'capturePending': False})
        data['events'].sort(key=lambda e: e['us'])
        with self.assertRaisesRegex(ValueError, 'Unreleased snapshot'): analyze(data)

    def test_candidate_without_target_capture_is_rejected(self):
        data = self.fixture()
        data['config'].update({'variant': 'B', 'compiledVariant': 'B'})
        with self.assertRaisesRegex(ValueError, 'Target capture'): analyze(data)

    def test_character_change_is_never_geometry_tolerance(self):
        self.assertFalse(position_equal({'textOffset': 20}, {'textOffset': 21}))
        self.assertFalse(position_equal({'paragraphIndex': 2}, {'paragraphIndex': 3}))

    def test_non_monotonic_events_cannot_be_hidden_by_sorting(self):
        data = self.fixture()
        data['events'][0], data['events'][-1] = data['events'][-1], data['events'][0]
        with self.assertRaisesRegex(ValueError, 'Non-monotonic'): analyze(data)

    def test_reveal_during_frame_is_not_misclassified_as_motion(self):
        data = self.fixture()
        data['frames'].append({'id': 8, 'buildStart': 29000, 'buildFinish': 32500,
            'rasterStart': 32600, 'rasterFinish': 52600, 'buildUs': 3500, 'rasterUs': 20000})
        data['events'].append({'request': 0, 'phase': 'paintState', 'us': 31500, 'frame': 8,
            'value': 1, 'preparing': False, 'active': False})
        data['events'].sort(key=lambda e: e['us'])
        _, rows = analyze(data)
        self.assertEqual(rows[1]['stage'], 'revealOrAfter')
        self.assertIn('release', rows[1]['crosses'])

    def test_adjacent_raster_work_is_not_attributed_to_previous_frame(self):
        frame = {'rasterStart': 1000, 'rasterFinish': 2000}
        self.assertFalse(overlaps_frame({'start': 2100, 'end': 3000}, frame))
        self.assertTrue(overlaps_frame({'start': 990, 'end': 2005}, frame))


if __name__ == '__main__': unittest.main()
