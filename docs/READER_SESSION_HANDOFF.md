# 翻页任务交接与已知待办

初版交接日期为 2026-11-06。本次状态更新于 2026-11-19。

## 当前结论与证据 · 2026-11-19

维护者决定保留现有修复，暂停测试和设备操作。**HONOR 第一阶段发布验收记为未完成**，待发布前再补。当前分支为 `codex/reader-turn-location-fixes`，HEAD 为 `4ab1170`。下方保留 2026-11-06 的原始安排和诊断记录。

| 项目 | 结论与证据 |
| --- | --- |
| 旧 10 · 复杂 EPUB 首图与跨版面定位 | **本机定向验证完成，104 项通过。** 首次图片案例把首图绘制与次图进入视窗拆开验证，并记录各图片行的实际位置。跨版面案例验证竖屏切横屏后的回翻，以及新引擎用旧版位置数据恢复到相同图内位置。只调整测试样本和清理流程，旧引擎只释放一次。 [回归日志](../.dart_tool/epub_item10_cleanup/flutter-test.log) · [测试用例](../test/epub_image_resource_test.dart) |
| 13B-1 · 准备与移动阶段 | **HONOR 真机短测完成。** 以 SurfaceFlinger 和 Flutter 的 60 Hz 口径，在正常缓存下完成两轮 36 次翻页，覆盖 TXT 长段、EPUB 长段及 EPUB 插图。移动慢帧 0/792、准备 6/180、交接及后续 0/72，12 组往返均回到起点。结论限于单机同版本短测，整体性能预算尚未验收，原生深度追踪继续搁置。 [短测报告](../.dart_tool/p13b1_honor_20261119/guarded-reader-startup/report.md) · [原始核对](../.dart_tool/p13b1_honor_20261119/guarded-reader-startup/verification.json) |
| 13B-2 · 恢复正文的尾部慢帧 | **HONOR TXT 长段短测未复现，维持观察。** 两轮共 12 次翻页，交接首帧 0/12、后续帧 0/12 慢帧，四组往返均回到起点。释放与恢复标记涵盖整个同步交接区间，现有证据不足以归因于 `dispose`。 [交接帧报告](../.dart_tool/p13b2_honor_tail/report.md) · [原始核对](../.dart_tool/p13b2_honor_tail/verification.json) |
| 13B-3 · 首次字形与图片成本 | **完成 EPUB 正常缓存下的预加载场景对照。** AB、BA 共四次执行、16 次翻页，A/B 只差解码复用。原报告分列点击前加载、首次翻页与回访。四次目标图均在首次点击前约 1.38–1.45 秒解码完成，量测翻页中未重建该图的加载任务，预加载场景未显示额外收益。冷图首次翻页收益仍待验证，本轮未测 TXT 首次字形。 [A/B 对照报告](../.dart_tool/p13b3_honor_normal/evidence-ba-resume/report.md) · [原始核对](../.dart_tool/p13b3_honor_normal/evidence-ba-resume/verification.json) |
| HONOR 第一阶段 · 独立 ARM64 release APK | **未完成。** APK 以 `4ab1170` 为基线，已通过 ARM64、DataStore 和 Android `sqflite` 平台插件离线核对，安装前确认前景无遮挡，安装后 APK 哈希一致。TXT 已打开并完成前后各翻一次，同一段的正文偏移为 `0 → 535 → 0`，回翻后正文核对一致。按 Home 后，当次图层数据无法证明 Hiboard 未遮挡，验收停在后台切换。 [APK 离线核对](../.dart_tool/release_honor_phase1/offline-sqflite/input-verification.json) · [TXT 原始证据](../.dart_tool/release_honor_phase1/evidence-sqflite/txt/exercise/app-events.json) · [停止记录](../.dart_tool/release_honor_phase1/evidence-sqflite/stop.txt) · [验收状态](../.dart_tool/release_honor_phase1/evidence-sqflite/acceptance-status.md) |

### 发布前待补

