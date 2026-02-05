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

  String get userMessage {
    switch (type) {
      case ReaderErrorType.fileNotFound:
        return "这本书好像迷路了。\n文件找不到了，可能被移动或删除。";
      case ReaderErrorType.unsupportedFormat:
        return "猫娘看不懂这种格式。\n暂时不支持打开此类型的文件。";
      case ReaderErrorType.parseFailed:
        return "书页粘在一起了。\n文件解析失败，可能是文件已损坏。";
      case ReaderErrorType.unknown:
      default:
        return "发生了意想不到的事情。\n请稍后再试。";
    }
  }
}