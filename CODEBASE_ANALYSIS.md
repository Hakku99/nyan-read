# 喵阅 Nyan Read · 全库静态代码审查报告（CODEBASE_ANALYSIS）

> 分析锚点：commit `05fdd8b153ce413beadf766641c2f7af8cae79a5` · branch `feat/fable-5-analysis` · 审查日期 2026-07-07
> 审查方式：只读静态审查；唯一命令类动作为一次 `flutter analyze`（结果：仅 1 条 warning，见 M6 线索）。

## 进度追踪（增量落盘）

- [x] M2 数据层（database / backup / signature backfill / models）
- [x] M3 书籍导入与指纹
- [x] M5 阅读器引擎（txt/epub/pdf）
- [x] M6 阅读器控制层
- [x] M7 阅读器 UI
- [x] M4 书架
- [x] M8 亮度子系统
- [x] M9 书签/笔记
- [x] M10 隐私与安全
- [x] M11 设置与全局偏好
- [x] M1 启动/DI/路由
- [x] M12 主题与设计系统
- [x] M13 边缘小模块（admin/ads/tts/l10n）
- [x] 阶段三：跨模块与全局分析
- [x] 阶段五：优先级问题清单

---

# 1. 执行摘要

分析锚点：commit `05fdd8b153ce413beadf766641c2f7af8cae79a5` · branch `feat/fable-5-analysis`。

**整体健康度：中上。** 分层真实、进度持久化五重保险、解析全部离 UI isolate、schema 迁移纪律好、`flutter analyze` 仅 1 条 warning——工程基本功扎实。问题集中在"产品级架构决定"和"半成品/死代码"，而非低级 bug。最需优先处理：

1. **书源不落沙盒 + 清道夫删临时文件**——iOS/桌面导入的书可能自毁（M3，问题清单 #1）；
2. **TXT 编码嗅探残缺**——UTF-16 中文书必乱码且污染高亮/进度锚点（M5，#2）；
3. **删除 Undo 语义欺骗**——撤销回来的书没有笔记、可能没有文件（M4，#4）；
4. **TXT 内嵌网络图**——"完全离线"承诺唯一实质破口（M5，#3）；
5. **EPUB anchor 章节索引沿袭上游 bug**——TOC 跳转错位，违反自家 §3.6 不变式（M5，#6）。

# 2. 新维护者导航

**先读这三个模块**（读懂它们 = 读懂全库）：
- `lib/modules/reader/controllers/reader_controller.dart` 及其三个 Manager——reader 会话如何编排（从 `reader_controller_provider.dart` 的 Riverpod 装配入手）；
- `lib/modules/reader/reader_engine/reader_engine.dart` + `txt/txt_reader.dart`——引擎契约与最完整的实现（TXT 是唯一支持高亮/排版的引擎）；
- `lib/core/services/database_service.dart`——所有持久化真相（schema v9、自愈、冷备恢复）。

**改动最危险的区域**（碰前先读 AGENTS §3.5 受保护面）：
- `epub_parse_helpers.dart` 的段落计数——注释明言必须与上游"逐字节等价"，动它 = 全体用户的 EPUB 进度与高亮错位；
- `ReadingPosition` 的 JSON 字段名与 `books.last_position_*` 列——已持久化在用户设备上，改名即丢进度；
- `BookImportFingerprint._buildSignature` 的输入格式（`nyan-read-v1|...`）——改动使全部已存签名失配，去重与恢复双双失效；
- `_onUpgrade` 迁移链——只可追加，禁止改历史段；
- 删除流程（`deleteBooksWithAssociatedData`）与 `ConflictAlgorithm` 选择——历史上 REPLACE 级联删过用户高亮（代码注释有尸检记录）。

# 3. 模块清单总览表

| 模块 | 路径 | 一句话职责 | 健康度 |
|---|---|---|---|
| M1 启动/DI/路由 | `main.dart`, `core/services/service_locator.dart`, `core/router/` | get_it 异步装配 + go_router 4 路由 | 一般 |
| M2 数据层 | `core/services/database_service.dart` 等 3 服务 + `core/models/` | SQLite v9、冷备份、自愈、签名回填 | 一般 |
| M3 导入与指纹 | `home_screen.dart:_importBook`, `core/utils/book_import_fingerprint.dart` 等 | file_picker → 指纹去重 → 入库 | 需关注 |
| M4 书架 | `modules/bookshelf/` | 双 Tab 书库、多选删除、排序搜索 | 需关注 |
| M5 阅读器引擎 | `modules/reader/reader_engine/` | ReaderEngine 契约 + TXT/EPUB/PDF | TXT/EPUB 需关注；PDF 良好 |
| M6 阅读器控制层 | `modules/reader/controllers/` | 会话编排、进度持久化、高亮自愈 | 一般 |
| M7 阅读器 UI | `modules/reader/` 页面与 widgets | 画布、手势、One Paper chrome | 一般 |
| M8 亮度子系统 | `modules/reader/brightness/` | 硬件亮度 + 暖色温双通道状态机 | 良好 |
| M9 书签/笔记页 | `modules/bookmark/`, `modules/notes/` | 浏览与跳转 | 一般 |
| M10 隐私与安全 | `modules/privacy/`, `core/services/pin_service.dart` 等 | PIN/生物识别/私密书架 | 需关注 |
| M11 设置与偏好 | `modules/settings/`, `core/services/*preferences*` 等 | 去抖落盘偏好、功能开关 | 良好 |
| M12 主题/设计系统 | `core/theme/`, `core/ui/` | NyanTheme token 与 34 组件 | 良好 |
| M13 边缘模块 | `modules/admin|ads|tts/`, `l10n/` | 调试面板/占位广告/TTS stub | 一般 |

---

# 逐模块详细分析

## M2 · 数据层（DatabaseService / BackupRecoveryService / SignatureBackfillService / core/models）

### 职责与架构位置

SQLite（sqflite）单库 `nyan_read.db`（version 9），四张表：`books` / `bookmarks` / `reading_stats` / `highlights`。`DatabaseService` 是唯一 DB 入口（get_it 单例，异步预热）；`BackupRecoveryService` 挂 `WidgetsBindingObserver`，App pause 时用 `VACUUM INTO` 做冷备份（最多 3 份）；`SignatureBackfillService` 启动 15s 后为旧书补算内容签名。被依赖方：书架 VM、导入流程、reader 控制层、书签/高亮服务。

### 关键文件

- `lib/core/services/database_service.dart`（~1040 行，含 schema、迁移、CRUD、自愈、逻辑恢复）
- `lib/core/services/backup_recovery_service.dart`（冷备份/清道夫/导出导入）
- `lib/core/services/signature_backfill_service.dart`
- `lib/core/models/book.dart`（`Book` + `BookStorageType` + `BookSourceType`）

### 逻辑正确性

- **schema 迁移策略存在且规范**〔已确认〕：`_onUpgrade` 全部为增量 `ALTER TABLE`/`CREATE INDEX`，无 DROP；另有 `_ensureHighlightColumns` / `_ensureBookColumns` / `_ensureHotIndexes` 在每次打开时按 `PRAGMA table_info` 防御性补列/补索引（`CREATE INDEX IF NOT EXISTS`），能抵御"版本号漂移但列缺失"的脏安装。升级即丢数据的高危点**不成立**。
- **书删除路径安全**〔已确认〕：`deleteBooksWithAssociatedData` 在单事务内手动删 bookmarks/highlights/books；`insertBook` 显式用 `ConflictAlgorithm.abort` 并注释了历史痛点（`REPLACE` 会触发 FK CASCADE 级联删掉高亮）：
  ```dart
  // Deliberately NOT using ConflictAlgorithm.replace: REPLACE on a books
  // row fires the FK ON DELETE CASCADE path and silently deletes every
  // highlight and bookmark ...
  await db.insert('books', payload, conflictAlgorithm: ConflictAlgorithm.abort);
  ```
- **冷备份一致性正确**〔已确认〕：`backupViaVacuumInto` 用 `VACUUM INTO`（自动并入 WAL 页，无需 sidecar），比旧的三件套裸拷贝正确。备份触发点是 `didChangeAppLifecycleState(paused)`，`unawaited` 有注释说明。
- **自愈流程**〔已确认〕：启动时 `_checkAndHealDatabase` 跑 `PRAGMA integrity_check`，失败则 `_restoreFromLatestBackup`（Isolate 内做文件搬运，候选按 mtime 新→旧逐个尝试，空文件跳过）。逻辑闭环完整。

### 漏洞与隐患

