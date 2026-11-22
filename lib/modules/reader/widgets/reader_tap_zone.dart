enum ReaderTapZone {
  previous,
  center,
  next;

  static ReaderTapZone at(double x, double width) {
    if (x < width * .20) return previous;
    if (x > width * .80) return next;
    return center;
  }
}
