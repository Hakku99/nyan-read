import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/privacy_screen_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(PrivacyScreenService.channelName);
  late List<bool> calls;
  Object? failWith;

  setUp(() {
    calls = [];
    failWith = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (failWith != null) throw failWith!;
      calls.add((call.arguments as Map)['secure'] as bool);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  PrivacyScreenService build({bool native = true}) =>
      PrivacyScreenService(nativeEnabled: native);

  test('ref-counts holders: native flag flips only on empty<->non-empty',
      () async {
    final service = build();
    final a = Object(), b = Object();

    service.acquire(a);
    service.acquire(a); // duplicate acquire is a no-op
    service.acquire(b);
    await Future<void>.delayed(Duration.zero);
    expect(calls, [true]);

    service.release(a);
    await Future<void>.delayed(Duration.zero);
    expect(calls, [true], reason: 'b still holds the flag');

    service.release(b);
    service.release(b); // double release is a no-op
    await Future<void>.delayed(Duration.zero);
    expect(calls, [true, false]);
    expect(service.active.value, isFalse);
  });

  test('never touches the channel when native support is disabled', () async {
    final service = build(native: false);
    final a = Object();
    service.acquire(a);
    service.release(a);
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
  });

  test('a failing channel is logged, not thrown', () async {
    failWith = PlatformException(code: 'boom');
    final service = build();
    service.acquire(Object());
    await Future<void>.delayed(Duration.zero);
    expect(service.hasHolders, isTrue);
  });

  test('untilNewerReleased waits for screens stacked above, not below',
      () async {
    final service = build(native: false);
    final home = Object(), search = Object(), reader = Object();
    service.acquire(home);
    service.acquire(search);
    service.acquire(reader);

    var searchWaitDone = false;
    var readerWaitDone = false;
    service.untilNewerReleased(search).then((_) => searchWaitDone = true);
    service.untilNewerReleased(reader).then((_) => readerWaitDone = true);
    await Future<void>.delayed(Duration.zero);
    expect(readerWaitDone, isTrue, reason: 'nothing above the reader');
    expect(searchWaitDone, isFalse);

    service.release(reader);
    await Future<void>.delayed(Duration.zero);
    expect(searchWaitDone, isTrue);
  });

  test('a failed native push is retried on the next transition', () async {
    final service = build();
    failWith = PlatformException(code: 'boom');
    final a = Object();
    service.acquire(a);
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);

    failWith = null;
    service.release(a);
    final b = Object();
    service.acquire(b); // empty -> non-empty again must resend true
    await Future<void>.delayed(Duration.zero);
    expect(calls, contains(true));
  });
}