1. **〔已确认·数据丢失边界〕自愈失败的兜底是"删库"**：`_runRestoreFromBackupInIsolate` 先把损坏主库 `_archiveOrDelete`（rename → copy+delete → **bare delete**），再逐候选恢复；若所有候选失败，主库已被移走/删除，用户全部元数据（进度/书签/高亮）清零。第三级 fallback `file.deleteSync()` 时 `.bak` 都不留。触发条件：主库损坏 + 无可用备份（如首日损坏、备份目录被清）。属"损坏后本就难救"的场景，但 bare-delete 分支连尸体都不留，建议至少保住损坏文件供人工救援。证据：`database_service.dart` `_archiveOrDelete` 第三分支 `file.deleteSync(); logs.add('... archived only by deletion (no .bak written) ...')`。
2. **〔已确认·启动性能〕每次冷启动全量 `integrity_check`**：`_checkAndHealDatabase` 无条件对整库跑 `PRAGMA integrity_check`（O(库大小)），且在 `getIt.allReady()` 之前、主 isolate 上等待（sqflite channel 本身在平台线程执行，但启动被它串行阻塞，`main.dart` 有 5s DI 超时——大库 + 低端机可能直接触发 `_BootstrapErrorApp`）。证据：`_initDatabase` → `await _checkAndHealDatabase(path)`；`main.dart` `setupServiceLocator().timeout(const Duration(seconds: 5))`。建议改为 `PRAGMA quick_check` 或抽样/隔日校验。
3. **〔已确认·注入面（低危）〕`VACUUM INTO` 用字符串拼接**：`backupViaVacuumInto` 把路径拼进 SQL：`await db.execute("VACUUM INTO '$safePath'")`。已做 `'` 转义且路径来自内部 `getDatabasesPath()`，当前不可注入；但这是唯一一处拼 SQL 的地方，若未来路径来源变化会成暗雷。
4. **〔已确认·恢复语义〕`restoreDataBatch` 的 title fallback 仍可交叉污染**：签名优先匹配正确，但 legacy fallback 用 `localByTitle[title]`——同名书多本时 Map 后写覆盖前写，恢复目标取决于遍历顺序（书库查询无 ORDER BY）。已有 `[Restore][legacy]` 日志意识到此事，风险窗口只剩"两侧都无签名"的旧数据。
5. **〔已确认·代码坏味道〕Mojibake 注释残留**：`database_service.dart` 中 `// --- 鍏ㄩ噺鏁版嵁瀵煎嚭鎺ュ彛 (For Global Export) ---`（UTF-8 被 GBK 二次解码的乱码），说明历史编码事故清理未尽。
6. **〔已确认·死 schema〕`reading_stats` 表建而不用**：`_onCreate` 创建了 `reading_stats`，但 `DatabaseService` 无任何读写该表的方法（全文件仅出现在 CREATE TABLE）。死 schema + 潜在"统计功能未完成"信号。
7. **〔疑似·并发〕备份与写库并发**：`VACUUM INTO` 在 SQLite 层与写并发是安全的（共享读锁），注释正确；但 pause 时若正好在 `restoreDataBatch` 大批量写入中，备份会拿到"恢复到一半"的一致-但-半成品快照。属可接受的边界，不算实锤。
8. **〔已确认·导出隐私面（低）〕`exportGlobalUserData` 把全部书目（含 `file_path` 绝对路径）与全部笔记明文写入临时目录 JSON**，随后经 share 流转。本地离线 App 可接受，但违反自家 AGENTS §2.2.4 "日志不得输出绝对路径" 的精神——导出文件里包含全部绝对路径。

### 优化方向

- `integrity_check` → `quick_check` 或降频（`database_service.dart:_checkAndHealDatabase`）。
- `getBooks` 每次全列查询（含 `last_position_payload`），书架列表其实不需要 payload 列；大书库可收窄列。
- `SignatureBackfillService` 逐本 `Isolate.run`（每本一个 isolate 启停开销）；可合并为单 isolate 批处理，但一次性后台任务，优先级低。

### 状态管理判定

服务层无状态管理框架，纯异步服务 + get_it 注入，规范。

**健康度评级：`一般`**（结构与迁移纪律良好；扣分项：启动路径 integrity_check、自愈兜底删库、死 schema）。

---

## M3 · 书籍导入与指纹（BookImportFingerprint / BookSourceAccess / 导入管线）

### 职责与架构位置

导入入口在书架页 `home_screen.dart:_importBook`（file_picker 多选）→ `_resolveImportedSource` 决定来源类型（Android SAF `content://` 持久化授权 vs 文件路径）→ `BookImportFingerprint` 去重 → `db.insertBook`。`BookSourceAccess` 是引擎读取书源的统一门面（文件 or Android MethodChannel）。

### 关键文件

- `lib/modules/bookshelf/home_screen.dart`（`_importBook` / `_resolveImportedSource` / `_cleanupPickerTempFiles`）
- `lib/core/utils/book_import_fingerprint.dart`（采样指纹 + 去重索引）
- `lib/core/utils/book_source_access.dart` / `book_source_platform.dart`（MethodChannel `com.example.nyan_read/book_source`）
- `lib/modules/bookshelf/epub_cover_extractor.dart`（Isolate 内 OPF 封面 → 缩放 → JPEG）

### 逻辑正确性

- 去重双保险〔已确认〕：`normalizedLocators`（路径归一化小写）+ `content_signature`；导入循环内边导入边把新签名/locator 加入 known 集合，同批次重复文件也能拦住。
- Android SAF 正确〔已确认〕：`content://` 走 `persistReadPermission`（持久化 URI 授权），失败则放弃该文件并日志；读取经 MethodChannel。
- 每文件独立 try/catch，单文件失败不炸整批〔已确认〕。

### 漏洞与隐患

1. **〔疑似·高危·数据可用性〕导入从不拷贝进 App 沙盒，且导入源可能是"临时文件"**：证据链：
   - `_importBook` 建书时恒为 `storageType: BookStorageType.externalPath`（`home_screen.dart`），全仓无任何"拷贝到应用文档目录"的导入路径——`BookStorageType.appPrivateCopy` 只在 `_backfillBookStorageTypes` 的历史回填里被赋值，是僵尸枚举值。
   - 非 Android（iOS/桌面）分支 `sourceLocator = file.path`——file_picker 在 iOS 上返回的是**拷贝到临时/缓存目录的副本路径**（需实机核实，标〔需人工确认〕），iOS 系统会清理该目录。
   - 更糟：`BackupRecoveryService.runCacheScavenger` 每次启动 5s 后删除 `getTemporaryDirectory()` 下**所有超过 24 小时的文件**（`_heavyCacheCleanupTask`，无扩展名/目录白名单）。若 file_picker 的 iOS/桌面副本恰好落在同一临时沙盒，**导入次日书就被自家清道夫删了**。
   - Android 主路径（`content://`）不受影响；Windows/Linux picker 通常返回原始路径，也不受影响。风险集中在 iOS 与"picker 返回缓存副本"的平台组合。
   - 综合判定：**架构上"书源=外部路径"这一决定使书籍可用性依赖外部文件的生死**，App 已有 `BookSourceAccess.unavailableMessage` 兜底文案（"Remove it from your bookshelf and import it again"），说明作者知道并接受了这个模型；但"自家清道夫可能杀死自家书源"这条组合路径大概率不在预期内。
2. **〔已确认·契约漂移〕"content_signature = SHA-256 of the source bytes" 是假的**：`database_service.dart` 的 restore 注释声称签名是全文件 SHA-256，实际 `BookImportFingerprint._buildSignature` 是 `sha256('nyan-read-v1|扩展名|文件大小|' + 头64KB + 尾64KB)` 的**采样指纹**。后果：(a) 两个大小相同、头尾 64KB 相同、中间不同的文件会被判为同一本书（去重误杀 + 恢复错绑笔记）——对"同一系列小说改了中间章节再导出"这类 TXT 场景并非纯理论；(b) 改扩展名（.txt→.TXT 归一化了吗？`ext` 取 `path.extension().toLowerCase()`，同名不同扩展签名不同）会破坏"重命名仍能匹配"的承诺。概率低但契约文档与实现不一致，至少该修注释。
3. **〔已确认·内存〕SAF 读取整书进内存并跨 channel**：`BookSourcePlatform.readUriBytes` 用 `invokeMethod<Uint8List>` 一次性把整本书从原生侧拷进 Dart 堆。EPUB/PDF 数百 MB 时是 OOM 面（PDF 有 `copyUriToTempFile` 旁路，EPUB/TXT 没有）。
4. **〔已确认·UX 边界〕全部失败时无任何反馈**：`_importBook` 内 per-file `catch (e) { debugPrint... }`，若所有文件都异常失败（`successCount==0 && skippedCount==0`），最后既无 success 也无 skipped toast，loading toast 之后直接静默结束。
5. **〔已确认·低危〕`format` 字段大小写不归一**：`format: path.extension(fileName).replaceAll('.', '')`——`BOOK.EPUB` 得 `format='EPUB'`。下游 `ReaderFactory` 如何匹配需在 M5 核对（若大小写敏感则打不开大写扩展名的书；见 M5 结论）。

### 优化方向

