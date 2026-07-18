# 喵阅 Nyan Read · 全库架构与漏洞审查报告

> 分析锚点：commit `22073d817733b010aafdfabcf62e1246636d72a9` · branch `main` · 审查日期 2026-07-15
> 方法：静态审查（只读），主会话亲自读码确认；证据等级标注见各条（已确认 / 疑似 / 需人工确认）。
> 规模：`lib/` 143 个 Dart 文件、37,110 行；零生成代码；平台层自定义原生代码仅 `MainActivity.kt`（161 行 SAF 通道）。

---

## 1. 执行摘要

整体健康度：**良好偏优**。这是一个工程纪律罕见地严格的代码库——隔离（Isolate）纪律、订阅粒度、dispose 完整性、数据迁移与防级联删除等在代码与注释中均有系统性落实；2026-07-07 的前次全库审查问题已修复（见 `docs/BACKLOG.md`）。本次审查在核心链路上未发现"进度丢失/漂移"级缺陷，但发现以下最值得优先处理的问题：

1. **EPUB 解压无条目大小上限**——恶意/畸形 EPUB 可造成打开即 OOM 崩溃（M7）。
2. **冷备份恢复候选只校验非零字节**——备份中途被杀留下的截断快照会被反复优先恢复，最坏形成启动失败循环（M2）。
3. **"导出数据"无 PIN 门禁**——私密书架的书名、笔记、高亮可经 设置→导出 三步绕过可见性门禁（跨模块）。
4. **EPUB 内容枚举由 TOC 驱动而非 spine**——TOC 稀疏的书会静默丢正文（M7）。
5. **Android persistable URI 授权上限**——数百本 SAF 导入的大书库可能静默失去旧书访问权（M3，需人工确认）。

---

## 2. 新维护者导航

**先读这三处（按顺序）：**

1. `lib/modules/reader/reader_engine/reader_engine.dart` —— 全部引擎契约（`ReaderEngine` / `ReadingPosition` / `ChapterLocator` / Capability 体系）。读懂它就读懂了阅读器一半。
2. `lib/modules/reader/controllers/reader_controller.dart` + `reading_progress_manager.dart` —— 打开一本书的完整生命周期：加载→恢复位置→心跳→落盘→退出兜底。
3. `lib/core/services/database_service.dart` —— schema（v9）、迁移、自愈、以及注释里记录的历史痛点（`ConflictAlgorithm.replace` 级联删除事故）。

**改动最危险的区域（碰了容易连锁出错或丢数据）：**

- `epub_parse_helpers.dart` 的 `_linearizeChapterDocument` —— **任何**改动都会平移全书 EPUB 段落索引，导致所有已存进度/高亮/书签锚点失效（文件头注释明确警告，golden test 锁行为）。
- `txt_reader.dart` 的 `decodeTxtBytesForParse` —— 解码链顺序决定行索引，行索引是 TXT 锚点。注释明言"existing anchors must not move"。
- `database_service.dart` 的 `insertBook` / `restoreDeletedBooksBatch` —— 必须保持 `ConflictAlgorithm.abort`；改成 replace 会经 FK CASCADE 静默删光该书全部高亮书签。
- `_onUpgrade` 迁移脚本 —— 只准增量 ALTER，schema version 现为 9。

---

## 3. 模块清单总览表

| # | 模块 | 路径 | 一句话职责 | 健康度 |
|---|---|---|---|---|
| M1 | 应用装配与 DI | `main.dart`, `core/services/service_locator.dart`, `core/router/` | get_it 异步注册 + Riverpod 装配 + 生命周期钩子 | 良好 |
| M2 | 数据层 | `core/services/database_service.dart`, `backup_recovery_service.dart`, `signature_backfill_service.dart` | SQLite v9 + VACUUM INTO 冷备份 + 自愈 | 需关注 |
| M3 | 书籍导入与文件访问 | `core/utils/book_*.dart`, `bookshelf/widgets/import_book_sheet.dart` | SAF/沙盒双策略导入、指纹去重、源可用性 | 需关注 |
| M4 | 书架 | `modules/bookshelf/` | 双书架（公开/私密）、选择模式、延迟删除+undo | 良好 |
| M5 | 阅读器核心 | `reader_page.dart`, `controllers/` | 控制器编排、进度心跳与落盘、One Paper UI | 良好 |
| M6 | TXT 引擎 | `reader_engine/txt/` | 编码嗅探、isolate 解析、章节识别、估算分页 | 良好 |
| M7 | EPUB 引擎 | `reader_engine/epub/` | 自研 zip/OPF/TOC 解析 + 纯 Flutter 渲染 | 需关注 |
| M8 | PDF 引擎 + 契约 | `reader_engine/pdf/`, `reader_engine.dart`, `reader_factory.dart` | pdfx 封装、页码锚点、合成目录 | 良好 |
| M9 | 进度/书签/高亮持久化 | `reading_progress_manager.dart`, `content_meta_manager.dart`, `anchor_healer.dart`, `modules/bookmark/`, `modules/notes/` | 稳定锚点存取 + 三段式高亮自愈 | 良好 |
| M10 | 亮度子系统 | `reader/brightness/` | 手动/跟随系统双模状态机 + 硬件亮度编排 | 良好 |
| M11 | 隐私 | `modules/privacy/`, `pin_service.dart`, `biometric_service.dart` | PIN(盐+哈希)+生物识别+试错锁定+自动锁 | 一般 |
| M12 | 设置与偏好服务群 | `modules/settings/`, `reader_preferences_service.dart` 等 | 300ms 去抖落盘偏好 + 设置页 | 一般 |
| M13 | 广告与推荐 | `modules/ads/` | 纯静态占位"赞助"卡 + Pro nudge（总闸关闭） | 良好 |
| M14 | 主题与 UI 组件库 | `core/theme/`, `core/ui/` | 设计 token 体系 + 组件库（精简审查） | 良好 |
| — | l10n / 平台层 | `lib/l10n/`, `android/` 等 | gen-l10n 风格本地化实现（4.4k 行）；原生仅 MainActivity.kt 的 SAF MethodChannel | 一句话带过 |

