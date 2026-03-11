enum ReaderErrorType {
  fileNotFound,
  unsupportedFormat,
  parseFailed,
  unknown,
}

class ReaderErrorState {
  final ReaderErrorType type;
  final String? technicalMessage; // Only for debug/admin
  final String? userMessage;

  ReaderErrorState({
    required this.type,
    this.technicalMessage,
    this.userMessage,
  });
}