- 导入时（至少对 iOS/桌面路径源）拷贝进应用文档目录并置 `storageType=appPrivateCopy`，一劳永逸解决书源失效；这是 `storage_type` 字段显然预留的方向。
- `runCacheScavenger` 加白名单/目录过滤，避免与 file_picker 缓存互踩。
- 去重索引 `buildExistingIndex` 每次导入全表查询后在内存建索引，书库万本级别时可换成 SQL `WHERE content_signature IN (...)` 逐条判重；当前规模无碍。

### 状态管理判定

导入流程写在 `HomeScreen`（ConsumerState）内，直接 `ref.read` 服务 + 命令式流程；无状态框架滥用，但导入这种多步业务落在 Widget 里偏重（见 M4 坏味道）。

**健康度评级：`需关注`**（去重与 SAF 处理扎实；扣分项：书源生命周期模型 + 清道夫互踩的组合风险、签名契约漂移）。

---

## M5 · 阅读器引擎（ReaderEngine 契约 + TXT / EPUB / PDF 实现）

### 职责与架构位置

`reader_engine.dart` 定义 `ReaderEngine` 抽象（initialize / buildReader / goToPosition / getCurrentPosition / getProgress / getChapters / nextPage…）+ `ReadingPosition` + `ReaderCapabilities`（三级 `CapabilityLevel`）+ 三个可选 capability 接口（TextReader / TextExtraction / PageMetrics）。`ReaderEngineFactory.create(book)` 按 `book.format.toLowerCase()` 分派——**导入时 format 大小写不归一（M3-5）在此被 `toLowerCase()` 化解，不是 bug**；但 unknown format 默认落 `TxtReaderEngine`（把 PDF 当 TXT 解析出乱码，而非显式报错）〔已确认，`reader_factory.dart` `default: return TxtReaderEngine(book)`〕。

### 进度锚点判定（指令稿重点，最终结论）

| 格式 | 锚点 | 类型 | 漂移风险 |
|---|---|---|---|
| TXT | `paragraphIndex`（行号）+ `paragraphLeadingEdge/TrailingEdge`（视口对齐比例） | **稳定锚点** | 改字号/字体/行高后 paragraphIndex 不漂；edge 是视口内微调，最多页内偏移半行。重新解析行号确定（同一解码结果下）。唯一漂移源：**编码嗅探结果变化**（见下）会改变行切分 |
| EPUB | `cfi`（epub_view 生成的 EPUB CFI）主 + `paragraphIndex` 辅 | **稳定锚点** | CFI 与排版无关，最优方案 |
| PDF | `pageNumber` | **天然稳定** | 无 |

结论：进度锚点设计**正确**，"改字号后进度漂移"的经典 bug 在此项目基本不存在。页码（`_totalPages`）只是显示用估算值，不参与锚点存储——设计干净。

### TXT 引擎（`txt/txt_reader.dart` ~1370 行 + `pagination_helper.dart` + `txt_position.dart`）

**逻辑正确性亮点**〔已确认〕：解析（解码+分行+段偏移+章节识别）单次 `compute()` 全离 UI；正文以 UTF-8 bytes + 行 range 索引存储（省一半内存）；分页估算按 `_PaginationLayoutKey`（viewport+fontSize+lineHeight+padding+orientation+textScaleFactor+paragraphBottomMargin）去重且回程校验 key 未失效（§3.4 合规）；章节识别正则有长度预过滤（`maxChapterLineLength = 500`）防回溯爆炸；翻页有 anchor 栈（48 深）支持"翻回上一页精确还原"。

**漏洞与隐患：**

1. **〔已确认·高危·编码兼容〕编码嗅探链过短，UTF-16 必乱码**：
   ```dart
   String _decodeBytesForParse(Uint8List bytes) {
     try { return utf8.decode(bytes); }
     catch (_) { try { return gbk.decode(bytes); } catch (_) { return latin1.decode(bytes); } }
   }
   ```
   无 BOM 检测、无 UTF-16 LE/BE、无 Big5；`latin1.decode` **永不抛错**，因此任何 UTF-16 文件（Windows 记事本"Unicode"存档，中文 TXT 生态常见）会经 utf8 失败 → gbk 失败/伪成功 → latin1 兜底 → 全书乱码且**无任何用户提示**。GB18030 四字节区在 fast_gbk 下的行为也未验证〔需人工确认〕。指令稿点名的"txt 编码嗅探"专项：**不合格**。
2. **〔已确认·安全/隐私〕TXT 内嵌 `<img>` 渲染允许网络加载**：`_buildImageByUri` 中 `if (sourceUri.scheme == 'http' || 'https') provider = NetworkImage(...)`。一本从网上下载的 TXT 只要嵌入 `<img src="https://tracker.example/pixel.png">`，打开即发起网络请求——**"完全离线、无遥测"的产品承诺被书内容本身击穿**（IP、阅读时间点泄露给任意第三方）。同函数还支持 `file://` 与 Windows 绝对路径（`_looksLikeWindowsAbsolutePath` → `File(src).uri`）加载本地任意图片——展示给用户本人，泄露面低，但组合上仍是"书内容驱动的本地文件探测"。
3. **〔已确认·规范偏离〕`TextPainter.layout` 实际发生在 build 帧内**：`buildReader` 的 `LayoutBuilder` builder 里调 `_recalculatePagination(...)`（未 await），而 `PaginationHelper.calculatePageEstimate` 是 async 函数但**首个 await 之前**就完成了 `textPainter.layout(...)`——Dart async 函数在首个 await 前同步执行，所以 3000 字符的 layout 就在 build 里跑。有 layout-key 去重兜底、单次成本 ~ms 级，实际影响小，但违反 AGENTS §3.4 "不在同步 build() 中完成" 的字面要求。另外该 `TextPainter` 从不 `dispose()`。
4. **〔已确认·错误语义〕`initialize` 把一切异常揉成 `FormatException('Failed to parse TXT file: $e')`**：文件不存在（源被移动/删除）也会被报成"解析失败"，上层错误视图无法区分"文件坏了"和"文件没了"（`BookSourceAccess.unavailableMessage` 有专门文案却走不到）——需 M6/M7 核对上层是否先行 `isAvailable` 检查。
5. **〔已确认·低〕引擎内建底部 bar 硬编码样式**：`buildReader` 内 `fontSize: 10`、`height: 20`、硬编码 padding——绕过设计 token（引擎层不在 §2.2.3 管辖内是灰色地带，但同项目 PDF 引擎已用 `resolveNyanTheme`）。
6. **〔已确认·优化点〕`_getLine` 每次 `sublist`+`utf8.decode`**：滚动中 itemBuilder 反复解码同一行（无缓存）且 `sublist` 拷贝（可用 `Uint8List.sublistView`）。长列表快速滚动时的重复分配热点。

### EPUB 引擎（`epub/epub_reader.dart` + `epub_parse_helpers.dart`）

**亮点**〔已确认〕：解析走 `compute(parseEpubBytesInIsolate)`，只回传轻量 DTO；私有 `epub_view/src/` import 已剥离（内联算法并注明"必须与上游逐字节等价"的原因）；坏 EPUB 有"缺资源自动打补丁"容错循环（`_openEpubWithMissingResourceTolerance`，最多 8 次，向 zip 里补空条目）。

**EPUB 专项安全排查（指令稿点名的高危区）：**

- **Zip Slip / 路径穿越：不成立**〔已确认〕。全链路（`epubx`/`epub_view`/`archive`）均为**内存内解压**，本项目代码从不把 EPUB 条目写到文件系统（`epub_parse_helpers.dart` 只有 `ZipDecoder().decodeBytes` + 内存 `ArchiveFile`），无落盘即无穿越。
- **解压炸弹 / OOM：成立（疑似）**。恶意构造的高压缩比 EPUB 在 `ZipDecoder().decodeBytes(sourceBytes)` 与 `EpubDocument.openData` 时全量解压进内存，无大小上限检查；且正常路径本身就是**双份解析**（isolate 一次 + 主 isolate `openData` 再一次，代码注释承认这是权衡），50MB EPUB 的稳态内存 = 原始 bytes + 主 isolate 整棵 `EpubBook` 图（全部章节 HTML 字符串）。大 EPUB 是明确的 OOM 面。〔疑似·需运行时验证具体阈值〕
- **HTML/CSS 渲染注入：低风险**〔已确认（架构层面）〕。渲染走 `epub_view` 的 Flutter widget 树（非 WebView），**无 JS 执行环境**；书内脚本天然死路。epub_view 内部对 `<img>` 网络资源的行为未审计〔需人工确认〕——若其 HTML 渲染器也允许 NetworkImage，则与 TXT-2 同类的追踪信标问题在 EPUB 同样存在。
- XXE：`package:html` 是 HTML 解析器不解析外部实体，不成立（一句话带过）。

**漏洞与隐患：**