---

## 4. 逐模块详细分析

### M1 · 应用装配与 DI（良好）

**职责与位置**：`main.dart` 负责全局错误钩子、两段式超时 bootstrap（5s 快路径 + 25s 宽限，同一 future，注释解释了为何不能重启 setup）、私密书架后台 3 分钟自动锁。`service_locator.dart` 用 `registerSingletonAsync` + `allReady`，服务经构造器注入（如 `BackupRecoveryService(await getIt.getAsync<DatabaseService>())`，`dependsOn: [DatabaseService]`）。

**逻辑与隐患**：
- 【疑似】bootstrap 25s 二次超时后进入 `_BootstrapErrorApp`，此时原 `setupServiceLocator()` future 仍可能在跑；用户点 Retry 执行 `await getIt.reset()` 再重跑 setup（`main.dart` `_retry`），与仍在执行的旧注册存在竞态窗口。触发条件苛刻（DI 卡死 30s+ 且用户手动重试），影响低。
- 启动后延时任务错峰合理：5s 后缓存清道夫、15s 后签名回填，注释说明避开冷启动 I/O。

**优化方向**：无紧要项。

### M2 · 数据层（需关注）

**职责与位置**：`DatabaseService`（1087 行）拥有 schema v9、迁移、自愈、全部 CRUD；`BackupRecoveryService` 负责 pause 时 `VACUUM INTO` 冷备份（保留 3 份）、缓存清道夫（temp 目录 >24h 文件，isolate 内删除）、JSON 导出/导入；`SignatureBackfillService` 后台补算旧书签名。

**做对了的（值得后来者维持）**：
- 迁移全部增量 `ALTER TABLE`，`_ensureHighlightColumns`/`_ensureBookColumns` 在版本迁移之外再防御性补列。
- `insertBook` 显式 `ConflictAlgorithm.abort` 并注释记录历史事故："REPLACE on a books row fires the FK ON DELETE CASCADE path and silently deletes every highlight and bookmark"。
- 备份用 `VACUUM INTO`（单文件全检查点，无 WAL 边车依赖）；启动 `PRAGMA quick_check`（非 integrity_check，注释解释了 O(db size) 与 DI 超时的权衡）；恢复的纯文件操作走 `Isolate.run`。
- 逻辑恢复 `restoreDataBatch` 以 `content_signature` 为主键、title 为 legacy 回退，只 UPDATE 不 INSERT，重绑 book_id 后 upsert 子表——契约注释完整。

**漏洞与隐患**：
- 【已确认·本模块最重要发现】**备份恢复候选只校验非零字节**。`_runRestoreFromBackupInIsolate` 中唯一的有效性检查是 `if (restoredSize == 0) { throw Exception('Restored file is empty ...') }`。`VACUUM INTO` 在 `AppLifecycleState.paused` 窗口执行（`unawaited(_performColdBackup())`），Android 后台杀进程是常态——中途被杀会留下**尺寸>0 但截断**的 `.db` 快照。该快照按 mtime 是最新候选，恢复时被首选；恢复出的损坏文件让 `openDatabase` 再次失败，而坏候选**从不被隔离或删除**，下次启动仍然首选它。最坏路径：备份中被杀 → 主库恰又损坏 → 自愈反复恢复同一个坏快照 → 启动失败循环。触发概率低但两个前置条件都真实存在。修复：候选恢复后跑一次 `PRAGMA quick_check`，失败则将该候选改名隔离再试下一个。
- 【已确认·轻微】`bookmarks`/`highlights` 的 `insertBookmark`/`insertHighlight` 用 `ConflictAlgorithm.replace`——主键是 UUID，冲突仅发生在恢复/undo 场景，行为正确。

**优化方向**：`getBooks` 书架查询可收窄列（BACKLOG 已记）；无其它热点。

### M3 · 书籍导入与文件访问（需关注）

**职责与位置**：导入入口在 `home_screen.dart` `_importBook`；平台策略在 `_resolveImportedSource`：Android → `content://` URI + `persistReadPermission`（原生 `takePersistableUriPermission`，读写降级读，`MainActivity.kt` `persistReadPermission`）；iOS/macOS → `BookSandboxCopier.copyIntoLibrary` 复制进 `<documents>/books/`（picker 返回临时目录路径，注释明言"the book would silently die after import"）；Windows/Linux → 原路径引用。去重 = 归一化 locator + 采样指纹（SHA-256 over `ext|size|首尾 64KB`，`book_import_fingerprint.dart` `_buildSignature`，注释自认同尺寸中段差异的碰撞窗口）双索引。

