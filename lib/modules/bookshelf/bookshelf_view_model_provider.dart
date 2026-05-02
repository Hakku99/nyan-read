import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/riverpod_providers.dart';
import 'bookshelf_view_model.dart';

/// Singleton bookshelf VM for the app lifetime (not autoDispose).
///
/// AutoDispose caused flaky UX: overlay dialogs briefly dropping subscriber
/// count could recreate the VM, wiping selection / deleting against stale data,
/// and follow-up notices relied on an Overlay ancestor from this subtree.
final bookshelfViewModelRpProvider = Provider<BookshelfViewModel>((ref) {
  final vm = BookshelfViewModel(
    ref.read(databaseServiceRpProvider),
    ref.read(bookshelfPreferencesRpProvider),
  );
  ref.onDispose(vm.dispose);
  return vm;
});
