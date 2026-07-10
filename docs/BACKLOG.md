# Backlog · 遗留事项

> 2026-07-10：CODEBASE_ANALYSIS.md（2026-07-07 全库审查报告）的全部问题级条目已修复完毕，
> 报告已删除（完整内容见 git 历史，锚点 commit `05fdd8b`）。以下是从中抽出的未完成事项。

## 测试债（原"第五批"，维护者主动搁置）

1. **~36 条遗留测试失败**（全量套件 `+294 ~4 -36` 的稳定失败集合，已知含
   `selection_chip_sheet_test`）。多为 UI 断言与当前实现漂移；逐条定性后修测试或修实现。
2. **全量套件耗时 ~60 分钟**（290+ 测试不该这么久）——疑似有测试吃满长超时，
   可能与上一条同根。定位方式：`flutter test --reporter expanded` 找耗时尖峰。

## 测试盲区（维护者明确排除出批次）

3. 以下核心模块无测试：**PDF 引擎**、**BookImportFingerprint**（导入指纹/去重）、
   **ContentMetaManager 高亮自愈**（fast/slow-path + 批量 isolate）。
   （EPUB 引擎原本也在此列，2026-07 自研重构时已补成全库测试最厚的模块。）

## 需实机验证（报告标〔需人工确认〕）

4. **iOS 书源沙盒修复验证**：iOS 设备上导入 → 冷启动次日 → 书仍可打开
   （验证 `BookSandboxCopier` 拷贝进 Documents 的行为 + file_picker 临时目录假设）。
   无 iOS 设备时降级为"上架 iOS 前必做"。

## 商业化前置（上架收费前）

5. `is_pro_mode` 明文 SharedPreferences 标志 → 商店内购收据校验（Play Billing /
   StoreKit 本地校验即可，不需要服务器）；同时移除 `FeatureManager.init` 的
   `kDebugMode` 强制 Pro。Pro 重开时：改 `upgradeToProSubtitle` 文案（还写着
   "解锁私密书架"）、按真实付费功能重写 `NyanShelfProNudge` 特性列表、
   打开 `FeatureManager.proSurfacesEnabled`。

## 低优先（报告原判"可接受"，有触发条件才动）

- TXT Big5 检测（gbk 解码伪成功，等真实乱码报告；`txt_reader.dart` 有 `ponytail:` 注释）
- PIN 试错锁定期无专门提示文案（表现为通用错误抖动；`pin_service.dart` 有 `ponytail:` 注释）
- PDF 无真实 outline（每 10 页合成伪章节，pdfx 能力所限）
- 带 tag 的功能 TODO：`#package-info` / `#highlight-detail` / `#share` / `#pin-forgot`
- 小优化：`getBooks` 书架查询可收窄列（不取 `last_position_payload`）；
  `SignatureBackfillService` 逐本 isolate 可合并为单次批处理