**`content://` URI 持久化判定（指令稿必答）**：Android 采用**持有 URI**而非复制；`takePersistableUriPermission` 有真实调用（`_resolveImportedSource` → `BookSourcePlatform.persistReadPermission`，失败则放弃该文件导入并打日志）。URI 失效后的表现：打开书时 `ReaderController._loadBook` 先查 `BookSourceAccess.isAvailable`（原生 `openInputStream` 试探），不可用则显示 `ReaderErrorView`（fileNotFound 文案引导重新导入）——**优雅降级，不崩溃**。书架列表不做源文件同步探测（封面仅详情页提取），列表渲染不会因悬挂引用卡死。【已确认】

**漏洞与隐患**：
- 【需人工确认】**persistable URI 授权系统上限**：Android 对每 app 的持久化 URI 授权有配额（API 30 前 128 个、30+ 为 512 个，此为平台行为，未在本仓验证）。数百本 SAF 导入后，最旧授权被系统静默回收 → 老书变"源不可用"。代码无任何计数、提示或"复制进沙盒"降级路径。大书库用户是本品类常态，建议：接近阈值时改走复制导入，或在导入 UI 提示。
- 【已确认】`MainActivity.kt` 的 MethodChannel handler 在**平台主线程**执行 `copyUriToTempFile`（`input.copyTo(output)` 全量流拷贝）与 `readUriBytes`。打开一本 SAF 来源的大书（EPUB/PDF 上百 MB）时整个拷贝阻塞 Android 主线程——掉帧乃至 ANR 风险（`readUriBytes` 有 100MB 上限护栏，`copyUriToTempFile` 无）。修复：handler 内派发到后台线程（或 `TaskQueue`），完成后 `result.success`。
- 【已确认·设计周到，非问题】删除带文件：物理删除延迟 8s（undo 窗口 4s + 余量），`BookshelfViewModel._commitPendingFileDeletions` 在计时器/新批次/dispose 三处收口；undo 恢复书行+书签+高亮单事务。

**优化方向**：无紧要项。导入不解析书体（书名=文件名），首开时才解析——正确的懒策略。

### M4 · 书架（良好）

**职责**：`BookshelfViewModel`（ChangeNotifier）持有公开/私密两列表、选择模式、undo 快照；`home_screen.dart`（1839 行）承载网格/列表双视图、导入、排序、删除确认。

**逻辑与渲染**：网格 `SliverGrid` + 列表 `DecoratedSliver(SliverList.builder)`（注释明确"so the inner SliverList stays lazy"）均懒加载；书架卡不做 EPUB 封面提取（grep 全仓 `extractEpubCoverAsJpeg` 仅详情页一处调用），滚动路径无同步 I/O。【已确认】

**隐患与优化**：
- 【已确认·内存尖峰】详情页封面提取 `_loadCoverBytes`（`book_details_page.dart`）经 `BookSourceAccess.readBytes(book)` 把**整本 EPUB 读进内存**再交 isolate 提取封面。100MB+ 插图本首次进详情页即全书级内存尖峰（此后走 `BookCoverCache` 100MB LRU 磁盘缓存）。优化：改用 reader 同款流式路径（`prepareReadableFile` + `InputFileStream` 按条目抽取，见 `extractEpubImageBytesFromFile`）。
- 【已确认·订阅粒度】`_buildGridBookTile` 每格包 `ListenableBuilder(listenable: _vm)`——任意 VM notify 重建所有可见格，违背自家最小订阅 SHOULD（§2.3）。可见格数量有限，实际影响小。
- `flutter analyze` 全仓仅 2 个 info（`home_screen.dart:155/163` use_build_context_synchronously），且该处有注释解释是为避免 loading toast 搁浅的有意行为（154 行上方 `ponytail:` 注释）——非 bug。

### M5 · 阅读器核心（良好）

**职责与位置**：`ReaderController` 是编排根（构造引擎、三个 Manager、生命周期）；`ReaderPage`（1115 行）承载 One Paper UI 与手势；生命周期资源统一进 `LifecycleRegistry`。Riverpod 侧 `readerControllerRpProvider`（autoDispose.family）负责创建/销毁，`ref.onDispose(controller.dispose)` 收口。

**进度锚点判定（指令稿必答·已确认）**：
- TXT/EPUB：**段落索引 + 段落内视口 leading/trailing edge 比例**（`ReadingPosition.paragraphIndex/paragraphLeadingEdge/paragraphTrailingEdge`）。段落索引由确定性解析（TXT `split('\n')`；EPUB 固定线性化规则+golden test）产生，**不随字号/字体/主题/重新分页漂移**。页码只是采样估算的展示值，从不做锚点。
- PDF：页码（固定版式，天然稳定）。
- 结论：锚点设计正确，无"改字号丢进度"类缺陷。