7. **〔已确认·功能正确性〕上游 chapter-anchor 索引 bug 被"忠实保留"**：`computeEpubParseResult` 对带 `Anchor` 的章节 `chapterIndexes.add(index)`（章内相对索引）而非 `paragraphCount + index`（绝对索引），代码注释明说"looks suspicious but we mirror it faithfully"以兼容已持久化的位置。后果：使用 anchor 定位章节的 EPUB（同一 HTML 文件多章节的常见结构），TOC 跳转会跳到**书开头附近的错误段落**，且底部进度条章节与 TOC 高亮不一致——直接违反自家 §3.6 不变式"章节导航必须与进度条一致"。这是"为兼容旧数据而冻结的已知错误"，属产品级债务。
8. **〔已确认·性能〕`applyMissingResourceStubs` 在主 isolate 重编码整个 zip**：`initialize()` 中 `compute` 返回后，若有缺失资源，主线程跑 `ZipDecoder().decodeBytes + ZipEncoder().encode`（整本书大小）——只影响坏书，但正好是"坏书修复"场景卡 UI。
9. **〔已确认·UX/正确性〕EPUB 翻页按"一个段落"步进**：`nextPage()` 计算 `targetIndex = currentIndex + 1`（段落 +1）再 `seekToProgress`——点按翻页在 EPUB 上不是翻一屏而是挪一段，与 TXT 的"翻一视口"语义不一致。
10. **〔已确认〕EPUB capabilities 全 none**（typography/theme/highlights 均 `CapabilityLevel.none`）：字号、行高、serif、主题、高亮在 EPUB 全不生效——产品功能面差距大，靠 capability 系统"诚实降级"，但用户视角是"EPUB 什么都调不了"。
11. **〔已确认·健壮性〕`_extractMissingArchivePath` 靠解析异常字符串** `RegExp(r'file (.+?) not found in archive')` 识别缺资源——epubx 换错误文案即失效（静默降级为直接抛错，可接受但脆）。

### PDF 引擎（`pdf/pdf_reader.dart`）

**亮点**〔已确认〕：`initialize()` 把"解析源+打开文档"整个 Future 交给 `PdfController`，首帧即返回；`_isDocumentReady` 闸门保护所有查询方法；`dispose()` 有 in-flight future 的临时文件清理接力（注释详尽）；占位/错误 UI 用 `resolveNyanTheme` 合规取色。

12. **〔已确认·功能〕PDF 无真实目录**：`getChapters()` 每 10 页合成一个 "Page N" 伪章节（`isSynthetic: true`），未读 PDF outline（pdfx 能力所限）。
13. **〔已确认·低〕`seekToProgress` 页码换算**：`(progress * (count - 1)).round() + 1`，与 `getProgress` 的 `page / count` 不是同一映射（往返 seek(getProgress()) 会偏 1 页内）——微小不对称，实际无感。

### 状态管理判定

引擎内部用 `ValueNotifier`（config / highlightVersion / pageInfo）+ listenable 订阅，符合 §2.3 高频值规范。

**健康度评级：TXT `需关注`（编码嗅探+img 网络加载）；EPUB `需关注`（anchor 索引债+内存双份+能力面）；PDF `良好`。**

---

## M6 · 阅读器控制层（ReaderController + 三 Manager + BrightnessController）

### 职责与架构位置

`ReaderController`（ChangeNotifier + WidgetsBindingObserver）是 reader 会话的编排根：构造时经 `ReaderEngineFactory` 建引擎，组装 `ReaderSettingsManager`（设置→引擎 config）、`ContentMetaManager`（章节/书签/高亮）、`ReadingProgressManager`（心跳/持久化）。创建/销毁由 Riverpod `readerControllerRpProvider`（autoDispose.family）托管，服务经构造器注入（Phase 3 目标达成）。

### 关键文件

`reader_controller.dart`、`reading_progress_manager.dart`、`content_meta_manager.dart`、`reader_settings_manager.dart`、`brightness_controller.dart`、`reader_controller_provider.dart`、`core/utils/anchor_healer.dart`、`core/utils/lifecycle_registry.dart`。

### 逻辑正确性（进度持久化链路——指令稿重点，判定：健壮）

〔已确认〕进度写入时机有**五重保险**：① 30s 周期自动保存（`startTracking` 注册 `Timer.periodic(30s)`）；② `seekTo`/章节跳转后立即保存；③ App pause/detached（`didChangeAppLifecycleState` → `saveForLifecyclePause` + prefs flush）；④ 正常退出 `saveBeforeExit`（PopScope 路径）；⑤ **dispose 兜底快照**：`scheduleDisposeFallbackSave` 同步抓取引擎状态快照后 fire-and-forget 落库，注释明确说明为什么不能复用 `saveCurrentPosition`（in-flight 去重可能拿到还在摸引擎的旧 Future，而引擎即将 dispose）：
```dart
// IMPORTANT: the caller is about to dispose the engine.  We must read
// every piece of engine state synchronously here and hand the detached
// snapshot to a fire-and-forget DB write whose continuation never
// touches the engine again.
```
杀进程丢失窗口 ≤30s（仅当 OS 未派发 pause 事件，如 crash/强杀），符合行业常规。`_loadBook` 先 `BookSourceAccess.isAvailable(book)` 前置检查再 initialize——M5-4 的错误语义混淆在控制层被兜住（fileNotFound 与 parseFailed 分开），草稿区线索 12 关闭。翻页有 `_pageTurnQueue` Future 链串行化防重入〔已确认〕。

### 漏洞与隐患

1. **〔已确认·数据完整性（低概率）〕`_errorState` 分类靠异常字符串匹配**：`errorStr.contains('file not found')` / `contains('format')`——脆弱但有 isAvailable 前置检查垫底，仅影响错误文案准确性。
2. **〔已确认·僵尸功能〕阅读时长只进内存不落库**：`ReadingProgressManager._readSeconds` 每秒累加，但全仓无任何持久化（`reading_stats` 表零写入，见 M2-6）；`shouldShowReminder`（3600s 取模）也无调用方。**阅读统计是"建了表、加了计数器、没接管线"的半成品功能**。
3. **〔已确认·可维护性·重灾区〕`content_meta_manager.dart` 中文注释全量 Mojibake**：约 20 处注释呈 `閸旂姾娴囨妯瑰瘨...` 状（UTF-8→GBK 二次解码损坏），包括解释高亮自愈 Fast/Slow-Path 的关键注释。代码意图靠注释不可读，历史编码事故未清理（AGENTS Phase 2 声称"日志全部英文化"，但注释没救回来）。
4. **〔已确认·性能〕高亮自愈逐条 spawn isolate**：`_healHighlights` 循环内对每条需要慢路径修复的高亮 `await Isolate.run(...)`（串行、每条一个 isolate 启停）。触发场景恰是"编码/文本变化导致全书高亮偏移"——那时可能是几十上百条，打开书时串行 spawn 几十个 isolate。应批量合并为单次 `Isolate.run`。
5. **〔已确认·死代码〕`anchor_healer.dart` 的 `_HealingRequest` + `_runAnchorHealingInIsolate` 无引用**（flutter analyze 唯一 warning）：compute 版通道废弃，实际走 `Isolate.run` 闭包。应删除。
6. **〔已确认·裸 Future〕`_healHighlights` 内 `_db.updateHighlightHealedOffset(h.id, ...)` 直接丢弃 Future**，无 `unawaited()` 包装与注释——违反自家 §2.2.2（该方法 docstring 自称 fire-and-forget，但调用点没按规范标注）。
7. **〔已确认·行为怪癖〕`ReaderSettingsManager.handleLayoutChange` 会按视口宽度自动改字号**：`scaleFactor = (newSize.width / 800).clamp(0.7, 1.5)`，与用户手动设置的字号差 >1pt 就覆盖（不落盘、仅会话内）。旋转屏幕/分屏时用户字号被静默改掉，且直接改 `_fontSize` 绕过 preferences——与"UI 偏好唯一拥有者是 ReaderPreferencesService"（§3.3）冲突。疑似早期"响应式字号"实验残留。
8. **〔已确认·低〕`setFontSize` 双重通知**：`setFontSize` 自己 `_updateEngineConfig + onSettingsChanged`，而 `preferences.setFontSize` 的 `notifyListeners` 又触发 `_handlePreferencesChanged` 再来一轮——同帧两次全量重算（幂等无害，白做一次）。
9. **〔疑似·EPUB 恢复时序〕`restoreLastPosition` 靠 `delayed(180ms)` / `delayed(120ms)` 等视图就位**：配合 epub_reader 内部 `_waitForViewReady`（5s 超时）双保险，慢设备上首次恢复仍可能落在视图未布局完成时——有 progress fallback 垫底，最坏错位一屏，非丢失。

### AnchorHealer 算法评注

三段式（preContext+exact+postContext）→ 降级唯一匹配 → 多候选重叠权重仲裁（阈值 30%）。逻辑正确、边界处理完善（clamp 齐全），是全仓质量最高的纯算法文件之一〔已确认〕。

### 状态管理判定