- **完成 HONOR 第一阶段功能验收。** 保留 TXT 已完成的打开与前后翻证据，补后台恢复和退出重开。EPUB、扫描 PDF、混排 PDF 均未执行，各补一次打开、前后翻、后台恢复及退出重开，逐一核对画面和阅读位置。
- **另行安排发布级设备与资源验证。** 高刷新率、大屏、iOS 真机，以及原生／GPU 内存峰值、温升和耗电仍缺发布级证据。资源短测未执行，连续 20 分钟长测继续延期。

## 原始接手安排（2026-11-06，历史记录）

维护者要求将工作交给新会话，本会话停止继续排查。

继续在当前分支排查 EPUB 插图页长原生提交调用内部、应用 Android 主线程当时执行的工作。
优先复用已有追踪，必要时仅补一次带调用栈的短追踪，使用用户提供的 EPUB。
确认应用侧原因后再修复，不跑长测。完成后报告原因、修复结果和未知项。
这项任务刚获得授权，尚未开始调用栈采集。其他待办按队列保留，不要求同时实施。

## 工作目录和提交（2026-11-06 快照）

- 目录 `C:\Projects\nyan-read`，当前分支 `codex/reader-turn-location-fixes`。
- HEAD `65184f0 fix(reader): reuse the ready capture frame`，消除重复准备帧。
- 前置 `261de5f perf(reader): isolate page turn snapshots`，双截图实现，整体性能仍待验收。
- `dd2c6b1` EPUB 图片布局变化/取消保位；`fbe18f1` 13A 诊断工具；`ae5a630` G2；`f6afd0f` G1。
- 更早 01A、02、03、04、05、08 已分项提交，详见 git log 与对应文档。不要重新实施。
- 工作区有大量既有修改与未跟踪诊断文件。开始前读 git status，不要清理、覆盖或全部提交。
  目前生产 reader 文件和翻页测试已经提交；剩余修改主要是工具、报告和基线。
- 不创建分支或 worktree，继续本地当前分支。未授权推送或合并 main。

## 全部已知待办

优先级为现有商业阅读器目标下的工作排序；复杂度是当前估计，诊断结果可能改变修复范围。

| 顺序 | 项目 | 优先级 / 复杂度 | 当前状态与下一步 |
|---|---|---|---|
| 1 | 13B-1 EPUB 插图移动：原生提交内部、Android 主线程与调度 | P1 / 高 | 应用根因未确认，原生深度追踪继续搁置。保留既有追踪和调用栈记录 |
| 2 | 13B-1 准备/移动整体性能验收，含 TXT、EPUB 普通/长段/插图 | P1 / 高 | 重复准备帧已修复。HONOR 真机短测完成，整体性能预算尚未验收 |
| 3 | 06 PDF 加载完成前的位置恢复请求丢失 | P1 / 中高 | 既有已确认待修问题；与 PDF 横向呈现就绪等待不同。动工前按 AGENTS.md 给出影响/风险/验证 |
| 4 | 13B-2 动画结束后恢复正文的尾部慢帧 | P1 / 中高 | HONOR TXT 长段短测未复现，维持观察。现有证据不足以归因于 `dispose` |
| 5 | 13B-3 首次字形图集、图片首次呈现成本 | P2 / 中高 | EPUB 正常缓存下的预加载场景对照完成。冷图首次翻页收益待验证，本轮未测 TXT 首次字形 |
| 6 | 13B-4 PDF 波动、扫描/图片等复杂 PDF 性能 | P2 / 诊断中等、修复待定 | 主要只有合成 PDF 证据，尚缺复杂文件覆盖 |
| 7 | 13C 首次移动前的剩余响应等待 | P2 / 中高 | 消除重复帧已部分改善约 16–18ms，剩余合理就绪等待与可省成本仍待区分 |
| 8 | TXT 总页数估算与估算缓存键 | P2 / 中 | 字体族、非线性系统文字缩放的缓存键覆盖不完整；不同于已修复的实际阅读定位 |
| 9 | 14 EPUB 段落式进度百分比 | P2 / 中高 | 长段落内推进的表达仍不充分，尚未实施 |
| 10 | 16 EPUB 图片会话缓存上限与淘汰 | P2 / 中高 | 已完成图片数据/Future 的保留修复不等于有界缓存，仍待限制生命周期内增长 |
| 11 | 旧 10 EPUB 复杂内容首次图片、跨版面回退与冷启动恢复 | P2 / 中高 | 已知重挂载图片高度和取消漂移已修复。本机定向验证完成，104 项通过。独立 release APK 的 EPUB 功能验收归入第 12 项 |
| 12 | 发布级设备和资源验证 | P2 / 验证工作 | HONOR 第一阶段未完成，保留 TXT 打开与前后翻证据，发布前补 TXT 恢复与重开及另外三种格式。资源短测未执行，高刷新率、大屏、iOS 真机、原生/GPU 内存峰值、温升和耗电待验收。连续 20 分钟长测继续延期 |
| 13 | 诊断工具、报告、原始证据的整理提交 | 工程收尾 / 中 | 本会话及前几轮诊断大多尚未提交。需保留证据和源码/APK 对应关系，按用户指令另行整理 |