**进度落盘时机判定（指令稿必答·已确认）**：四重保障——
1. 30s 周期自动保存（`ReadingProgressManager.startTracking` 的 `Timer.periodic`）；
2. `AppLifecycleState.paused/detached` → `saveForLifecyclePause()` + prefs flush（`ReaderController.didChangeAppLifecycleState`）；
3. 正常退出（PopScope / 顶栏返回 → `saveBeforeExit`）；
4. dispose 兜底：`scheduleDisposeFallbackSave` **同步**快照引擎状态后 fire-and-forget 写库，注释明确解释为何不能复用带去抖的 `saveCurrentPosition`（"the in-flight dedup there could hand back a pre-existing save that is still trying to talk to the engine"）。
丢失窗口仅剩"进程被杀且无 pause 回调"时的最近 ≤30s。设计完善。

**其它**：
- 悬挂引用：`_loadBook` 先 `BookSourceAccess.isAvailable` → `ReaderErrorState(fileNotFound)` → 全屏 `ReaderErrorView`，可重试可返回。【已确认】
- 翻页经 `_enqueuePageTurn` future 链串行化，防重入。
- 渲染订阅用自研 `_ControllerSelect`（record `==` 切片），progress 走独立 `ValueNotifier`——心跳不惊动整树。
- 【轻微】`build()` 中每次 rebuild 调 `configureInteractions` 重挂三个回调（纯赋值，开销可忽略，build 纯度瑕疵）；`"Book not found."` 硬编码英文未走 l10n。
- 【坏味道】PDF 打开失败不进 `ReaderErrorState` 统一错误页（pdfx 的 future 交给 controller 内部消化，errorBuilder 内联展示）——错误路径分叉于 TXT/EPUB。

### M6 · TXT 引擎（良好）

**编码嗅探判定（指令稿必答·已确认）**：`decodeTxtBytesForParse`（`txt_reader.dart`）：BOM UTF-8/UTF-16 LE/BE → BOM-less UTF-16 嗅探（NUL 字节分布 40%/5% 阈值，注释解释为何必须先于 utf8 跑）→ utf8 → GBK → latin1（高字节占比 >30% 时抛 `FormatException` 拒绝渲染乱码，理由：乱码会污染锚点）。兜底行为：解码失败 → `initialize` 抛 `FormatException` → `ReaderErrorType.parseFailed` 错误页。
- 【已确认·自我记录的缺口】**Big5 会被 `gbk.decode` 伪成功**渲染乱码（代码内 `ponytail:` 注释自认，BACKLOG 列为"等真实报告再动"）。GB18030 未显式支持（fast_gbk 覆盖度未验证，【需人工确认】）。

**解析与内存**：单次 `compute` 完成解码+分行+段偏移+章节识别（注释：曾经只有解码离线，其余在 UI isolate 上"lock the main thread for seconds on 20MB+ novels"）。全书以 UTF-8 单份 + 行 range 表驻留，行文本按需解码——内存自觉性高。

**分页**：`_recalculatePagination` 完全符合 §3.4——LayoutBuilder 中 `unawaited` + 布局键（viewport+fontSize+lineHeight+padding+orientation+textScale+段间距）去重 + in-flight 去重 + 完成后校验键未失效 + `TextPainter.dispose()`。页数是"采样 3000 字符 TextPainter 外推"的估算，仅展示。

**边界**：空文件 → `_lineCount == 0` → "no content" 提示；超长行（>500 字符）跳过章节正则防回溯；巨段落翻页有 `_tryTurnInsideOversizedParagraph` 视口内步进。
- 【疑似·低危】内嵌 `<img>` 支持 `file://`/相对路径 `FileImage`——恶意 TXT 可引用设备任意可读图片路径显示（仅显示给本机用户，无外传）；http/https 已显式阻断且注释点名"tracking beacon"。
- 【优化·微】`_getLine` 用 `_rawUtf8.sublist(start,end)`（拷贝）；`Uint8List.sublistView` 可零拷贝。每可见行每次 build 一次小分配，量级小。

### M7 · EPUB 引擎（需关注）

自研栈（2026-07 P3c，epubx/epub_view 已删）：`epub_package_parser.dart`（container/OPF/TOC）→ `epub_parse_helpers.dart`（HTML 线性化为段落）→ `epub_reader.dart`（ScrollablePositionedList 纯文本渲染）。

**安全专项（指令稿重点·逐项）**：
- **Zip Slip / 路径穿越：不存在**。全程内存解析（`ZipDecoder().decodeBytes/decodeStream`），从不解压到文件系统；`resolveHref` 的 `..` 只用于 zip 条目名解析且 segments 下限为空（无法越出 zip 根），条目名仅做 `findZipEntry` 查找键。【已确认】
- **HTML/CSS/JS 渲染注入：不存在**。无 WebView；自研线性化中 `if (tag == 'script' || tag == 'style') return;` 直接丢弃；出版商 CSS 全部丢弃（设计使然）；渲染为纯 `TextSpan`。【已确认】
- **XXE**：`package:xml` 默认不解析外部实体，不成立（一句话结论）。
- **解压炸弹 / 超大条目：存在缺口**。`readZipBytes` 直接 `entry.content` 全量解胀，**无任何条目大小上限**；`parseEpubFileInIsolate` 也 `File(path).readAsBytes()` 整包进内存。构造 EPUB（如 1MB 压缩 → 数 GB xhtml 条目）在解析 isolate 内解胀——Dart 堆是进程级的，OOM 即整进程崩溃。【代码事实已确认；崩溃后果为疑似（未运行验证）】修复成本低：解压前查 `ArchiveFile.size`（解压后尺寸）设上限（如 64MB/条目），超限按 parseFailed 处理。`MainActivity.readUriBytes` 的 100MB 护栏只保护 content:// 直读路径，管不到这里。

