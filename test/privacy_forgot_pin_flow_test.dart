/// Forgot-PIN recovery (audit P0-2). Pins the safety invariants:
///   * erase deletes the books BEFORE clearing the PIN; a failed erase keeps
///     the PIN;
///   * backing out of the post-verification setup keeps the OLD PIN (never a
///     PIN-less shelf);
///   * first-time PIN setup refuses to hand over surviving private books;
///   * the overlay hides the button without a handler and ignores double taps.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/biometric_service.dart';
import 'package:nyan_read/core/services/bookshelf_preferences_service.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/core/services/pin_service.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/bookshelf/bookshelf_view_model.dart';
import 'package:nyan_read/modules/privacy/forgot_pin_sheet.dart';
import 'package:nyan_read/modules/privacy/pin_overlay_page.dart';
import 'package:nyan_read/modules/privacy/privacy_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBiometric extends BiometricService {
  bool deviceSupported = true;
  BiometricResult result = BiometricResult.success;

  @override
  Future<bool> isDeviceAuthSupported() async => deviceSupported;

  @override
  Future<BiometricResult> authenticate(
    String localizedReason, {
    bool biometricOnly = true,
  }) async =>
      result;
}

class _FakeDb extends DatabaseService {
  final Map<String, Map<String, dynamic>> books = {};
  bool refuseDelete = false;

  int get privateCount =>
      books.values.where((b) => b['is_private'] == 1).length;

  @override
  Future<List<Map<String, dynamic>>> getBooks({
    bool isPrivate = false,
    String orderBy = 'last_read_at DESC',
  }) async =>
      books.values
          .where((b) => (b['is_private'] ?? 0) == (isPrivate ? 1 : 0))
          .map(Map<String, dynamic>.from)
          .toList();

  @override
  Future<void> deleteBooksWithAssociatedData(List<String> bookIds) async {
    if (refuseDelete) return;
    bookIds.forEach(books.remove);
  }
}

