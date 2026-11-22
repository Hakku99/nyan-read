import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/riverpod_providers.dart';
import 'book_annotations_controller.dart';

final bookAnnotationsRpProvider = Provider<BookAnnotationsController>((ref) {
  return BookAnnotationsController(ref.read(databaseServiceRpProvider));
});