这些是代码文档和当前对话确认的待办，不能将 TXT/PDF 视为已无问题。
早期完整问题清单并未独立落盘到本交接可找到的文件；旧编号 07/09/11/12/15 的原始定义
尚未找到，不能据编号缺失认定已完成。如果后续需要逐编号结项，应先核对原始清单。

## 已完成的重要结果

- 01A 截图 release 安全、02 TXT 实际位置、03 EPUB 翻页定位、04 TXT 旧翻页历史、
  05 模式/布局保位、08 先准备后移动、G1 正文横滑、G2 连点与选字已修复。
- EPUB 已完成图片数据/尺寸在重挂载和缓存驱逐后保留，修复已知取消翻页保位漂移。
- 13A 独立性能对照和逐帧诊断已完成，整体性能验收仍开放。
- 重复准备帧修复已提交，每次少一个准备帧，原文件 12 对位置一致。
  精确提交快照验证：前置 8 项翻页测试，修复 10 项翻页测试、2 项采集兼容测试和静态检查通过。
- 两个曾试验的候选（平移内部增加绘制边界、准备阶段裁掉被遮正文）均无稳定性能收益，已撤回。
  不要把 rejected 目录中的实现恢复到生产。

## 原生提交与调度诊断（2026-11-06，历史记录）

先读 `docs/READER_EPUB_IMAGE_MOTION_REVIEW.md`，包含最新原生/调度复审。
再读 `docs/READER_PERFORMANCE_13B1_BUFFER_CHAIN.md`、`docs/READER_PREPARATION_FRAME_FIX.md`，
历史背景读 `docs/READER_PERFORMANCE_13A_RESULTS.md`。

该阶段的对照数据保存在 `.dart_tool/perf_epub_matched/`。

- 同一 APK `B.apk` SHA256 `4bc056c9dc1eacf5c9b78c2a803bc4533b9e96ca052c8d848dfb22441a4c5840`。
- `results/matched-epub_normal/`、`matched-epub_image/` 为正文→插图。
- `results/reverse-epub_image/`、`reverse-epub_normal/` 为插图→正文。
- 每次全新安装专用测试应用；字号 18、行高 1.5、无衬线、固定各场景位置，预热 6 次，
  测量前翻 3 次回翻 3 次。first 路径另有 2 次，不纳入热态比较。记录未报告丢包/覆盖。
- 各目录有系统 `system.pftrace`、VM `flutter-timeline.json`、原始场景 JSON、
  `matched-motion.csv`、`causal.json`、`native-scheduling.sql/csv/json`。
- 反向插图目录额外有 `preemption.sql/csv`、`main-contention.sql/csv` 与帧级 SQL。
- 可复现的本地脚本 `run.py`、`reverse_run.py`、`analysis.py`、`compare_order.py`、
  `native_scheduling.py`；四轮汇总 `order-comparison.json`。

热态移动中段明显等待（>8ms）：

| 顺序 | 正文 | 插图 |
|---|---:|---:|
| 正文→插图 | 35/90 | 49/92 |
| 插图→正文 | 14/84 | 48/86 |