高频值（progress/brightness/warmth/HUD）全部走 `ValueNotifier`，结构性状态走 ChangeNotifier 回调，与 §2.3 完全一致；`BrightnessController` 的 dispose 链（cancel timer → remove listener → dispose 全部 notifier）无遗漏〔已确认〕。

**健康度评级：`一般`**（进度持久化链路扎实是最大亮点；扣分：Mojibake 注释、半成品统计、逐条 isolate、字号自动覆盖怪癖）。

---

## M7 · 阅读器 UI（ReaderPage + 手势 + One Paper chrome + 高亮渲染）

### 职责与架构位置

`reader_page.dart`（~1020 行，另含两个 `part` 文件：`reader_page_overlay.dart` 顶栏、`reader_page_gesture_handler.dart` 手势）是 reader 门面：FutureBuilder 取书 → Riverpod 拿 `ReaderController` → Stack 八层（引擎画布 / 错误视图 / 左缘亮度手势区 / 浮动顶栏 / scrim / OnePaperDock / 亮度弹层 / 休息提醒遮罩）。`highlightable_text.dart` 是 TXT 高亮渲染核心；`smooth_page_reader.dart` 做截屏式翻页动画。

### 逻辑正确性

〔已确认〕手势层质量高：tap/pan 区分（20px 阈值）、翻页三重防抖（350ms tap 去重 + 220ms 最小间隔 + `_isPageTurning` 锁带 3s 超时自愈）、慢拖（划选文本）不误翻页（速度/位移双阈值）。退出双路径（PopScope + 顶栏返回键）都走 `saveBeforeExit`。休息提醒的 `Listener(opaque)` 命中测试屏蔽注释清晰。`HighlightableText` 的 recognizer 池 + TextSpan 缓存（四元组键）+ dispose 全量回收，与 AGENTS Phase 1 P0-3 描述一致，无泄漏〔已确认〕。

### 漏洞与隐患

1. **〔已确认·性能/文档漂移〕整页重建范围与注释宣称的"最小订阅"不符**：`build` 顶层 `ListenableBuilder(listenable: controller)` 包住整个 PopScope→Scaffold→八层 Stack（`reader_page.dart` `return ListenableBuilder(listenable: controller, builder: ...`），任何一次 `controller.notifyListeners()`（章节同步、设置变更、meta 变化）都重建全页；其内部还嵌着两层同 listenable 的 `ListenableBuilder`（阅读画布、章节标签），成为冗余订阅。代码内注释仍写着 "Selector on a record so it only rebuilds when (backgroundColor, progress, hasBottomBar) actually change"——描述的是 Phase 1 的 provider `Selector` 实现，Riverpod 迁移（P2-2）时被降级成了全页 ListenableBuilder，**Phase 1 的 P0-2 优化实质上被回退**。好在最高频的 progress 心跳走 `progressListenable`（不触发 notifyListeners），未复发每秒重建；但滚动中的章节同步（250ms 去抖）仍是全页重建。
2. **〔已确认·规范偏离〕`_fingerprintHighlights` 在每次 build 中 `.where().toList()..sort()`**（`highlightable_text.dart`）：缓存命中路径也要先算指纹（含排序）。段落数 × 高亮数小则无感，违反 §3.4 "build 内不得 .sort()" 的字面规则，量大时是滚动热点。
3. **〔已确认·联网面〕划词"Search"直接拉起 Google 搜索**（`_searchInBrowser` → `launchUrl('https://www.google.com/search?q=...')`）：用户主动触发、外部浏览器打开，可接受；但作为"完全离线"产品应在阶段三联网行为清单中记账。
4. **〔已确认·hack〕高亮跳转用手写 JSON 字符串**：`_openHighlightsPage` 里 `'{"paragraphIndex": ${result.paragraphIndex}}'` 拼 payload 再走书签恢复通道——绕过 `ReadingPosition.toJson()`，类型安全为零；EPUB 书的高亮跳转走此路径时只有 paragraphIndex 而 EPUB `goToPosition` 只认 CFI，**EPUB 高亮跳转是死路**（但 EPUB capabilities.highlights=none，当前不可达，属埋雷）。
5. **〔已确认·部分模块〕书签/笔记列表页用非懒加载 `ListView(...)`**（`bookmark_list_page.dart` `return ListView(`、`notes_list_page.dart` 同）——单书书签量小可接受，违反 §3.4 "列表型组件使用 builder" 字面规则。
6. **〔已确认·低〕`configureInteractions` 在每次 build 里重绑回调**——幂等、开销可忽略，但属于 build 副作用。

### 优化方向

- 恢复最小订阅：顶层改 `ListenableBuilder` → 仅包需要的 slice（或迁 Riverpod `select`），删两处冗余内层订阅（`reader_page.dart`）。
- `_fingerprintHighlights` 结果随 `setHighlights` 版本号缓存，build 内只做 int 比较。

### 状态管理判定

页面局部 UI 态（sheet 状态机、popover、rest reminder）用 `setState` + `ValueNotifier`，控制器经 Riverpod 提供——方案统一；唯独订阅粒度回退（见 1）。

**健康度评级：`一般`**（手势与 chrome 状态机成熟；主要债务是订阅粒度回退与注释失真）。

---

## M4 · 书架（HomeScreen / BookshelfViewModel / 详情页 / 搜索页）

### 职责与架构位置

`home_screen.dart`（~1100 行）是最大的 UI 文件：书架双 Tab（Public/Private）、导入管线（见 M3）、多选删除/移动、排序 sheet、吸顶工具栏、Continue Reading 英雄卡、Discover/Pro 广告位挂载。`BookshelfViewModel`（ChangeNotifier，Riverpod 提供）持有公开/私密两份书列表与选择态。

### 逻辑正确性

〔已确认〕列表/网格渲染保持懒加载（`DecoratedSliver` 包 `SliverList`，注释明确"so the inner SliverList stays lazy"）；批量删除/移动走 DB 事务；多选全选逻辑正确；删除确认 sheet（U21）带 "also delete files" 开关。

### 漏洞与隐患

1. **〔已确认·数据丢失·UX 陷阱〕删除后的 "Undo" 只还原书行，不还原书签/高亮，也复活不了已删的文件**：`deleteSelectedBooks` 先 `_db.deleteBooksWithAssociatedData`（书签高亮永久删除）+ 可选物理删文件，随后 toast 提供 `Undo`（`home_screen.dart` `actionLabel: loc.undo, onActionTap: () => _undoDelete(context)`）；`undoLastDelete` 仅 `insertBook(bookMap)` 回插书行（`bookshelf_view_model.dart` 注释自认 "associated data ... is not restored"）。用户视角"撤销"了删除，实际笔记全没了；若勾了删文件，撤销回来的书行指向已不存在的文件（打开报 fileNotFound）。**Undo 语义与用户预期严重不符。**
2. **〔已确认·低〕`undoLastDelete` 逐本 `await _db.insertBook`**（循环内单条 insert，无事务/batch）——违反自家 §2.4 ">3 条用 batch"；批量删除 50 本再撤销时是 50 次串行往返。
3. **〔已确认·僵尸代码〕封面通道半残**：`books.cover_path` 列建了从未读写（全仓仅 CREATE TABLE 一处出现）；书架格子从不显示真实封面；唯一的封面渲染在详情页 `_BookHeroCover`，且**每次进详情页都全量读整本 EPUB 进内存再进 isolate 抽封面**（`book_details_page.dart` `_loadCoverBytes`，注释自认 "large EPUBs cost RAM"），无磁盘缓存。AGENTS §2.4 的"封面缓存 ≤100MB + LRU"规则管辖着一个不存在的缓存。
4. **〔已确认·低〕`_resolveContinueReadingBook` fallback 到 `books.first`**：一本没读过的新书库会把第一本当"继续阅读"（按钮文案有 `startReading` 分支处理，可接受）。

### 状态管理判定

Riverpod（`bookshelfViewModelRpProvider`）+ ChangeNotifier VM + 局部 `ListenableBuilder`——方案统一；导入等多步业务写在 Widget State（`_importBook` 200 行）职责偏重，建议下沉 VM。

**健康度评级：`需关注`**（Undo 语义陷阱 + 导入业务在 UI 层 + 封面半成品）。

---

## M8 · 亮度子系统（Orchestrator / Repository / SystemAdapter / Overlay）

### 职责

双通道：硬件亮度（`screen_brightness` 经 `SystemBrightnessAdapter`）+ 暖色温 overlay（`overlay_widget.dart` 按 `OverlayBrightnessPolicy` 算透明度）。`BrightnessOrchestrator`（~490 行状态机）处理 manual/followSystem 双模式、后台还原/恢复渐变（1.2s ease ramp）、系统亮度回声抑制（`_ignoredSystemBrightness`）、写入队列去重（`_drainManualApplyQueue`）。

〔已确认〕状态机质量高：模式切换动画、后台保存 manual target、恢复 ramp、echo 抑制均有注释与防御。`_safeXxx` 包装吞错但有 fallback 语义（brightness 拿不到就用上次观测值），可接受。