**正确性**：
- 【已确认·内容丢失风险】**内容枚举由 TOC（nav/NCX）驱动而非 spine**：`computeEpubParseResultForPackage` 只遍历 TOC 条目读取章节文件；仅当 TOC 完全为空才回退 spine 顺序（`parseEpubPackageFromArchive` `if (toc.isEmpty)` 分支）。TOC 稀疏的书（spine 有文件未列入 TOC——前言、插页、或按"部"列 TOC 而按"章"分文件的书）→ 未列出的 spine 文件**完全不渲染，无任何提示**。修复方向：以 spine 为枚举主序，TOC 只做标题/锚点映射（这是标准 EPUB 阅读器语义），但属受保护面（§3.5），会平移现有锚点，需迁移策略。
- 【已确认·边缘】文件级去重只比较相邻 TOC 条目（`if (filename != chapter.contentFileName)`，`computeEpubParseResultFromSources`）：TOC 交错引用同一文件（A→B→A）会把 A 重新线性化、段落重复入列并使后续锚点整体偏移。真实书籍罕见此结构。
- 位置模型与 TXT 同构（绝对段落索引+视口边缘），legacy CFI 行恒有 paragraphIndex 双写，恢复路径覆盖完整。【已确认】
- SAF 源会话级临时副本 + dispose 删除 + 24h 清道夫兜底；图片按条目 `InputFileStream` 流式抽取（注释记录了 184MB 插图本的 OOM 教训）。

**坏味道**：`_jumpToIndex` 固定 60ms delay 等 positions listener、`_waitForViewAttached` 50ms×100 轮询——有界但属时序猜测。

### M8 · PDF 引擎 + 引擎契约（良好）

pdfx `PdfController(document: future)` 组合式打开（initialize 不阻塞）；`_isDocumentReady` 门控全部读取；dispose 有临时文件竞态守卫（`_pendingDocumentFuture.then` 链，注释解释场景）。锚点=页码。目录为合成伪章节（每 10 页，`isSynthetic: true`，pdfx 无 outline API 所限，BACKLOG 已记）。`ReaderEngineFactory` 对未知格式返回抛错 stub 而非误用 TXT 引擎渲染乱码（注释解释）。无发现级问题。

### M9 · 进度/书签/高亮持久化（良好）

- 落盘/锚点判定见 M5。存储：`books.last_position_type/payload`（JSON）+ `current_progress`；书签/高亮独立表带 FK CASCADE。
- **高亮自愈**（`ContentMetaManager._healHighlights` + `AnchorHealer`）：写入时捕获前后各 15 字符上下文；打开时 fast-path 校验偏移仍选中原文（零 I/O），失效者**批量单 isolate** 三段式重定位（完整签名→exact 唯一→多候选权重仲裁，阈值 0.3），治愈回写 fire-and-forget，治不好则不渲染但保留 DB 行等下次重试。设计与实现俱佳。【已确认】
- 【疑似·低危边缘】`position_type` 存的是 `book.format` 原始字符串（导入时 `path.extension(fileName).replaceAll('.', '')` 保留大小写）。`EpubReaderEngine._readInitialParagraphIndexFromBook` 判断 `book.lastPositionType != 'epub'`——若用户导入 `.EPUB` 大写扩展名文件，初始索引恢复静默失败回 0；但 `restoreLastPosition` 的 `goToPosition` 主路径仍生效（`ReadingPosition.fromJson` 对 epub type 无特判），实际影响仅"首帧从头开始随后跳回"。建议 format 入库前统一 lowercase。
- 书签快照回填 `backfillBookmarkSnippets` 逐条 await 循环——书签量大时慢，但 fire-and-forget 不挡加载。

### M10 · 亮度子系统（良好）

`BrightnessOrchestrator` 状态机严密：manual/followSystem 双模、系统亮度回声抑制（`_ignoredSystemBrightness`）、后台恢复原始系统亮度并暂存手动目标（`_pausedManualBrightnessTarget`）、resume 渐变 ramp、apply 队列防重入（`_drainManualApplyQueue`）、系统亮度流订阅取消完整。shutdown 与 dispose 的竞态由 `_notifierDisposed` 门控（注释精确描述了 debug assert 崩溃场景）。高频值全部走 `ValueNotifier`。无发现级问题。

### M11 · 隐私（一般）

