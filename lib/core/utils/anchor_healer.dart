class AnchorHealer {
  /// 搜救引擎：使用三段式特征定位偏移
  /// [chapterText] - 当前所在段落/章节全文
  /// [pre] - 前文特征 (最高15字符)
  /// [exact] - 被高亮的目标文本
  /// [post] - 后文特征 (最高15字符)
  /// return 修复后的 startOffset，如果遭遇灾难性不可恢复则返回 null
  static int? findHealedOffset(
      String chapterText, String pre, String exact, String post) {
    if (chapterText.isEmpty || exact.isEmpty) return null;

    // 1. 完整匹配最优路径 (极速通道)
    final String fullSignature = '$pre$exact$post';
    final int strictIndex = chapterText.indexOf(fullSignature);
    if (strictIndex != -1) {
      return strictIndex + pre.length;
    }

    // 2. 降级匹配：如果 pre 或 post 出现错别字，仅用 exact 搜索
    // 找出所有 exact 出现的位置候选节点
    List<int> candidateIndices = [];
    int searchIndex = 0;
    while (true) {
      final idx = chapterText.indexOf(exact, searchIndex);
      if (idx == -1) break;
      candidateIndices.add(idx);
      searchIndex = idx + exact.length;
    }

    if (candidateIndices.isEmpty) return null;
    if (candidateIndices.length == 1) {
      return candidateIndices.first; // 唯一孤岛，直接信赖
    }

    // 3. 权重对齐仲裁机制
    // 如果 exact 在段落中出现多次，计算两侧指纹的相似度权重最高者。
    int bestIndex = -1;
    int maxWeight = -1;

    for (int idx in candidateIndices) {
      int weight = 0;
      // 提取物理环境周边的真实文本
      int startPre = (idx - pre.length).clamp(0, chapterText.length);
      String actualPre = chapterText.substring(startPre, idx);

      int endPost =
          (idx + exact.length + post.length).clamp(0, chapterText.length);
      String actualPost = chapterText.substring(idx + exact.length, endPost);

      // 计算相似权重 (严格尾部与头部贴合字符数)
      weight += _calculateOverlap(pre, actualPre, alignRight: true);
      weight += _calculateOverlap(post, actualPost, alignRight: false);

      if (weight > maxWeight) {
        maxWeight = weight;
        bestIndex = idx;
      }
    }

    // 设定最小存活阈值（若错位极其严重则抛弃）
    if (maxWeight >= (pre.length + post.length) * 0.3) {
      return bestIndex;
    }

    return null; // 搜救彻底失败
  }

  /// Neighbour-paragraph variant for when an enumeration change moved the
  /// whole paragraph (e.g. a newly recognised cover image shifts every later
  /// index by one).
  ///
  /// [window] holds paragraph texts centred on the stored paragraph (odd
  /// length; `null` = unavailable or an image slot).
  ///
  /// With context, the full `pre+exact+post` signature is searched across the
  /// WHOLE window first, nearest-first and forward before backward (inserted
  /// slots push content forward). Only if that fails is the lenient
  /// [findHealedOffset] tried on the stored paragraph: it trusts a lone
  /// `exact` hit, so running it first would "heal" onto an unrelated
  /// paragraph that merely contains the same word after a shift.
  ///
  /// Without context (legacy rows) nothing can tell paragraphs apart, so the
  /// text is accepted only if it occurs exactly once in the whole window.
  /// Returns the paragraph delta from the centre plus the offset inside it.
  static ({int delta, int offset})? findHealedInWindow(
      List<String?> window, String pre, String exact, String post) {
    if (window.isEmpty || exact.isEmpty) return null;
    final center = window.length ~/ 2;

    if (pre.isEmpty && post.isEmpty) {
      return _findUniqueInWindow(window, exact, center);
    }

    final signature = '$pre$exact$post';
    for (var distance = 0; distance <= center; distance++) {
      for (final delta in distance == 0 ? const [0] : [distance, -distance]) {
        final text = window[center + delta];
        if (text == null) continue;
        final index = text.indexOf(signature);
        if (index != -1) return (delta: delta, offset: index + pre.length);
      }
    }

    final centerText = window[center];
    if (centerText == null) return null;
    final offset = findHealedOffset(centerText, pre, exact, post);
    return offset == null ? null : (delta: 0, offset: offset);
  }

  static ({int delta, int offset})? _findUniqueInWindow(
      List<String?> window, String exact, int center) {
    ({int delta, int offset})? hit;
    for (var i = 0; i < window.length; i++) {
      final text = window[i];
      if (text == null) continue;
      var from = 0;
      while (true) {
        final index = text.indexOf(exact, from);
        if (index == -1) break;
        if (hit != null) return null; // second occurrence: ambiguous
        hit = (delta: i - center, offset: index);
        from = index + exact.length;
      }
    }
    return hit;
  }

  static int _calculateOverlap(String target, String actual,
      {required bool alignRight}) {
    int score = 0;
    int minLen = target.length < actual.length ? target.length : actual.length;
    for (int i = 0; i < minLen; i++) {
      if (alignRight) {
        if (target[target.length - 1 - i] == actual[actual.length - 1 - i]) {
          score++;
        }
      } else {
        if (target[i] == actual[i]) {
          score++;
        }
      }
    }
    return score;
  }
}