### 漏洞与隐患

1. **〔疑似·debug 崩溃〕`BrightnessOrchestrator.dispose()` 与 in-flight `shutdown()` 竞态**：`dispose()` 是 `unawaited(shutdown())` + `super.dispose()`；若此前 `reader_page.dispose` 发起的第一次 `shutdown()` 还在 `await _systemBrightnessSubscription?.cancel()` 之后的异步段，`restoreOriginalBrightness()` → `_setState` → `notifyListeners()` 会打在已 `super.dispose()` 的 ChangeNotifier 上——debug 断言崩溃（release 下多为无害空遍历）。触发窗口极窄（一帧内退出 reader），实机偶发闪退日志可查此处。
2. **〔已确认·低〕`didChangeAppLifecycleState` 对 `inactive` 也触发 `_handleBackgrounding`**：iOS 上拉控制中心/来电即还原系统亮度，回来再 ramp——行为可能偏敏感，属产品取舍。

**健康度评级：`良好`**（该子系统连同 `brightness_orchestrator_test.dart` 是全仓工程质量标杆）。

---

## M9 · 书签 / 笔记高亮浏览

`bookmark_list_page.dart` / `notes_list_page.dart`：从 DB 读列表 → push 页面 → pop 回位置数据由 reader 恢复。逻辑直白。

1. **〔已确认·死代码〕`modules/bookmark/bookmark_service.dart`（内存态 ChangeNotifier）与 `core/models/bookmark.dart` 零调用方**——真实书签直接走 `DatabaseService` 的 Map 行。整组文件是早期原型残留。
2. **〔已确认·低〕两个列表页用非懒加载 `ListView(...)`**（见 M7-5）。
3. 〔已确认〕列表页与 reader 的数据交接用裸 `Map<String, dynamic>`（`position_type`/`position_payload` 字符串键），无类型模型——坏味道，改字段名即静默断裂。

**健康度评级：`一般`**。

---

## M10 · 隐私与安全（PIN / 生物识别 / 私密书架）

### 现状

真实链路：`PrivacyLockService` → `PinService`（`flutter_secure_storage` 存 SHA-256(pin+salt)，salt 为时间戳）→ `PinOverlayPage` 全屏遮罩（U16）+ `BiometricService`。私密书架 = `books.is_private` 标志 + Tab 可见性门禁（`isPro && isPrivateShelfUnlocked`），后台 3 分钟自动锁（`main.dart`）。

### 漏洞与隐患

1. **〔已确认·高危写法但为死代码〕`modules/privacy/privacy_service.dart` 含硬编码 AES 密钥 + 明文 PIN**：
   ```dart
   final _key = encrypt.Key.fromUtf8('my32lengthsupersecretnooneknows1');
   final _iv = encrypt.IV.fromLength(16); // 全零 IV
   ...
   await prefs.setString('privacy_pin', pin); // 明文 PIN 进 SharedPreferences
   ```
   全仓 grep 确认 `PrivacyService`/`IPrivacyService` **无任何调用方**——是未接线的原型 stub。虽不构成运行时漏洞，但它与 `encrypt` 依赖一起留在仓里：(a) 误导后来者接上它；(b) 一旦接上就是"固定密钥+零 IV+明文 PIN"三连。**应整文件删除（顺带可移除 `encrypt` 依赖）。**
2. **〔已确认·诚实性〕"私密书架"不加密任何内容**：私密书的源文件仍以明文躺在设备原位置（外部路径！任何文件管理器可见），DB 行也明文。隐私保护 = UI 遮挡。AGENTS §2.4 声称 secure_storage 存"隐私书架密钥"——**该密钥不存在**。文档与实现的安全承诺不符。
3. **〔已确认·固有弱点〕4 位 PIN + 单轮 SHA-256**：离线暴力 10⁴ 次哈希瞬间完成；时间戳做盐熵极低。对"防家人翻看"够用，对"防取证"无意义——与 2 的结论一致：隐私层是礼貌性的。无 PIN 试错次数限制〔已确认，`pin_overlay_page.dart` 未见计数逻辑——标注：仅按 grep 与 M10 文件通读，未逐行读 overlay 页〕。
4. **〔已确认·DI 偏离〕`PinService` 是静态单例**（`static final PinService _instance`），绕过 get_it/构造注入——Phase 3 "删除静态单例"没删干净。
5. 〔已确认·加分项〕Pro 标志明文存 SharedPreferences（`is_pro_mode`）且 debug 构建强制 Pro（`kDebugMode ||`，有 `ponytail:` 注释）——离线免费 App 可接受，正式商业化前需换校验方案。

**健康度评级：`需关注`**（运行时链路本身尚可；扣分：死的高危 stub、文档承诺与实现不符）。

---

## M11 · 设置与全局偏好服务

`ReaderPreferencesService`：内存态同步更新 + 300ms Debouncer 合并落盘 + `flushPendingWrites()` 在退出/后台时冲刷——P0-8 设计完整落地〔已确认〕；enum 持久化用 index 且注释了"只许尾部追加"的契约。`BookshelfPreferencesService` / `LanguageManager` / `ReadingReminderService` / `MascotManager` 同型小服务。`FeatureManager` 见 M10-5。

1. **〔已确认〕`reading_stats` 断链确认**：设置页无统计 UI，配合 M2-6/M6-2——统计功能三处半成品（表、计数器、无 UI）。
2. **〔已确认·低〕`getPerceptualBrightness` 注释说 2.2 gamma、实现是平方**（代码内已自注 "Using 2.0 for performance/feel"）——文档级不一致，无害。
3. `settings_page.dart` 的导出/导入接 `BackupRecoveryService`（机制 D/E），书架顶栏的 Export 仍是 stub toast（`_showExportNotice`：注释 "Export flow is a stub"）——同功能两个入口一真一假〔已确认〕。

**健康度评级：`良好`**。

---

## M1 · 启动 / DI / 路由

〔已确认〕`main()`：全局错误钩子 → `setupServiceLocator().timeout(5s)`（失败进 `_BootstrapErrorApp`）→ `ProviderScope(runApp)`。`service_locator.dart` 统一 `registerSingletonAsync` + `allReady()`；清道夫延迟 5s、签名回填延迟 15s 错峰。go_router 4 路由 + 全局 navigatorKey。

1. **〔已确认·启动风险〕5s DI 超时把"慢"当"死"**：DI 里含 DB 打开 + **全量 integrity_check**（M2-2）+ 三个 prefs 初始化；低端机大库首启可能 >5s → 直接进"bootstrap failed"死屏（无重试按钮，仅文字）。超时兜底应给重试/跳过自检的降级路径。
2. **〔已确认·低〕`_BootstrapErrorApp` 把原始异常串直接显示给用户**——含路径等技术细节，与 §2.2.4 隐私日志精神相悖（错误屏也是"输出面"）。
3. 〔已确认〕生命周期钩子（3 分钟锁私密书架）逻辑正确，`_pausedAt` 清理无泄漏。

**健康度评级：`一般`**（结构好；5s 硬超时是唯一实质风险）。

---

## M12 · 主题与设计系统（core/theme + core/ui）

Token 五件套 + `NyanTheme` ThemeExtension 双预设 + 34 个组件。按指令稿"纯展示模块精简"处理：

1. **〔已确认〕纪律执行良好**：抽查的业务 Widget 均走 `context.nyanTheme` / `NyanTypography` / `NyanShadows.*`；`flutter analyze` 无相关告警；例外都有交付包出处注释（AGENTS 的例外清单与代码互相印证）。
2. **〔已确认·死代码〕`core/theme/app_radius.dart`（`AppRadius` 别名层）零调用方**——应删除。
3. **〔已确认·分层违规〕`core/ui/components/nyan_book_card.dart` import 书架模块的 `animated_book_card.dart`**（core→feature 反向依赖，草稿区 3）；`segmented_tab_control.dart` 躺在 bookshelf 却被 reader 复用（草稿区 4）——两者都该收编进 core/ui。

**健康度评级：`良好`**。

---

## M13 · 边缘小模块（admin / ads / tts / l10n）

- `admin_panel.dart`：feature flag 面板，路由 `/admin` **无任何门禁**——但 flags 本就是本地开关，风险≈0；debug 默认 Pro 才可达入口（M10-5）。〔已确认〕
- `ads/`：`NyanShelfDiscoverBlock` / `NyanShelfProNudge` 均为**本地静态假数据**的占位广告位（无 SDK、无网络）〔已确认，无第三方广告依赖于 pubspec〕。
- `tts/tts_ui.dart`：纯 stub（"Text To Speech (Stub)" 文案 + 空回调按钮）——Pro 特性列表若宣传 TTS 则是空头支票〔已确认〕。
- `l10n/`：en/zh 双语，`flutter gen-l10n`；reader 引擎内仍有少量硬编码英文（TXT 引擎 `'No content loaded'`、图片 fallback `'[... unavailable]'`、`book_source_access.dart` 的 `unavailableMessage` 整段英文）绕过 l10n〔已确认〕。