- PIN：盐+SHA-256 存 `flutter_secure_storage`；**5 次错→30s 锁定且持久化**（重启不清零）；生物识别 `biometricOnly+stickyAuth`、异常 fail-closed；后台 ≥3 分钟自动锁私密书架（`main.dart`）。产品定位（AGENTS §2.4）明示"可见性门禁，不承诺防取证"。
- 【已确认·低危改进项】盐是 `DateTime.now().millisecondsSinceEpoch.toString()`（`pin_service.dart` `setPin`）——低熵可预测；且单轮 SHA-256 无 KDF，4 位 PIN 离线爆破仅 10^4 次哈希。虽在声明的威胁模型外，换 `Random.secure()` 盐 + 迭代哈希的成本几乎为零，建议顺手补。
- 跨模块相关的**导出绕过 PIN** 问题见 §5（本次审查最重要的隐私发现）。

### M12 · 设置与偏好服务群（一般，精简）

`ReaderPreferencesService` 是 §2.4 去抖规则的教科书实现：300ms `Debouncer` 键级合并、类型保留的 `_PendingPrefWrite`、pause/退出 `flushPendingWrites`、dispose 兜底、reset 时先取消 in-flight 写防"半秒后复活"。`FeatureManager`：`kDebugMode` 强制 Pro（自注释，上架前须移除，BACKLOG 已记）；`is_pro_mode` 明文 SharedPreferences（商业化前置，BACKLOG 已记）。设置页的分层违规见 §5。其余琐碎服务未逐行（预算内精简）。

### M13 · 广告与推荐（良好）

**离线承诺专项结论（已确认）**：`AdsUI` 全部内容为硬编码占位（"BookBuzz" 假书目三条，`ads_ui.dart` `_suggestionsZh/En`），**零联网、零 SDK、零遥测**。全仓网络出口仅两处且均为用户主动动作跳外部应用：划词菜单"搜索"开外部浏览器 Google 搜索（选中文本进 URL——用户主动触发，可接受）；错误页 mailto 反馈。Pro nudge 有 `FeatureManager.proSurfacesEnabled = false` 总闸（注释："an upgrade pitch would sell an empty box"）。

### M14 · 主题与 UI 组件库（良好，精简）

五 token 文件 + `NyanTheme` 扩展体系完整；抽查的 `highlightable_text.dart`（recognizer 池化 + TextSpan 缓存 + XOR 指纹免 build 期排序，注释详尽）、`nyan_response` 质量高。不逐行审。

### l10n / 平台层（一句话）

l10n 为手写的 gen-l10n 风格三文件（4.4k 行，含良性互引环）；平台自定义原生代码仅 `MainActivity.kt`（SAF 通道，问题见 M3）；`android/` 曾修复过系统自动备份问题（commit `46b111b` 禁用 auto backup，方向正确——避免 SAF URI 与 DB 跨设备恢复后不一致）。

---

## 5. 全局与跨模块分析

### 5.1 整体架构评价

分层清晰且**自我执行**：Presentation → Controller/Manager → Engine → Service 的调用矩阵在抽查中基本成立；单一真相源表（§3.3）与代码一致（progress 在 ProgressManager 的 ValueNotifier、章节在 ContentMetaManager、亮度在 BrightnessController）。突出优点是**注释文化**：几乎每个反直觉决策都有"为什么"注释，多处直接引用历史事故。这是可以放心接手的代码库。

### 5.2 循环依赖（脚本建图结论）

文件级环：**仅 2 个**，均为 `l10n/app_localizations.dart ↔ app_localizations_{en,zh}.dart`（gen-l10n 标准结构，良性）。**业务代码零文件级环**。【已确认，基于全量 import 解析 DFS】

模块级双向边（无环但分层软违规）：
- `core/services → modules/privacy`（`service_locator.dart` import `PrivacyLockService`）——core 反向依赖 modules，建议把 `privacy_lock_service.dart` 移入 core 或注册点下沉；
- `modules/reader ↔ modules/settings`（reader_page push SettingsPage；settings 引 reader 服务）；
- `core/services ↔ core/utils`（fingerprint→DatabaseService）。

### 5.3 分层违规（已确认）

`settings_page.dart:67/142` 直接调用 `getIt<BackupRecoveryService>()`——同时违反自家 §2.3（get_it 只准在 service_locator 内直取）与 §3.2 跨层矩阵（Presentation→Service ❌）。其它服务在 `riverpod_providers.dart` 均有 provider，这是漏网点，修复即加一个 provider。

### 5.4 隐私发现：导出绕过私密书架门禁（已确认，本次最重要隐私问题）

`SettingsPage → 导出数据` 无任何 PIN 校验（`_handleExportData` 直接调 `exportGlobalUserData`），而 `exportGlobalUserData → dbService.getAllBooks()` **不过滤 `is_private`**——导出 JSON 含私密书架全部书名、作者、`file_path`、阅读进度、全部高亮与书签正文，且下一步就是 `share_plus` 分享。私密书架的产品承诺是"防随手翻看"（AGENTS §2.4），而拿到解锁手机的人经 设置→导出→分享 三步即可带走私密书目与笔记——**恰好在声明的威胁模型内**。修复成本低：导出前若存在私密书且未解锁则要求 PIN；或默认排除私密书 + 显式开关。（附带发现：`exportBookNotesToMarkdown` 全仓零调用点，是死代码——grep 已确认，对应详情页的 `TODO(#share)` 尚未接线。）