两种顺序下插图都更频繁等待，但等待前短间隔提交（<8ms）条件占比没有比正文更高。
扣除释放等待后，原生提交中位数四场景均为约 0.58–0.62ms。
原生提交 >8ms 主要集中在少数帧，反向插图 6/86，反向正文 2/84。
插图帧 628 的原生提交约 15.03ms，其中实际运行约 5.34ms、等 CPU 约 9.65ms；
此前 CPU 同期运行应用 Android 主线程和 SurfaceFlinger TimerDispatch。
主线程当时没有更细调用切片，尚不知具体工作。
插图帧 686 的 BLAST 获取缓冲区间约 16.59ms，无更细子调用切片；原生运行也有长尾。
原生调用区间包含内部图形/系统工作，不能全部认作应用业务成本或 GPU 纯耗时。
反向插图等待外长工作后下一帧明显等待为 4/7，其他可比帧为 42/77，未建立稳定因果差异。
尚未证明这些少数长帧能解释插图总体等待率。生产代码因此保持在 65184f0。

分析注意事项：

- buffer 编号、Flutter frame ID、FenceMonitor 序号是不同体系，不能硬拼。
- 用 clock_snapshot 中 MONOTONIC 换算，把原始 FrameTiming raster 区间与系统切片关联。
- 切片嵌套不可加总。区分绘制、swap 内非释放等待、释放等待、实际运行、就绪等 CPU、睡眠。
- CPU 抢占时最后所在 CPU 的其他任务，仅说明该 CPU 占用，不证明所有 CPU 饱和或全局饥饿。
- Flutter 超 16.67ms、系统 latch 间隔、HWC present API 时长和物理呈现延迟不同。
- 重型追踪只用于归因。两组小样本、宿主负载/窗口调度未隔离，勿宣布商业性能验收通过。

## 环境与短采集约束

- Windows，Flutter `C:\flutter\bin\flutter.bat` 3.38.9 / Dart 3.10.8。
- ADB `C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe`。
- 模拟器 `Medium_Phone` / `emulator-5554`，Android 16 x86_64，1080×2400，DPR 2.625，60Hz，
  Impeller OpenGLES。开始前重新检查设备状态，不能假定仍运行。
- 专用包 `com.example.nyan_read.perf13a`，日常应用是 `com.example.nyan_read`。
  仅允许清理测试包及测试副本。安装空间不足时沿用全新专用包安装流程，不动日常数据。
- 用户样本目录 `C:\Users\User\Downloads\Mobile Devices`。EPUB 大小 193460451 字节，
  SHA256 `486fff823e05f54e623528ce488b211b6196c6aa751272b74e6565ef133d3915`；TXT 大小
  9190763 字节，SHA256 `908bc3552974c31f1ed3c8c25ee83e289773ca44f7c84c84aa1a16a4dc5844a9`。
  按扩展名与大小定位，保留原文件，日志不要输出书籍正文。
- `tool/reader_baseline/run_13a.py`、`perf13a_heavy.py` 提供采集；旧 `HeavyTrace` 时限 90s，
  通常单场景实际运行 36–41s 后主动结束。调用栈如需新采集，应设计更小明确窗口。
- 官方本地 Perfetto 处理器 `.dart_tool/perf13a/trace_processor.py`，已有 v59.1 缓存。
- VM 应先以 in-memory recorder 启动并附着，再开始系统 ATrace，否则 Flutter 可能切到系统记录器。
- 测量时不并行编译、测试或重型分析，采集完再解析。不要恢复 20 分钟长测。
- 先读本地 AGENTS.md。分页/定位/恢复等受保护面遵循影响、风险、验证及授权要求。

## 未提交状态与本次交接

本交接文件是状态说明，尚未提交。所有诊断目录在 .dart_tool 下，可能未入 Git，
所以新会话使用同一项目的本地目录至关重要。
已知未暂存修改包括 docs/PERFORMANCE.md、analyze_13a.py、run_13a.py、run_profile.ps1、
test_analyze_13a.py；其他新增报告、基线与工具以 git status 为准。
本会话在交接后不再执行测量、代码修改或提交，由新会话接管。

## 接管后的单次调用栈采集结果（2026-11-06）

