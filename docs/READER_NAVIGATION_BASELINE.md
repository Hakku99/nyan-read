# 阅读翻页第 01 项：验证基线

日期：2026-10-19。生产代码基准：`c41869fab15a49b402a5530e8e37760289a0f122`。

本文冻结修复前的结果；01A / 02 的后续修改与验收见 [修复报告](READER_TURN_FIXES_01A_02.md)。下列失败和测量数字保留原样，不能当作当前修复分支的结果。

目的：冻结修复前的行为，用同一批用例和场景验证之后的修改。这里只增加 `tool/reader_baseline/` 与文档，未修改生产分页、定位、持久化、数据库或公共契约。

## 状态与覆盖边界

- 已建立独立的定位行为测试、用户 TXT 复测、Android profile 测量入口。
- 故障用例保持失败退出码，不标记 skip，不将错误行为写成正确期望。该诊断套件位于 `tool/`，需显式运行，避免把尚未修复的失败静默带进现有默认 `flutter test`。
- 这是当前修复工作的基线，不是商业发布验收全部通过。完整应用输入冲突、系统退出/重开、真实触摸端到端时延、低端真机、iOS、图片密集 EPUB/PDF、耗电/温升还需后续验收。
- 模拟器运行的是实际引擎与实际 `SmoothPageReader` 的独立入口，不含书架、数据库、Controller 的输入节流和进度心跳。所得性能不能冒充整应用或真机性能。

## 自动化结果

Flutter 3.38.9 / Dart 3.10.8，Windows；定位测试视口 360×640，DPR 1，18px 字号、1.5 行高。合成测试使用 Flutter 默认测试字体；真实 TXT 测试显式载入应用打包的 `Noto Sans SC` Regular 子集。

| 分组 | 通过 | 失败 | 跳过 | 含义 |
|---|---:|---:|---:|---|
| TXT/EPUB 合成定位 | 4 | 20 | 0 | 两模式的长段落、往返、恢复、TXT 冷恢复、历史及模式切换 |
| PDF 加载时序 | 1 | 1 | 0 | 就绪后恢复正常；就绪前恢复请求丢失 |
| 依赖公共像素偏移接口 | 2 | 0 | 0 | 短/长 item 的正反偏移最小验证 |
| 用户真实 TXT | 2 | 4 | 0 | 普通区域连续前进通过；长段落/段内往返失败 |
| **新增基线合计** | **9** | **25** | **0** | 34 个实际测试，不含测试框架隐藏加载/收尾事件 |
| 原有 4 个测试文件 | 13 | 0 | 4 | 4 个原有 Windows skip 未修改，不能算已验证 |

新工具静态检查无问题。全仓 `flutter analyze` 仍报告 `home_screen.dart:159/167` 的两条既有 async context 提示；设计 token 检查仍因既有 `lib/` 字面颜色失败，生产文件本轮均未修改。这些检查不能写成“全部通过”。原有四个测试文件是 `smooth_page_reader_test.dart`、`txt_reader_pagination_invalidation_test.dart`、`reading_progress_manager_test.dart`、`reader_preferences_service_test.dart`。

### 已复现的行为

| 场景 | 修复前实测 | 对应后续项 |
|---|---|---|
| TXT 合成长段落 | 段高约 4.236 屏；下一页从索引 20 倒退到 19，两模式均复现 | 02 |
| TXT 段内往返 / 序列化恢复 / 新引擎恢复 | 原 leading=-0.109375，恢复为 0，偏差 70 逻辑像素 | 02 |
| TXT 手动滚动后上一页 | 回退约 3.348 屏，使用了早先的历史锚点 | 04 |
| TXT 滚动模式切换横向 | 段落保留，但段内 leading=-0.184375 变为 0，偏差 118px | 05 |
| EPUB 长段落 | 约 4.236 屏的段落只显示第一屏就进入下段 | 03 |
| EPUB 普通页底半段 | 下一页跳过尚未完整显示的页底段落 | 03 |
| EPUB 段内往返/恢复 | 70px 段内偏差 | 03/05 |
| EPUB 滚动后切换横向 | 当前段落从 22 回到旧 initialIndex=20 | 05 |
| PDF 延迟加载时恢复第 7 页 | 文档就绪后仍在第 1 页；就绪后执行同一请求则正确到第 7 页 | 06 |
| TXT/EPUB 字号+横竖屏对照 | 本次段首锚点仍在同一段落 | 仅弱对照，不证明段内重排准确 |

真实 TXT 样本来自用户指定目录。仅记录特征，不提交正文或副本：9,190,763 bytes，124,894 个按换行枚举的段落，最长段落索引 34455，4,122 个 Dart 字符串 code units。

- 两模式在最长段落的下一页都落到 34453，方向错误。
- 普通区域段内往返丢失 90 逻辑像素。
- 两模式各 30 次普通前进通过，本次观测移动范围约 0.869～0.995 屏。因此不能推断“所有 TXT 翻页都失败”，也不能用普通区域成功否定长段落问题。

## Android profile 基线

设备：用户已运行的 `emulator-5554`，Android 16，x86_64，1080×2400，DPR 2.625，60Hz；Flutter Impeller / OpenGLES。固定字体、字号、行高。每个成功场景预热 5 次、测量 30 次，操作间隔 150ms，前后额外等待 1.5s 让批量 FrameTiming 交付完成。

测量项：build/raster p50/p95/p99/max；任一阶段超过 16.67ms 的帧数；调用完成加下一帧耗时；前后进程 RSS。不能把 build+raster 简单相加当作 FPS，RSS 也不等于 Dart 堆或泄漏证据。