### 5.5 贯穿主链路走查（导入→解析→分页→渲染→进度）

链路无断点、无重复转换：导入只记元数据（不解析书体）→ 首开时引擎在 isolate 解析 → 分页为展示级估算（不做锚点）→ 渲染与解析共享同一段落枚举（EPUB 注释："index alignment between count and content is structural"）→ 进度以段落锚点四重时机落盘。进度漂移的唯一已知窗口是**改动 EPUB 线性化规则**（会平移全书索引），已被 golden test 与受保护面制度覆盖。系统性缺口只有 M7 的 TOC 驱动枚举（解析环节可能静默丢内容）。

### 5.6 跨模块重复逻辑

TXT 与 EPUB 引擎存在成对的近似实现：`_currentViewportAnchor` / `_alignmentFromEdges` / UTF-8 bytes+ranges 存储 / ScrollablePositionedList 装配。当前各自 ~50-100 行、已刻意同构（注释互相引用），可容忍；若出现第三个文本引擎（Phase 5 TTS/注释系统前置）应抽 `ParagraphListEngineBase`。

### 5.7 测试情况（一句话）

`test/` 47 个文件覆盖 DB/备份/undo/亮度/EPUB 解析 golden/TXT 编码与分页确定性等核心；**PDF 引擎、BookImportFingerprint、ContentMetaManager 高亮自愈无测试**，另有 ~36 条已知失败测试债（均为 `docs/BACKLOG.md` 自认，维护者主动搁置）。

### 5.8 依赖健康度（`flutter pub outdated` 实测 2026-07-15）

全部 null-safety；直接依赖无 discontinued（transitive `js 0.6.7` discontinued，无碍）。滞后主版本：`go_router` 13.2.5（最新 17.3.0）、`local_auth` 2.3.0（3.0.2）、`flutter_secure_storage` 9.2.4（10.3.1）、`share_plus` 12.0.1（13.2.1）、`file_picker` 10.3.10（11.0.2）、`xml` 6.6.1（7.0.1）。均为兼容性锁定而非风险信号；是否有安全公告【需联网核实】。`fast_gbk 1.0.0` 为小众包，维护活跃度【需联网核实】。

### 5.9 未完成的工作

git 历史 2026-01-25 ~ 2026-07-15。前次全库审查（2026-07-07）的问题级条目已修复、报告删除（`docs/BACKLOG.md` 记载，锚点 `05fdd8b`）。遗留：测试债与测试盲区（见 5.7）；**iOS 从未真机验证**（README/BACKLOG 双记载，`BookSandboxCopier` 行为待实机确认）；商业化前置（`is_pro_mode` 明文 + `kDebugMode` 强制 Pro + Pro 文案过期）；4 处 TODO 带 slug tag（`#package-info` / `#highlight-detail` / `#share` / `#pin-forgot`）而非数字 issue 号（§5.2 形式要求打折，实质无碍）。

---

## 6. 优先级问题清单

排序：严重程度降序；同级内修复成本升序。

