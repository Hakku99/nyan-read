enum ReaderErrorType {
  fileNotFound,
  unsupportedFormat,
  parseFailed,
  unknown,
}

class ReaderErrorState {
  final ReaderErrorType type;
  final String? technicalMessage; // Only for debug/admin

  ReaderErrorState({
    required this.type,
    this.technicalMessage,
  });
}
