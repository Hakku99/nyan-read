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