已完成本轮授权的有界排查，未改生产代码，HEAD仍为65184f0。新增一次约36秒插图场景采集，
在两个等待外长提交样本内分别捕获模拟器QemuPipe图形同步、BLAST→SurfaceFlinger Binder事务栈。
主线程移动时间窗内捕获计时器维护、Vsync请求、Dart消息处理等栈，但没有重现旧帧628的
同CPU主线程竞争窗口；部分AOT函数仍无符号。尚未确认可修复的应用业务原因，第1项保持开放。
新记录有12条perf lost records，不能作为无损证据或整体性能验收。未增加第二次采集或长测。
详情见READER_EPUB_IMAGE_MOTION_REVIEW.md末节；本地新证据在`.dart_tool/perf_epub_stacks/`。
旧四份追踪、原工作区全部保留，其他待办顺序不变；未提交、未推送。

## 诊断副本前置门槛的后续尝试（2026-11-06）

用户授权消除2ms轮询、验证符号，满足条件后仅一次短采集。独立副本在
`.dart_tool/perf_epub_attribution/`；完成通知及原翻页流程共15项测试通过，实际运行PC成功
还原为函数/源码行，APK与符号Build ID匹配。生产源码未变。

但原门槛漏检VM服务握手：唯一一次场景启动在attach_vm失败，系统采样未开始。
只读核查确认APK的libapp.so使用dwarf_stack_traces_mode，而libvmservice_snapshot.so
为no-dwarf_stack_traces_mode，日志明确报告不兼容。应用主隔离区仍运行，服务未启动。
按停止条件未重试或重建。归因门槛已标为未通过，初次符号验证记录保留。
未追踪的6次warm翻页位置一致，但不得作性能归因数据；应用侧根因仍未知。
下一次场景前必须先让不打开书籍的前置入口同时验证符号还原和真实VM时间线服务连接。
详情见READER_EPUB_IMAGE_MOTION_REVIEW.md末节；没有新生产修复或提交，其他队列不变。

## 最新：快照兼容问题解决，前置符号/时间线握手通过（2026-11-06）

用户本轮仅授权独立副本修复和能力验证，未授权恢复翻页或采样。
新构建改为单独save-debugging-info + no-strip，保持no-dwarf_stack_traces_mode，
与内置VM服务快照匹配。不使用会切换运行时栈格式的split-debug-info。
新证据在`.dart_tool/perf_epub_attribution/compat-no-dwarf/`。

APK SHA256 `9104369718dab8466cd6243e3456e8ca29c7e47483a01817f3fa7b791ce31093`，
符号Build ID `90435225eed65d6c2fea19eca41a29b8`。3个AOT函数的配套地址还原到非零源码行，
实际运行栈也返回诊断anchor函数/源码；getVM、服务扩展nonce回执、Endless内存时间线同nonce
标记、Dart/Embedder/GC流及无快照不兼容日志全部通过。新gate-result.json为passed。
没有打开书籍、翻页或CPU/系统采样；验证后专用应用已停止、转发移除。

父目录旧失败APK/门槛保留；不要用旧run_once.py启动场景，不要把新门槛嫁接到旧包。
本轮到此结束。生产代码/测试无diff，仍在65184f0，未提交推送。应用侧根因仍未知。
详细证据和静态地址/运行栈的区别见READER_EPUB_IMAGE_MOTION_REVIEW.md最新一节。

## 最新：兼容APK单次短采集已完成并停止（2026-11-06）

用户再次授权唯一一次短采集。使用已通过前置门槛的兼容APK和配套符号，在原EPUB/位置/设置
预热后3前翻3回翻，约41秒完成，无追加轮次、长测或生产改动。6次轨迹与旧插图一致。
证据在`.dart_tool/perf_epub_attribution/compat-no-dwarf/results/foreground-compatible-once-epub_image/`。

关键发现：raster596释放等待内，被SurfaceFlinger唤醒后就绪等CPU6.377ms；最后所在CPU2同期
执行应用主线程UI597的构建/布局，实际栈还原到Opacity.updateRenderObject等框架更新。
三段等待外长提交（652/675/711）进入BLAST/Binder或createNativeSync ioctl路径。
关联Binder均为0x11单向异步，接收间隔不能当同步阻塞时长。

