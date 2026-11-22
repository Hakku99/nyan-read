// Copied only into the disposable diagnostic project, never production lib/.
import 'dart:developer' as dev;
import 'dart:ui';
import 'package:flutter/scheduler.dart';

final class PerfTrace {
  static bool enabled = true;
  static bool heavy = false;
  static const capacity = 50000;
  static bool overflow = false;
  static final events = <Map<String, Object>>[];
  static final frames = <FrameTiming>[];
  static int request = -1;
  static void resources(Image? outgoing, Image? incoming, bool capturePending) {
    if (!enabled || request < 0) return;
    if (events.length >= capacity) { overflow = true; return; }
    events.add({'request': request, 'phase': 'resources', 'us': dev.Timeline.now,
      'images': (outgoing == null ? 0 : 1) + (incoming == null ? 0 : 1),
      'pixels': (outgoing == null ? 0 : outgoing.width * outgoing.height) +
        (incoming == null ? 0 : incoming.width * incoming.height),
      'capturePending': capturePending});
  }
  static void mark(String phase) {
    if (!enabled || request < 0) return;
    if (events.length >= capacity) { overflow = true; return; }
    events.add({'request': request, 'phase': phase, 'us': dev.Timeline.now});
    if (heavy) dev.Timeline.instantSync('13A.$phase', arguments: {'request': request});
  }

  static void motion(double value, bool preparing, bool active) {
    if (!enabled || request < 0) return;
    if (events.length >= capacity) { overflow = true; return; }
    events.add({'request': request, 'phase': 'paintState', 'us': dev.Timeline.now,
      'frame': PlatformDispatcher.instance.frameData.frameNumber,
      'systemUs': SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds,
      'value': value, 'preparing': preparing, 'active': active});
  }

  static void collect(List<FrameTiming> values) {
    if (frames.length + values.length > capacity) { overflow = true; return; }
    frames.addAll(values);
  }

  static void begin() {
    events.clear(); frames.clear(); overflow = false;
    SchedulerBinding.instance.addTimingsCallback(collect);
  }
  static Map<String, Object> end() {
    SchedulerBinding.instance.removeTimingsCallback(collect);
    request = -1;
    return {'overflow': overflow, 'events': List.of(events), 'frames': frames.map((f) => {
      'id': f.frameNumber,
      'vsync': f.timestampInMicroseconds(FramePhase.vsyncStart),
      'buildStart': f.timestampInMicroseconds(FramePhase.buildStart),
      'buildFinish': f.timestampInMicroseconds(FramePhase.buildFinish),
      'rasterStart': f.timestampInMicroseconds(FramePhase.rasterStart),
      'rasterFinish': f.timestampInMicroseconds(FramePhase.rasterFinish),
      'buildUs': f.buildDuration.inMicroseconds, 'rasterUs': f.rasterDuration.inMicroseconds,
      'layerBytes': f.layerCacheBytes, 'pictureBytes': f.pictureCacheBytes,
    }).toList()};
  }
}
