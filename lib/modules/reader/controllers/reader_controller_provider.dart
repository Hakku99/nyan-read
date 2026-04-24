import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/book.dart';
import '../../../core/services/riverpod_providers.dart';
import 'brightness_controller.dart';
import 'reader_controller.dart';

class ReaderControllerProviderArgs {
  final Book book;
  final BrightnessController brightnessController;

  const ReaderControllerProviderArgs({
    required this.book,
    required this.brightnessController,
  });

  @override
  bool operator ==(Object other) {
    return other is ReaderControllerProviderArgs &&
        other.book.id == book.id &&
        identical(other.brightnessController, brightnessController);
  }

  @override
  int get hashCode => Object.hash(book.id, identityHashCode(brightnessController));
}

/// Riverpod host experiment for ReaderController lifecycle.
///
/// The UI still consumes ReaderController through provider selectors for now,
/// while the creation/disposal path is moved under Riverpod control.
final readerControllerRpProvider = Provider.autoDispose
    .family<ReaderController, ReaderControllerProviderArgs>((ref, args) {
  final controller = ReaderController(
    args.book,
    readerPreferencesService: ref.read(readerPreferencesRpProvider),
    databaseService: ref.read(databaseServiceRpProvider),
  );
  controller.attachBrightnessController(args.brightnessController);
  controller.init();
  ref.onDispose(controller.dispose);
  return controller;
});