未报告lost/overwrite，但有perf_samples_skipped=2；主线程409、raster401样本均有栈。
仍无唯一业务调用者/冗余工作证据，不能证明插图总体等待率根因。按约定停止，不提出猜测性
生产修复。最新详细分析见READER_EPUB_IMAGE_MOTION_REVIEW.md末节。
仍为65184f0；现有工作区和原始证据保留，未提交推送。旧场景入口不要重跑。

## 最新：离线收窄UI597业务组件范围（2026-11-06）

仅复用追踪和源码，未启动应用/采样、未测试或改生产。UI597嵌套BUILD起点后3微秒出现
SmoothPageReader动画builder既有标记，证明该组件参与该作用域；两Stack+Opacity更新栈高度
匹配截图动画层。LayoutBuilder拥有独立BuildScope，flush dirty后代不等于业务builder重跑，
因此不能据此归因EPUB正文或整个ReaderPage重建。
request0的21动画UI帧中最长BUILD中位数0.045ms，仅597超过1ms，属单次长尾。
仍缺Element身份、各业务builder/段落实际计数、dirty来源、包含子节点核对的组件完整耗时。
下一步建议仅独立副本结构探针测试，再有授权时一次定向事件级短验证；本轮没有实施。
详见READER_EPUB_IMAGE_MOTION_REVIEW.md最新一节。生产仍65184f0，其他队列不变。

## 最新：结构探针测试通过，尚未采集（2026-11-06）

用户仅授权独立诊断副本结构测试。新增DiagnosticAnimatedBuilder的StatefulElement探针，
performRebuild外层包含builder返回后的同步子节点核对；8结构测试+5完成观察器+10原翻页
测试=23项通过，静态检查清零。可控时钟2+7=9证明包含子节点update，不是实际性能测量。
测试区分动画后代更新、父层业务builder重跑、约束变化和正文独立通知，并覆盖嵌套、异常、卸载。

仅诊断project源码改变；新探针未构建为APK，未启动应用/采样或长测，生产无diff。
旧兼容APK及符号哈希保持。真实ReaderPage/EPUB计数还未接入，不能把缩小结构的测试计数当作
用户EPUB行为。后续须获准接入定向计数、构建并重过符号/VM门槛，不能直接用旧APK采新探针。
证据在`.dart_tool/perf_epub_attribution/structural-probe/`；详见排查报告最新一节。
本轮停在测试报告，其他待办队列不变，未提交推送。

## 最新：真实业务计数接入，新APK及前置功能验证通过（2026-11-06）

仅独立诊断project接入ReaderPage布局/筛选分支通知与build、EPUB配置/高亮/viewport/
段落/图片等计数，保留动画Element完整重建探针。4新增计数/实际EPUB测试+原23项=27项通过。
新证据在`.dart_tool/perf_epub_attribution/business-counters/`。

APK SHA256 `a039ce8a8ec43e1e763649cdccd13835d41fc378e7921fa6e294d19f21748fe4`，
Build ID `90435225da2f22a22fea19eca15db710`。符号非零源码行、VM服务、Endless标记回读及
真实ReaderPage/EPUB计数功能验证全通过。功能入口只开极小合成EPUB，改一次字号和高亮版本，
不使用用户书或翻页；计数证明通知不等于重建、外层布局回调不等于内层构建。
新探针5个闭合span，无溢出/未闭合。gate-result.json为passed。

本轮没有性能场景、系统/CPU采样或长测；生产无diff，原工作区和旧APK/符号/追踪均保留。
没有自动运行后续场景；将来如获授权必须显式businessCounters=true并使用此目录新包/符号。
详细计数表和限制见排查报告最新一节。未提交推送。

## 最新：定向事件短验证完成，未复现移动长尾后停止（2026-11-06）

按用户授权仅一轮，使用business-counters目录验证通过的新包/符号，businessCounters=true，
原EPUB/位置/设置，预热后3前3回，约36秒完成。没有linux.perf源，perf_sample=0，系统/业务
记录无丢失或溢出，6次位置一致。证据在business-counters/results/foreground-business-events-once-epub_image/。