**健康度评级：`一般`**（皆为低风险外围）。

---

## 跨模块线索草稿区

1. `txt_reader.dart`（M5 引擎）import `widgets/highlightable_text.dart`（M7 UI）——分层矩阵违规；但 `ReaderEngine.buildReader(BuildContext)` 契约本身就要求引擎产出 Widget，"Engine 不得调用 UI 层"与契约自相矛盾，属架构张力而非孤立违规（阶段三展开）。
2. `core/models/chapter.dart` ⇄ `reader_engine.dart` 模块级双向依赖；且 `Chapter` 模型疑似与 `ReaderChapter` 重复（使用方待查）。
3. `core/ui/components/nyan_book_card.dart` → `modules/bookshelf/widgets/animated_book_card.dart`（core 反依赖 feature）。
4. reader 的 `chapter_list_widget.dart` / `reader_menu.dart` 复用书架 `segmented_tab_control.dart`（应上移 core/ui）。
5. `reader_page.dart` 直接 import 三个其它 feature 页面做命令式导航；go_router 仅 4 条路由。
6. `flutter analyze` 唯一 warning：`anchor_healer.dart:_runAnchorHealingInIsolate` 未被引用——死代码；实际修复走 `content_meta_manager.dart` 的 `Isolate.run`（M6 核对）。
7. **进度锚点判定：稳定锚点，设计正确**（M5 表格）；唯一漂移源是 TXT 编码嗅探不稳定（M5-1）会改变行切分。
8. `storage_type='app_private_copy'` 无生产者；`Book.filePath` 兼容 getter 显示模型迁移未完成。
9. 清道夫删 temp 24h+ 文件 vs file_picker/iOS 缓存副本 —— 组合数据丢失链（M3-1）。
10. `reading_stats` 表死 schema（M2-6）→ M11 核对设置页有无统计 UI。
11. ~~导入 format 大小写~~ 已排除：`ReaderEngineFactory` 有 `toLowerCase()`。
12. TXT-4 错误语义混淆 → M6/M7 核对 reader 打开前是否 `BookSourceAccess.isAvailable` 前置检查。
13. TXT `<img>` NetworkImage（M5-2）→ M13/阶段三"联网行为"汇总；epub_view 内部 img 行为〔需人工确认〕。
14. EPUB `nextPage` 段落步进（M5-9）→ M7 核对手势层是怎么用 nextPage 的（若 EPUB 主要靠滚动手势则影响小）。

---

# 阶段三 · 跨模块与全局分析

## 1. 整体架构评价

分层（Presentation → Controller → Engine → Service）在**主链路上是真实存在且被遵守的**：Widget 不直接摸 DB（抽查 reader/bookshelf 均经 Controller/VM）；引擎只依赖 `BookSourceAccess` 与模型；服务层无 UI 依赖。三处结构性张力：

- **`ReaderEngine.buildReader(BuildContext)` 让"引擎"天生是半个 View**。AGENTS §3.2 说 "Engine MUST NOT 调用 UI 层"，但契约本身要求引擎产出 Widget（TXT 引擎因此 import `HighlightableText`、内建底部 bar）。这不是谁违规，是矩阵与契约互相矛盾——要么把渲染拆成 `ReaderViewBuilder`（engine 提供数据/回调，UI 层建 Widget），要么修改文档承认引擎含渲染职责。
- **`get_it` + Riverpod + ChangeNotifier 三层桥接**：服务在 get_it，经 `riverpod_providers.dart` 包成 provider，Controller 又是 ChangeNotifier 由 `ListenableBuilder` 消费。能跑，但同一状态有三种订阅入口，新人极易选错粒度（M7-1 的回退就是这么发生的）。
- **书源生命周期模型**（外部路径 + 不拷贝）是全库最大的产品级架构决定，见 M3-1。

## 2. 循环依赖（脚本检测，import 图 540 边）

方法：解析全部 `import`（相对路径已 resolve）→ DFS 找环。**文件级共 4 个环**：

| 环 | 判定 |
|---|---|
| `core/services/service_locator.dart ⇄ core/services/backup_recovery_service.dart` | **真环**〔已确认〕：`BackupRecoveryService` 内部 `import 'service_locator.dart'` 并直接调 `getIt<DatabaseService>()`（`_performColdBackup` 等 4 处）——同时违反自家 §2.3 "MUST NOT 在 service_locator 以外调用 getIt"与 Phase 3 "全部构造器注入"的宣称。修法：构造注入 DatabaseService。 |
| `modules/reader/reader_page.dart ⇄ modules/reader/widgets/reader_menu.dart` | **真环**〔已确认〕：`reader_page.dart` 末尾 `export 'controllers/reader_controller.dart'`，`reader_menu.dart` 反过来 import reader_page 取 ReaderController——用 export 当转发枢纽造出的环。修法：reader_menu 直接 import controller 文件。 |
| `l10n/app_localizations.dart ⇄ app_localizations_en/zh.dart` | 生成代码固有模式，忽略。 |
| （模块级）`core/models/chapter.dart → reader_engine` | 环的一半是**死文件**：`chapter.dart` 全仓零 import。删除即消环。 |

## 3. 状态管理一致性

单一方案已基本达成（Riverpod 提供 + ChangeNotifier/ValueNotifier 承载；provider 包已移除）。真相源（§3.3 表）抽查一致：进度只在 engine、章节只在 ContentMetaManager、亮度只在 BrightnessController。两处偏离：

- `ReaderSettingsManager.handleLayoutChange` 绕过 `ReaderPreferencesService` 直改字号（M6-7）；
- `PinService` 静态单例残留（M10-4）；`BackupRecoveryService` 内部 getIt（上表）。

## 4. 贯穿链路（导入 → 解析 → 分页 → 渲染 → 进度持久化）终审

- **导入**：指纹去重与 SAF 授权健壮；**断点 = 书源不落沙盒**（M3-1），链路起点的资产就不受 App 控制。
- **解析**：三格式全部离 UI isolate〔已确认〕；**断点 = TXT 编码嗅探**（M5-1）——嗅探结果不稳定会向下游污染一切按"行号/偏移"锚定的数据（进度、高亮、书签），这正是 AnchorHealer 存在的原因；修嗅探是治本，healer 是治标。
- **分页**：TXT 页码是显示用估算（确定性满足 §3.6：同 key 同结果）；EPUB 无分页（滚动）；PDF 原生。**分页从不作为进度锚点**——设计正确，链路上没有"改字号丢进度"的断点。
- **渲染**：recognizer 池 + span 缓存无泄漏；断点 = reader_page 顶层全页订阅（M7-1，性能非正确性）。
- **进度持久化**：五重保险（M6），锚点稳定（M5 表）。**全链路结论：进度不会"漂"，但书本身可能"没"**（iOS/清道夫组合），这是本次审查对主链路的最重要判定。

## 5. 跨模块重复 / 该抽象未抽象

- `segmented_tab_control.dart` 在 bookshelf 被 reader 两处复用（应上移 core/ui）；`nyan_book_card.dart`（core/ui）反向 import bookshelf 的 `animated_book_card.dart`。
- 位置数据在三处以裸 `Map<String,dynamic>`（`position_type`/`position_payload`）传递（bookmark 列表→reader、notes→reader、DB→manager），外加 `reader_page.dart` 手拼 JSON（M7-4）——该抽一个 `PersistedPosition` 值对象。
- "错误→用户文案"映射逻辑在 `ReaderController._loadBook`（字符串 contains）与 `BookSourceAccess` 各写一份。

## 6. 测试情况（一句话）

`test/` 有 40+ 文件、覆盖数据层/进度/分页/亮度/组件，但**核心链路里 EPUB 引擎、PDF 引擎、导入指纹（BookImportFingerprint）、ContentMetaManager（高亮自愈）、BookshelfViewModel（删除/撤销）完全没有测试**——恰好是本报告问题最密集的区域。

## 7. 依赖健康度（静态读 pubspec.yaml；"最新性/CVE"标〔需执行 flutter pub outdated / 联网核实〕）

| 依赖 | 锁定 | 观察 |
|---|---|---|
| `epub_view: ^3.2.0` | EPUB 渲染核心 | 上游长期低维护（代码内已把私有 API 内联防漂移，作者知情）；〔需联网核实〕 |
| `epubx: ^4.0.0` / `archive: ^3.6.1` / `image: ^3.3.0` | 封面/zip | `image` 3.x 是旧大版本（4.x 已出多年）；`archive` 4.x 同理〔需联网核实〕 |
| `internet_file: ^1.2.0` | **零 import，死依赖**〔已确认〕 | 离线 App 挂着名为 internet_file 的直接依赖，删除 |
| `encrypt: ^5.0.1` | 仅被死代码 `privacy_service.dart` 使用〔已确认〕 | 随死代码一起删 |
| `fast_gbk: ^1.0.0` | TXT GBK 解码 | 小众包，编码专项（M5-1）重做时一并评估 GB18030 覆盖〔需人工确认〕 |
| `sqflite / shared_preferences / flutter_secure_storage / go_router / flutter_riverpod / get_it` | 主干 | 均为活跃主流包，版本无明显异常 |

