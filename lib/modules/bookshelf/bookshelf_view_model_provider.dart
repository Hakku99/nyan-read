import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/riverpod_providers.dart';
import 'bookshelf_view_model.dart';

final bookshelfViewModelRpProvider = Provider.autoDispose<BookshelfViewModel>((ref) {
  final vm = BookshelfViewModel(
    ref.read(databaseServiceRpProvider),
    ref.read(bookshelfPreferencesRpProvider),
  );
  ref.onDispose(vm.dispose);
  return vm;
});