| # | 问题（模块 · 文件/符号） | 严重×成本 | 证据（含证据等级） | 修复范围 · effort |
|---|---|---|---|---|
| 1 | EPUB 解压无条目大小上限，恶意/畸形书打开即进程 OOM（M7 · `epub_package_parser.dart` `readZipBytes` / `epub_parse_helpers.dart` `parseEpubFileInIsolate`） | 崩溃×低 | 已确认（代码无上限：`final content = entry.content; return Uint8List.fromList(content)`）；崩溃后果疑似（未运行验证） | 单模块两处加 `ArchiveFile.size` 上限判断 · **low–medium**（机械护栏）✅ 已修复 (00bf64a) |
| 2 | 冷备份恢复候选只校验非零字节，截断快照被反复优先恢复，最坏启动失败循环（M2 · `database_service.dart` `_runRestoreFromBackupInIsolate`） | 数据丢失×中 | 已确认（唯一校验为 `if (restoredSize == 0) throw`；坏候选不隔离，按 mtime 恒首选） | 恢复后补 quick_check + 失败候选隔离改名 · **medium–high**（涉自愈路径，受保护面 §3.5-6）✅ 已修复 (b26a9af) |
| 3 | Android persistable URI 授权配额（128/512），大书库静默失去旧书访问权，代码无应对（M3 · `_resolveImportedSource` / `MainActivity.persistReadPermission`） | 数据丢失(可用性)×中 | 需人工确认（平台行为；代码侧"持 URI 不复制、无配额处理"已确认） | 接近配额时降级复制导入或提示；需实机验证 · **high**（导入策略决策） |
| 4 | "导出数据"无 PIN 门禁，私密书架书目/笔记/高亮可三步带走（跨模块 · `settings_page.dart` `_handleExportData` → `backup_recovery_service.dart` `exportGlobalUserData` → `getAllBooks()` 不过滤 is_private） | 隐私×低 | 已确认（调用链三处代码均已读） | 导出前 PIN 校验或默认排除私密书 · **low–medium** ✅ 已修复 (bd8018e，选 PIN 校验方案) |
| 5 | PIN 盐用时间戳毫秒 + 单轮 SHA-256 无 KDF（M11 · `pin_service.dart` `setPin`/`_hashPin`） | 隐私×低 | 已确认（`final salt = DateTime.now().millisecondsSinceEpoch.toString()`）；威胁模型内影响有限（产品自认不防取证） | `Random.secure()` 盐 + 迭代哈希，兼容旧哈希迁移 · **low–medium** ✅ 已修复 (67d282d) |
| 6 | EPUB 内容枚举 TOC 驱动而非 spine，TOC 稀疏的书静默丢正文（M7 · `epub_parse_helpers.dart` `computeEpubParseResultForPackage`） | 功能错误×高 | 已确认（仅 `toc.isEmpty` 才回退 spine） | 改 spine 主序 + TOC 锚点映射；平移现有锚点，需迁移与 golden test 重锁 · **xhigh**（受保护面 §3.5-1/4）✅ 已修复（迁移取方案 3：接受受影响书一次性漂移 + payload `enumVersion` 标记） |
| 7 | EPUB TOC 交错引用同一文件时段落重复计入、锚点偏移（M7 · 同上 `if (filename != chapter.contentFileName)` 仅相邻去重） | 功能错误(边缘)×低 | 已确认（代码事实）；真实书触发罕见 | 改为已解析文件 set 去重 · **medium**（同受保护面，随 #6 一起做）✅ 已修复（随 #6 同一提交，file-set 去重） |
| 8 | Big5/GB18030 TXT 被 GBK 伪解码为乱码（M6 · `txt_reader.dart` `decodeTxtBytesForParse`） | 功能错误×高 | 已确认（代码内 ponytail 注释自认；BACKLOG 列"等真实报告"） | 引入真实 charset 嗅探 · **high**（解码链是锚点地基，§3.5） |
| 9 | SAF MethodChannel handler 在 Android 主线程做整书流拷贝，打开大书掉帧/ANR 风险（M3 · `MainActivity.kt` `copyUriToTempFile`/`readUriBytes`） | 性能×中 | 已确认（handler 默认主线程执行 `input.copyTo(output)`）；ANR 后果疑似（未实机验证） | 原生侧派发后台线程 · **medium–high**（原生+时序）✅ 已修复 (57fc8d2，未实机验证) |
| 10 | 详情页 EPUB 封面提取整书入内存（M4 · `book_details_page.dart` `_loadCoverBytes` → `epub_cover_extractor.dart`） | 性能/内存×中 | 已确认（`BookSourceAccess.readBytes(book)` 全量读）；有磁盘缓存兜底、仅首次 | 改流式（复用 `extractEpubImageBytesFromFile` 模式）· **medium** ✅ 已修复 (a668269) |
| 11 | 设置页直接 `getIt<BackupRecoveryService>()` 破坏 DI 纪律与跨层矩阵（M12 · `settings_page.dart:67/142`） | 代码质量×低 | 已确认 | 加 riverpod provider 一处 · **low** ✅ 已修复 (bd8018e) |
| 12 | core/services → modules/privacy 反向依赖；reader ↔ settings 模块互引（全局 · `service_locator.dart` import `privacy_lock_service.dart`） | 代码质量×低 | 已确认（脚本建图 + import 语句） | 移动文件/下沉注册点 · **low–medium** |
| 13 | bootstrap 25s 超时后 Retry 的 `getIt.reset()` 与仍在跑的旧 setup 竞态（M1 · `main.dart` `_retry`/`_bootstrapServices`） | 崩溃(极低概率)×低 | 疑似（触发需 DI 卡死 30s+ 且用户重试） | 重试前等旧 future 落定 · **low–medium** |

---

## 附录 A · 阶段一原文（无头模式自行推进，按指令稿兜底规则保留供核对）

**规模校准**：`lib/` 143 文件 / 37,110 行；零生成文件；l10n 4,407 行不逐行。大头：reader 12,742、core/ui 6,214、bookshelf 4,792、core/services 2,681。

**深度预算声明**：写透（约 70% 篇幅）——M2 数据层、M3 导入、M5 阅读器核心、M6/M7/M8 引擎、M9 进度持久化；中等——M1、M4、M10、M11、M13（隐私专项）；精简——M12、M14、l10n/平台层一句话。

**模块划分（14 个）**：M1 装配与 DI / M2 数据层 / M3 导入与文件访问 / M4 书架 / M5 阅读器核心 / M6 TXT / M7 EPUB / M8 PDF+契约 / M9 进度书签高亮 / M10 亮度 / M11 隐私 / M12 设置偏好 / M13 广告 / M14 主题与 UI 组件库。

**粗依赖图**：M4→M3→M2；M5→M6/M7/M8（经 Factory）→M3(source access)；M5→M9→M2；所有 UI→M14；M1 装配一切。

**主数据流草图**：导入（file_picker → SAF persist / 沙盒复制 → 指纹去重 → DB books）→ 打开（factory 建引擎）→ 解析（isolate：TXT 解码分章 / 自研 EPUB / pdfx）→ 分页（估算，仅展示）→ 渲染（ScrollablePositionedList + HighlightableText）→ 进度（段落锚点，30s+pause+退出+dispose 四重落盘）。