Map<String, dynamic> _row(String id, {required bool isPrivate}) => {
      'id': id,
      'title': 'Book $id',
      'author': 'Author',
      'file_path': '/books/$id.txt',
      'format': 'txt',
      'is_private': isPrivate ? 1 : 0,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final preset = themePresets[ThemePreset.creamLight]!;

  late _FakeDb db;
  late _FakeBiometric biometric;
  late PinService pin;
  late PrivacyLockService service;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    db = _FakeDb()..books['p1'] = _row('p1', isPrivate: true);
    biometric = _FakeBiometric();
    pin = PinService();
    await pin.setPin('1234');
    final prefs = BookshelfPreferencesService();
    await prefs.initialize();
    final vm = BookshelfViewModel(db, prefs);
    service = PrivacyLockService(pin, biometric, () => vm);
  });

  void phoneSizedView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home) => MaterialApp(
        theme: preset.themeData,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      );

  /// Starts [run] from a button tap and returns a getter for its result.
  Future<T? Function()> start<T>(
    WidgetTester tester,
    Future<T> Function(BuildContext) run,
  ) async {
    phoneSizedView(tester);
    T? result;
    await tester.pumpWidget(app(Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async => result = await run(ctx),
            child: const Text('go'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return () => result;
  }

  // SnackBarUtils toasts keep a timer alive; let it run out.
  Future<void> drainToasts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('erase: books are deleted, then the PIN is cleared',
      (tester) async {
    final outcome = await start(tester, service.runForgotPinFlow);

    await tester.tap(find.text('Erase private shelf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erase'));
    await tester.pumpAndSettle();

    expect(outcome(), ForgotPinOutcome.erased);
    expect(db.privateCount, 0);
    expect(await pin.hasPinSet(), isFalse);
    await drainToasts(tester);
  });

  testWidgets('erase that cannot delete keeps the PIN', (tester) async {
    db.refuseDelete = true;
    final outcome = await start(tester, service.runForgotPinFlow);

    await tester.tap(find.text('Erase private shelf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erase'));
    await tester.pumpAndSettle();

    expect(outcome(), ForgotPinOutcome.cancelled);
    expect(db.privateCount, 1);
    expect(await pin.verifyPin('1234'), isTrue);
    await drainToasts(tester);
  });

  testWidgets('declining the erase confirmation changes nothing',
      (tester) async {
    final outcome = await start(tester, service.runForgotPinFlow);

    await tester.tap(find.text('Erase private shelf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(outcome(), ForgotPinOutcome.cancelled);
    expect(db.privateCount, 1);
    expect(await pin.verifyPin('1234'), isTrue);
  });

  testWidgets('device-lock path: backing out of setup keeps the OLD PIN',
      (tester) async {
    final outcome = await start(tester, service.runForgotPinFlow);

    await tester.tap(find.text('Verify with device lock'));
    await tester.pumpAndSettle();
    expect(find.text('Set a PIN'), findsOneWidget);

    await tester.tap(find.byIcon(NyanIcons.close));
    await tester.pumpAndSettle();

    expect(outcome(), ForgotPinOutcome.cancelled);
    expect(await pin.verifyPin('1234'), isTrue,
        reason: 'cancelling must never leave a PIN-less shelf');
    expect(db.privateCount, 1);
  });

  testWidgets('device-lock path: a cancelled prompt never reaches setup',
      (tester) async {
    biometric.result = BiometricResult.cancelled;
    final outcome = await start(tester, service.runForgotPinFlow);

    await tester.tap(find.text('Verify with device lock'));
    await tester.pumpAndSettle();

    expect(outcome(), ForgotPinOutcome.cancelled);
    expect(find.text('Set a PIN'), findsNothing);
    expect(await pin.verifyPin('1234'), isTrue);
  });

  testWidgets('device-lock option is hidden when the device cannot verify',
      (tester) async {
    biometric.deviceSupported = false;
    await start(tester, service.runForgotPinFlow);

    expect(find.text('Verify with device lock'), findsNothing);
    expect(find.text('Erase private shelf'), findsOneWidget);
  });

  testWidgets('guarded setup: surviving private books force the recovery sheet',
      (tester) async {
    await pin.resetPin(); // PIN gone, private row restored/surviving
    await start(tester, service.showPinSetupGuarded);

    expect(find.text('Forgot your PIN?'), findsOneWidget);
    expect(find.text('Set a PIN'), findsNothing,
        reason: 'free setup would hand the shelf to whoever taps first');
  });

  testWidgets('guarded setup: an empty shelf gets the plain setup overlay',
      (tester) async {
    await pin.resetPin();
    db.books.clear();
    await start(tester, service.showPinSetupGuarded);

    expect(find.text('Set a PIN'), findsOneWidget);
  });

  group('PinOverlayPage forgot button', () {
    Widget overlay({
      Future<ForgotPinOutcome> Function(BuildContext)? onForgot,
    }) =>
        app(PinOverlayPage(
          mode: PinOverlayMode.verify,
          pinService: pin,
          onForgotPin: onForgot,
        ));

    testWidgets('is hidden without a handler instead of doing nothing',
        (tester) async {
      phoneSizedView(tester);
      await tester.pumpWidget(overlay());
      await tester.pump();

      expect(find.text('Forgot PIN?'), findsNothing);
    });

    testWidgets('a double tap starts the flow once', (tester) async {
      phoneSizedView(tester);
      final pending = Completer<ForgotPinOutcome>();
      var calls = 0;
      await tester.pumpWidget(overlay(onForgot: (_) {
        calls++;
        return pending.future;
      }));
      await tester.pump();

      await tester.tap(find.text('Forgot PIN?'));
      await tester.pump();
      await tester.tap(find.text('Forgot PIN?'));
      await tester.pump();

      expect(calls, 1);
      pending.complete(ForgotPinOutcome.cancelled);
      await tester.pump();
    });
  });
}