移动121UI帧全部有完整动画Element探针；六次动画时间窗及UI帧内，已接入的正文/父层业务
构建计数均为0。段落29次、图片State7次、图片Future14次均在导航准备/就绪阶段。
最长移动BUILD0.884ms，对应动画Element0.873ms（builder0.033+子节点更新0.840）；
旧UI597的5.830ms长构建未重现。不能追溯确认旧根因，也不当作新旧包性能改善。
按约定停止，不追加轮次，不提出生产修复。生产仍65184f0、无diff，无长测、提交或推送。
详细归属、未覆盖范围及准备阶段区别见排查报告最新一节。一次性场景入口不要重跑。

## 维护者决定切换工作项 · 2026-11-06

维护者明确表示本项验证耗时过多：若始终无法确认，应进入下一环节。
据此停止EPUB插图长尾归因及其追加验证，状态保持“未复现、根因未确认”，不结为已修复。
整体性能验收保持延期，不以该项尚未闭环为由继续采集。

下一优先处理有明确代码缺陷的第06项PDF加载前恢复请求丢失。
只读复查确认PdfReaderEngine.goToPosition在_isDocumentReady为false时直接返回；
ReadingProgressManager.restoreLastPosition会把该调用正常完成视作已提交恢复。
尚未修改生产代码。PDF恢复属于AGENTS.md §3.5受保护面，需提交影响/风险/验证并获明确同意后实施。
保留现有分支、工作区、全部诊断源码/APK/符号和证据，无提交推送。

## 第06项：PDF加载前恢复请求丢失已修复 · 2026-11-06

维护者已明确授权上述范围的修复、针对性测试及架构文档更新，并要求保留现有变动、
不跑长测、不提交或推送。本轮按该范围完成生产修复。

PdfReaderEngine保留最新待执行页码/进度目标，在文档加载成功且页面控制器挂载后的帧边界
应用；章节跳转和加载中的前后翻页遵循同一请求顺序。新请求替换旧目标，页码裁剪至有效范围，
打开失败传播错误，销毁释放等待者并阻止迟到恢复。没有增加固定延时，公共方法签名和数据库未变。
恢复提交完成与既有PDF图片呈现就绪等待仍是不同阶段。

本轮涉及pdf_reader.dart、test/pdf_page_presentation_test.dart、READER_ARCHITECTURE.md及本交接追加记录。
12项PDF定向测试通过（新增10项、保留原有2项呈现测试），覆盖延迟加载、挂载前请求、最新目标、
重复请求、页码边界、加载中翻页、重新挂载、失败、销毁；修改的Dart文件静态检查无问题。
测试使用MethodChannel桩，不代表原生性能或真机验收。未做EPUB采样、性能矩阵或长测。
此前EPUB长尾仍为“未复现、根因未确认”；旧诊断源码/APK/符号/追踪和未提交变动全部保留。
分支仍为codex/reader-turn-location-fixes，HEAD仍为65184f0，未提交推送。

## PDF文档关闭生命周期修复 · 2026-11-06

13B-2只读核查未确认具体冗余；13B-3只读核查未确认重复字形/图片工作，均保留待办。
13B-4只读核查发现独立的资源释放缺口：pdfx 2.9.2的PdfController.dispose不关闭PdfDocument，
原引擎在正常退出及迟到加载后均未显式关闭文档。此缺口不等于历史PDF慢帧原因已确认。

维护者已明确授权修复文档关闭生命周期、补针对性测试和更新架构文档。引擎现在拥有文档，
退出后等待加载结算和所有已提交页面Future收尾（包含pdfx的page.close），再关闭文档一次，
成功后删除临时副本。加载失败不重等已拒绝Future、不关闭不存在的文档；文档关闭失败报告至
现有Flutter错误处理器并保留临时副本。没有新增固定延时或改变公共契约、分页、渲染尺寸和缓存策略。

新增test/pdf_document_lifecycle_test.dart的10项测试通过，覆盖正常/重复退出、迟到加载、
在途渲染、页面关闭阻塞、排队请求、打开失败、渲染失败、临时文件顺序和关闭失败；
原12项PDF定位/呈现回归通过，共22项。READER_ARCHITECTURE.md已同步资源所有权和清理顺序。
这是通道桩的生命周期验证，未进行原生性能或复杂PDF验收；13B-4性能波动及覆盖缺口继续保留待办。
全部既有变动、诊断源码/APK/符号/追踪保留，没有追加采样、长测、提交或推送。