## 8. 联网行为汇总（"完全离线"承诺盘点）

1. TXT 内嵌 `<img src="http(s)://...">` → `NetworkImage` **自动**加载（M5-2，被动、无提示——唯一实质破口）；
2. 划词 Search → 外部浏览器 Google（用户主动，可接受）；
3. `reader_error_view.dart` 的 url_launcher（报 bug 链接，用户主动）；
4. share_plus 导出（用户主动）。无遥测、无广告 SDK、无自动更新检查〔已确认〕。

## 9. 未完成的工作（git log + TODO + 死代码交叉）

- **阅读统计**：`reading_stats` 表 + `_readSeconds` 计数器 + 无落库无 UI（M2-6/M6-2/M11-1）——三处半成品。
- **封面系统**：`cover_path` 列死、书架无封面、详情页每次重抽（M4-3）。
- **TTS**：纯 stub（M13），但 FeatureManager 把它列为 Pro 特性。
- **书架顶栏 Export**：stub toast（M11-3）。
- **TODO 纪律良好**：仅 4 处，全部带 `#tag`（`#highlight-detail` / `#share` / `#pin-forgot` / `#package-info`）。
- **Phase 1 P0-2 的最小订阅优化在 P2-2 Riverpod 迁移中被实质回退**（M7-1）——AGENTS 路线图打了 ✅ 但现状不符，文档需要更正。
- 死代码清单（可整批删除）：`core/models/chapter.dart`、`core/theme/app_radius.dart`、`modules/bookmark/bookmark_service.dart` + `core/models/bookmark.dart`、`modules/privacy/privacy_service.dart`（连带 `encrypt` 依赖）、`anchor_healer.dart` 的 `_HealingRequest`/`_runAnchorHealingInIsolate`、`internet_file` 依赖、`books.cover_path` 列（保留列但注释现状）。

---

# 阶段五 · 优先级问题清单（严重程度 × 修复成本排序）

| # | 问题（模块 · 文件/符号） | 严重×成本 | 证据（含证据等级） | 修复范围 · effort（一句理由） |
|---|---|---|---|---|
| 1 | 书源生命周期：导入不拷贝进沙盒 + 清道夫删 temp 24h+ 文件，iOS/桌面导入的书可能次日失效（M3 · `home_screen.dart:_importBook` / `backup_recovery_service.dart:_heavyCacheCleanupTask`） | 数据丢失 × 高 | 疑似（代码链已确认，iOS file_picker 落盘位置需实机核实） | 跨模块 · **xhigh**——导入改为拷贝到应用文档目录（`appPrivateCopy` 字段已预留），清道夫加目录白名单；涉及导入/删除/回填三处 |
| 2 | TXT 编码嗅探缺 BOM/UTF-16/Big5，latin1 兜底必"成功"→整书乱码且污染行号锚点（M5 · `txt_reader.dart:_decodeBytesForParse`） | 功能错误(高频) × 中 | 已确认（代码引用见 M5-1） | 单模块 · **high**——补 BOM 检测 + UTF-16 解码 + 嗅探失败显式报错；属受保护面（分页/定位上游），需按 §3.5 走三段式 |
| 3 | TXT 内嵌 `<img>` 自动 NetworkImage，离线承诺被书内容击穿（追踪信标）（M5 · `txt_reader.dart:_buildImageByUri`) | 安全/隐私 × 低 | 已确认（M5-2） | 单文件 · **low–medium**——默认禁网络图（或加用户开关），仅保留 file/data |
| 4 | 删除后 Undo 只还原书行：书签/高亮已永久删除、文件可能已物理删除，撤销语义欺骗用户（M4 · `bookshelf_view_model.dart:undoLastDelete`） | 数据丢失(语义) × 中 | 已确认（M4-1，代码注释自认） | 单模块 · **medium–high**——要么删除延迟提交（软删除+过期清理），要么 Undo 一并缓存并回插关联数据 |
| 5 | 自愈失败兜底删主库且第三级不留 .bak（M2 · `database_service.dart:_archiveOrDelete`） | 数据丢失(边界) × 低 | 已确认（M2-1） | 单文件 · **low–medium**——bare-delete 分支改为重命名保尸体；恢复全败时保留损坏文件 |
| 6 | EPUB anchor 章节索引沿袭上游 bug，带 Anchor 的 EPUB TOC 跳转错位、违反 §3.6 一致性不变式（M5 · `epub_parse_helpers.dart:computeEpubParseResult`） | 功能错误 × 高 | 已确认（代码注释自认 "looks suspicious but we mirror it faithfully"） | 跨模块（涉及已持久化位置兼容） · **xhigh**——修正需同时做旧位置迁移，先加 golden test |
| 7 | 冷启动全量 `integrity_check` + DI 5s 硬超时 = 大库低端机可能直接 bootstrap 失败死屏（M2/M1 · `database_service.dart:_checkAndHealDatabase` / `main.dart`） | 崩溃(启动) × 低 | 已确认（M2-2/M1-1） | 双文件 · **medium**——quick_check/降频 + 超时后降级重试路径 |
| 8 | `reader_page.dart` 顶层 `ListenableBuilder(controller)` 全页重建，Phase 1 最小订阅优化被 Riverpod 迁移回退、注释失真（M7 · `reader_page.dart:build`） | 性能 × 中 | 已确认（M7-1） | 单文件 · **medium–high**——恢复 slice 订阅，删两处冗余内层订阅，更正注释与 AGENTS 路线图 |
| 9 | `privacy_service.dart` 硬编码 AES 密钥/零 IV/明文 PIN 的死 stub + `encrypt`、`internet_file` 死依赖 + 5 组死文件（M10/全局 · 见阶段三-9 清单） | 安全隐患(潜伏) × 低 | 已确认（零调用方 grep 证据） | 多文件删除 · **low**——纯删码；防后来者误接线 |
| 10 | `content_signature` 实为采样指纹而注释宣称全文件 SHA-256；同尺寸同头尾文件会互认（M3 · `book_import_fingerprint.dart:_buildSignature`） | 功能错误(低概率) × 低 | 已确认（M3-2） | 单模块 · **medium**——至少修文档；如改全量哈希需迁移已存签名 |
| 11 | 高亮自愈逐条 `Isolate.run` 串行 spawn；`_healHighlights` 大批修复时打开书卡顿（M6 · `content_meta_manager.dart:_healHighlights`） | 性能 × 低 | 已确认（M6-4） | 单文件 · **low–medium**——批量合并为单次 Isolate.run |
| 12 | `handleLayoutChange` 按视口宽度静默覆盖用户字号（M6 · `reader_settings_manager.dart`） | 功能错误(体验) × 低 | 已确认（M6-7） | 单文件 · **low**——删除或改为仅影响默认值 |
| 13 | 两个真实 import 环：`service_locator ⇄ backup_recovery_service`（附 getIt 越界）、`reader_page ⇄ reader_menu`（M2/M7 · 阶段三-2） | 代码质量 × 低 | 已确认（脚本检测 + import 语句） | 双文件 · **low–medium**——构造注入 + 取消 export 转发 |
| 14 | 阅读统计三处半成品（表/计数器/无 UI）与封面系统半残（`cover_path` 死列、详情页每次全书重读抽封面）（M2/M4/M6） | 代码质量/性能 × 中 | 已确认（M2-6/M4-3/M6-2） | 产品决策 · **medium**——要么接完管线（封面落盘缓存 + 统计落库），要么删干净 |
| 15 | `content_meta_manager.dart` 注释全量 Mojibake，关键算法意图不可读（M6 · 全文件） | 代码质量 × 低 | 已确认（M6-3） | 单文件 · **low**——按代码行为重写英文注释 |

---

## 终检说明（定稿自查）

- 全部标注 `已确认` 的条目均附有本会话实际打开文件中的符号名/代码片段；未打开文件（如 epub_view 包内部、Android 原生 `MainActivity.kt`）一律未标行号、结论标〔需人工确认〕。
- 降级处理：M3-1（iOS file_picker 落盘位置）定级"疑似"——代码链完整但平台行为需实机验证；M8-1（dispose 竞态）定级"疑似"——窗口极窄未观测到实锤路径；M2-7（备份并发）明示"不算实锤"。
- 已修正的初判：M3-5"format 大小写"被 `ReaderFactory.toLowerCase()` 化解（草稿区 11 已划销）；M5"Engine import UI 违规"重定性为契约级架构张力而非孤立违规；`PrivacyService` 硬编码密钥从"高危漏洞"降级为"死代码中的高危写法"。
- 模块间无互相矛盾结论；进度锚点判定（M5 表 ↔ 阶段三-4）两处一致。
