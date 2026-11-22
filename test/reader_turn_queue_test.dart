import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/modules/reader/controllers/reader_controller.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/reader_engine/page_turn_request.dart';

class _Engine implements ReaderEngine {
  int calls = 0;
  Future<void> Function()? action;
  @override
  Future<void> nextPage() async {
    calls++;
    await action?.call();
  }

  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<(ReaderController, _Engine)> create() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = ReaderPreferencesService();
    await preferences.initialize();
    final controller = ReaderController(
        Book(
            id: 'turn-test',
            title: 'Test',
            author: '',
            filePath: 'unused.txt',
            format: 'txt'),
        readerPreferencesService: preferences,
        databaseService: DatabaseService());
    final engine = _Engine();
    controller.engine = engine;
    addTearDown(controller.dispose);
    return (controller, engine);
  }

  test('cancelled queued request cannot run after an older request finishes',
      () async {
    final (controller, engine) = await create();
    final block = Completer<void>();
    engine.action = () => block.future;
    final first = controller.nextPage();
    await Future<void>.delayed(Duration.zero);
    final request = PageTurnRequest();
    final second = controller.nextPage(request: request);
    request.cancel();
    block.complete();
    await Future.wait([first, second]);
    expect(engine.calls, 1);
  });

  test('failure reaches caller and does not poison subsequent navigation',
      () async {
    final (controller, engine) = await create();
    final failure = StateError('navigation failed');
    engine.action = () async {
      throw failure;
    };
    await expectLater(controller.nextPage(), throwsA(same(failure)));
    engine.action = () async {};
    await controller.nextPage();
    expect(engine.calls, 2);
  });
}