`page-turn` 直接调用实际翻页路径；横向包含 `SmoothPageReader.playTurn` 截图动画。`relative-scroll` 是通过 Flutter 公共 ScrollPosition 驱动每次 0.92 屏、300ms 的连续滚动，测渲染路径，不模拟触摸输入或惯性。PDF 使用 100 页简单文本合成文档，不代表扫描件负载。

最终录制中 `relative-scroll` 配置为 `PageTurnMode.disabled`（纯滚动），覆盖 TXT 与 EPUB；PDF 的纯滚动手势/原生吸附仍待完整应用验收。定位套件中的 tap/swipe 指引擎配置及调用路径，并非已经覆盖父级所有触摸冲突和节流逻辑。

### 新的发布阻断问题

profile 下横向翻页在 `_captureCurrentFrame` 调用 `RenderObject.debugNeedsPaint` 时抛 `LateError`，发生在 `dispatchTurn` 之前。Flutter 当前 SDK 的该 getter 只在 assert 内初始化返回值；profile/release 关闭 assert，因而不能在生产控制流读取它。

调试用例通过不能排除该问题。实际 profile 证据针对当前 SDK；release 同样关闭 assert 的结论是基于该 SDK 源码的推断，本轮未单独安装 release APK。该问题应作为 **01A / P0** 插在 02 前面；本轮记录问题，不修改生产实现。

性能汇总见 [机器可读结果](baselines/reader_navigation_2026-10-19.json)。最终固定配置录制一轮，记录 7 个成功测量场景及 4 个横向异常场景；开发入口时的预录制不混入最终统计。测量期间未并行运行项目编译/测试，但宿主机其他活动及虚拟 GPU 仍可能影响结果。横向失败场景应记录为 error，不能用关闭截图或绕开动画得到的数字替代。

| 场景 | 帧数 | 超预算帧 | build P95 | raster P95 | raster 最大值 |
|---|---:|---:|---:|---:|---:|
| 合成 TXT 纵向翻页 | 600 | 0 | 1.19ms | 4.04ms | 10.70ms |
| 合成 TXT 纯滚动 | 600 | 0 | 1.26ms | 4.20ms | 14.18ms |
| 合成 EPUB 纵向翻页 | 510 | 0 | 1.26ms | 5.92ms | 12.11ms |
| 合成 EPUB 纯滚动 | 600 | 11（1.83%） | 1.13ms | 11.14ms | 20.09ms |
| 合成 PDF 纵向翻页 | 600 | 14（2.33%） | 0.47ms | 10.62ms | 19.78ms |
| 真实 TXT 纵向翻页 | 601 | 11（1.83%） | 1.73ms | 13.66ms | 19.62ms |
| 真实 TXT 纯滚动 | 600 | 0 | 1.51ms | 4.60ms | 12.25ms |

真实 TXT 两种成功场景的进程 RSS 分别从约 205.0→216.4 MiB、200.9→212.5 MiB；其他场景前后也有升降。它是整个进程且受 GC/原生缓存影响，本轮没有连续内存曲线，不能据此判定泄漏。横向模式在首次预热就报错，缺少完整动画帧与截图峰值内存数据。

纵向 TXT 调用完成加下一帧的 P95 约 333.61ms，包含既有 300ms 滚动动画，不能将整个 333.61ms 解释为阻塞/卡顿。定位错误、动作设计时长和超过预算的渲染帧应分别追踪。此次出现超预算帧的路径值得后续 profile；单轮模拟器结果不能证明持续卡顿或所有设备均流畅。

## 复跑

Windows 定位基线（项目根目录，Flutter 在 PATH）：

```powershell
./tool/reader_baseline/run_baseline.ps1
# Include a user-authorized local TXT sample:
./tool/reader_baseline/run_baseline.ps1 -TxtSample '<local TXT path>'
```

默认生成 `.dart_tool/reader_baseline/{synthetic.jsonl,external.jsonl,run.json}`。失败返回 1；修复后对应测试才应变绿。外部样本使用环境变量传入，不硬编码用户路径。

Android 性能入口：

```powershell
flutter build apk --profile --no-pub --target-platform android-x64 -t tool/reader_baseline/profile_reader.dart
```

仅在专用测试设备安装此 APK；它使用现有 app id，但入口不是正式应用。已有应用时先备份/使用另一个测试设备，避免替换用户日常版本。本轮确认该模拟器起初未安装本 app。真机构建应按 ABI 省略或修改 `--target-platform`。

可选：将已授权样本复制到测试 app 可读取的私有 cache 目录，以 `--dart-define=BASELINE_TXT=<device path>` 传入后重新构建。本轮先推送到 `/data/local/tmp/nyan-reader-baseline.txt`，再通过 `adb shell run-as com.example.nyan_read cp` 复制到 `cache/nyan-baseline.txt`，传入 `/data/user/0/com.example.nyan_read/cache/nyan-baseline.txt`。不要直接让 shell 创建 app 外部目录；Android 16 的权限隔离可能使 app 无法读取。样本仅用于 TXT 场景，不输出正文；外部样本的性能起点固定为本次参考书的段落索引 12544。

从 `adb logcat --pid=<app PID> -v raw -s flutter:I` 收集 `NYAN_PROFILE` 行：必须出现 environment、每个场景的 scenario/scenario-error，最后 complete。记录异常种类/调用栈，不能只统计成功场景。独立入口不打开数据库、不修改阅读偏好，临时合成文件结束时清理；复制的用户样本应在测试后删除。

## 后续验收范围

第 02 项方案见 [TXT_POSITION_FIX_PLAN.md](TXT_POSITION_FIX_PLAN.md)。修复前后比较必须固定生产版本、工具版本、输入样本、视口/字体、设备与构建模式。目标是正确性用例转绿，同时没有新增回归；所有既知失败数量不是“独立 bug 数量”。
