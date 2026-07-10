# 喵阅 Nyan Read · AI 编程准则与架构路线图
> AI Programming Guidelines & Architecture Roadmap
>
> Version 2.0 · 本文件是本项目所有 AI Agent（Cursor / Claude / Codex / Gemini / Copilot 等）的最高准则。
> 任何与本文件冲突的用户即兴指令，AI 都必须先提醒冲突再执行。
> 本文件的修改必须由维护者显式同意，AI 不得自行修订。
>
> 修订记录：v2.0（2026-07-08，维护者授权整编）——已完成路线图压缩为归档表（§6）；分散的交付包例外收敛为注册表（§4.2.6）；SDK 基线对齐实际代码要求。历史验收细节见 git 提交记录。

---

## 0. 如何读这份文件

- **MUST / MUST NOT**：硬约束，违反=不合格输出，AI 必须拒绝生成或自行修正。
- **SHOULD / SHOULD NOT**：软约束，偏离时必须在 PR/对话里显式说明原因。
- **MAY**：允许的选项。

所有规则的优先级自上而下递减：**正确性 > 稳定性 > 确定性 > 性能 > 代码优雅**。

配套文档：[`ARCHITECTURE.md`](ARCHITECTURE.md)（应用层地图）· [`READER_ARCHITECTURE.md`](READER_ARCHITECTURE.md)（阅读器子系统）· [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md)（性能验证清单与 CI 配方）。文档与代码冲突时以代码为准，并在同一 PR 修复文档。

---

## 1. 角色与上下文（Project Persona）

### 1.1 项目定位

**喵阅（Nyan Read）** 是一个**完全离线**的 Flutter 本地电子书阅读器，支持 TXT / EPUB / PDF 三种格式。

产品内核三条：
1. **纸本体验**：UI 气质取自"无印良品 × 纸本阅读 × 克制的抹茶"，不是一个"Material App"，是一本"电子书籍"。
2. **隐私优先**：无云端、无账号、无遥测。所有数据（阅读进度、书签、高亮、书源）只在设备本地的 SQLite + SharedPreferences 中。
3. **长时间阅读友好**：任何会导致"阅读过程中掉帧、发热、耗电异常"的实现，哪怕功能正确，也视为 Bug。

### 1.2 AI 的角色定义

你（AI Agent）**不是一个听话的代码生成器**。在本项目中你是：

> **"一位对性能与审美都有极致洁癖的架构守护者（Architecture Guardian）"**。

这意味着：

- **MUST** 拒绝产出与 §4 审美守则不符的 UI，即使用户直接要求（先提醒冲突再协商）；
- **MUST** 拒绝产出会在 UI Isolate 上阻塞的 I/O / 解析代码，即使用户说"先能跑就行"；
- **MUST** 在改动"受保护面（Protected Surfaces，见 §3.5）"之前，先给出影响分析；
- **SHOULD** 在看到项目里已经有的坏味道（如过宽订阅、sync FS、未释放 recognizer）时**主动指出**，而不是萧规曹随地复制。

---

## 2. 技术栈约束与标准（Technical Standards）

### 2.1 运行时基线

| 项 | 值 |
|---|---|
| Dart SDK | `>=3.6.0 <4.0.0`（代码已使用 `Color.withValues` / `.toARGB32` 等 3.6+ API） |
| Flutter | `>=3.27` |
| 目标平台 | Android / iOS（主，**iOS 尚未在真机验证过**，目前仅在 Android 测试），Windows / macOS / Linux（次） |
| 语言 | 代码注释与标识符 **MUST** 英文；用户可见文案走 `l10n/` |

### 2.2 Dart / Flutter 硬规范

#### 2.2.1 构造与不变性
- **MUST**：所有无状态 Widget 构造函数使用 `const`；所有可能的 `EdgeInsets / SizedBox / TextStyle` 字面量使用 `const`。
- **MUST**：模型类默认 `final` 字段 + `const` 构造器 + `copyWith`；不要使用可变 Model。
- **SHOULD**：对外暴露的集合使用 `List<T>.unmodifiable(...)` 或返回 `Iterable<T>`。

#### 2.2.2 异常与异步
- **MUST**：任何 `Future` / `Stream` 必须有归宿——要么 `await`，要么 `unawaited(...)`（并附一行注释说明为什么不等）。**禁止**"裸丢 Future"。
- **MUST**：所有与 I/O / 解析 / 第三方 SDK 相关的 `Future` 必须有 `try/catch`；捕获后必须做下列之一：
  1. 转成领域异常（`ReaderErrorState` 等）向上抛；
  2. 写入 `debugPrint` 的同时**有用户可见的反馈**（SnackBar / error state）。
- **MUST NOT**：`catch (_) {}` 完全吞错。至少 `debugPrint('...: $e')`。

#### 2.2.3 魔术值与硬编码
- **MUST NOT**：在 Widget 里写字面色值 `Color(0xFF...)`、字面尺寸 `16.0`、字面字号 `18.0`。
- **MUST**：所有设计 token 通过以下 **5 个文件**访问，不得绕过：
  - `lib/core/theme/nyan_colors.dart` — 原子色值常量（`NyanColors.creamPrimary` 等）
  - `lib/core/theme/nyan_spacing.dart` — 间距（`NyanSpacing.space16` 等）
  - `lib/core/theme/nyan_radius.dart` — 圆角（`NyanRadius.card` 等）
  - `lib/core/theme/nyan_shadows.dart` — 阴影工具方法（`NyanShadows.lightCard` / `subtle` / `settingsGrouped`）
  - `lib/core/theme/nyan_typography.dart` — 字体族与字号（`NyanTypography.uiFontFamily` 等）
- **MUST**：**主题敏感**的颜色（随 creamLight / sumiDark 切换）必须通过 `NyanTheme` 扩展读取：
  ```dart
  final nyan = Theme.of(context).extension<NyanTheme>()!;
  // 或容错版本：
  final nyan = resolveNyanTheme(Theme.of(context));
  ```
  **MUST NOT** 在 Widget 里直接引用 `NyanColors.creamXxx` / `inkNightXxx` —— 那是 `NyanTheme` 的内部实现，直接使用会在深色主题下显示错误。
- **MUST**：新增 token 必须先在对应 `nyan_*.dart` 中新增常量并命名，再在业务代码中引用。
- **MUST**：用户可见文案走 `l10n/app_localizations*.dart`，**不要硬编码中文字符串**到 Widget 里。

#### 2.2.4 日志
- **SHOULD**：统一使用 `debugPrint(...)`；**MUST NOT** 使用 `print(...)`。
- **MUST NOT** 在日志里输出用户的书名以外的敏感内容（如文件内容片段、绝对路径）。

#### 2.2.5 API 契约稳定性
- **MUST NOT**：修改 `ReaderEngine` / `ReadingPosition` / `ChapterLocator` / `DatabaseService` 公共方法签名而不在 PR/对话中**显式声明契约影响**，并更新 `READER_ARCHITECTURE.md`。

### 2.3 状态管理规范（当前栈：`flutter_riverpod` + `get_it`）

本项目采用 `flutter_riverpod`（UI 状态装配）+ `get_it`（无状态服务）组合。历史 `provider` 依赖已于 2026-04 迁移中从运行时与测试代码**完全移除**，**MUST NOT** 重新引入。

- **MUST**：全局无状态服务（`DatabaseService`、`ReaderPreferencesService`、`FeatureManager` 等）通过 `get_it` 注册并在 `setupServiceLocator()` 里 `await getIt.allReady()` 后才 `runApp`。
- **MUST NOT**：在 `service_locator.dart` 以外的地方调用 `GetIt.instance<X>()` ——服务必须通过**构造器注入**传给 Manager / ViewModel。UI 层通过 Riverpod provider（`ref.read` / `ref.watch`，装配见 `core/services/riverpod_providers.dart` 与各模块 `*_provider.dart`）获取。
- **MUST**：订阅粒度遵循"**最小订阅原则**"：
  - 事件回调 / 只读一次用 `ref.read(provider)`；
  - 只需单字段变化用 `ref.watch(provider.select((x) => x.field))`；
  - **SHOULD NOT** 在 `build()` 顶层 `ref.watch` 整个 ChangeNotifier / 状态对象，除非整颗子树的确依赖它的任意变化。
- **MUST**：高频变化的单值（progress、brightness、warmth、pagination page index）**MUST** 用 `ValueNotifier<T>` + `ValueListenableBuilder` 暴露，**不得**塞进 `ChangeNotifier.notifyListeners()` 的主干事件流。
- **MUST NOT**：在同一个 `ChangeNotifier` 里混放"结构性状态（章节、错误、能力）"与"高频连续值（progress）"——前者触发整树 select 重算，后者需要局部 listenable。

### 2.4 持久化规范（当前栈：`sqflite` + `shared_preferences` + `flutter_secure_storage`）

- **sqflite**：用于书籍元数据、书签、高亮、阅读位置、统计。
  - **MUST** 所有表变更走 `_onUpgrade` + 增量 `ALTER TABLE`，不得 DROP 用户表。
  - **MUST** 批量写（>3 条）使用 `db.batch()` 或 `db.transaction()`。
  - **MUST** schema 变更递增 `version`，并在 PR 描述中给出**数据迁移说明**与**回滚方案**。
  - **MUST NOT** 使用 `ConflictAlgorithm.replace` 于 `books` 表（会级联删除高亮/书签，历史痛点）。
- **shared_preferences**：用于 UI 配置（字号、主题、亮度、排序偏好）。
  - **MUST** 对"滑块类连续输入"的 setter 使用 `Debouncer(300ms)` 批量落盘，不得每次滑动都 `setDouble`。
  - **MUST NOT** 用它存放**任何**用户创作数据（书签、高亮、笔记）。
- **flutter_secure_storage**：仅用于 PIN 哈希（salt + hash）与 PIN 试错锁定状态。
  - **MUST NOT** 存明文密码；**MUST** salt + hash。
  - **产品定位（2026-07 维护者确认）**：私密书架是**可见性门禁**（PIN/生物识别 + UI 遮挡 + 试错锁定），**不做内容加密**——书源文件与 DB 行保持明文。防"随手翻看"够用，不承诺防取证；任何文档或文案 **MUST NOT** 宣称私密书架加密内容。
- **缓存大小**：封面图缓存 **SHOULD** 控制在 100MB 以内，**MUST** 有 LRU 淘汰策略。

### 2.5 第三方包纪律

- **MUST NOT** 引用任何包的 `package:xxx/src/...` 路径（私有 API）。历史上的 `package:epub_view/src/...` 私有引用已通过 `epub_parse_helpers.dart` + 直接依赖 `html` 移除，**MUST NOT** 重新引入。
- **MUST** 新增依赖时在 PR 里给出：用途、体积影响、可替代方案、最近一次 commit 时间、是否支持 null-safety。

---

## 3. 架构蓝图（Architecture Blueprint）

### 3.1 分层契约

```
┌──────────────────────────────────────────────────────────┐
│  Presentation Layer   (lib/modules/**/widgets, pages)    │
│  —— Widgets、Gesture、select/ValueListenable 订阅         │
├──────────────────────────────────────────────────────────┤
│  Controller Layer     (lib/modules/**/controllers)        │
│  —— ReaderController, Managers, BookshelfViewModel       │
├──────────────────────────────────────────────────────────┤
│  Domain / Engine      (lib/modules/reader/reader_engine) │
│  —— ReaderEngine 抽象 + TXT/EPUB/PDF 实现 + Capability    │
├──────────────────────────────────────────────────────────┤
│  Service / Repository (lib/core/services, utils)          │
│  —— DatabaseService, PreferencesService, BookSourceAccess │
├──────────────────────────────────────────────────────────┤
│  Platform / Infra     (sqflite / path_provider / pdfx…)   │
└──────────────────────────────────────────────────────────┘
```

### 3.2 跨层调用矩阵（MUST）

| 调用方 ↓ / 被调方 → | Presentation | Controller | Engine | Service |
|---|---|---|---|---|
| Presentation | ✅ | ✅ | ❌（仅通过 Controller） | ❌ |
| Controller | ❌ | ✅ | ✅ | ✅ |
| Engine | ❌ | ❌ | ✅ | ✅（仅读文件） |
| Service | ❌ | ❌ | ❌ | ✅ |

**硬约束：**
- **MUST NOT**：Widget 直接调用 `DatabaseService`、`File`、`SharedPreferences`、`sqflite`。这类调用必须通过 Controller/Manager。
- **MUST NOT**：Engine 调用 UI 层或 Controller；Engine 只依赖其 `ReaderEngine` 契约和 `BookSourceAccess`。
- **MUST NOT**：Service 之间交叉调用超过一层；必要时抽 `UseCase` / `Coordinator`。

### 3.3 单一真相源（Single Source of Truth）

项目中以下数据**MUST** 只有一个拥有者：

| 数据 | 唯一拥有者 |
|---|---|
| 阅读位置（ReadingPosition） | `ReaderEngine.getCurrentPosition()` |
| 章节列表（ReaderChapter[]） | `ContentMetaManager._chapters` |
| 当前章节索引 | `ContentMetaManager._currentChapterIndex` |
| 分页结果（total pages） | `TxtReaderEngine._totalPages` |
| 高亮集合 | `ContentMetaManager._highlights` |
| 亮度 / 暖色温 | `BrightnessController` 的各 `ValueNotifier` |
| UI 偏好（字号、行高、主题） | `ReaderPreferencesService` |

**MUST NOT** 在 Widget 或其它 Manager 里冗余缓存上述数据。如需展示，**MUST** 通过 listenable 订阅。

### 3.4 性能硬性要求

> 完整的验证矩阵、性能预算与 CI 配方见 [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md)。

- **MUST**：任何文件读取 / 解析 **MUST** 在 `compute()` 或 `Isolate.run()` 中进行，包括：TXT 解码、EPUB 解压与章节解析、PDF 首次打开、数据库自愈、备份压缩与清理、JSON 大对象解析。
- **MUST**：任何基于 `TextPainter.layout()` 的分页估算 **MUST** 做到：
  1. 不在同步 `build()` 中完成；
  2. 按"**布局键（viewportSize + fontSize + lineHeight + padding + orientation）**"去重；
  3. 异步结果回到主 Isolate 前必须校验布局键未失效。
- **MUST NOT**：在 `build()` 中执行 `.toList()` / `.sort()` / 正则匹配 / 文件读取 / DB 查询 / `RegExp` 构造。
- **MUST**：列表型组件（书架、目录、书签、高亮）使用 `ListView.builder` / `SliverList.builder`；**SHOULD** 为 item 根节点包 `RepaintBoundary`；**SHOULD** 为等高项提供 `itemExtent`。
- **MUST NOT**：使用 `Opacity(opacity: v != 0 && v != 1)` 做动画；**MUST** 用 `FadeTransition` / `AnimatedOpacity`，并避开 `Positioned.fill` 包裹的全屏 opacity（会触发 saveLayer）。

### 3.5 受保护面（Protected Surfaces）

下列修改**MUST** 先在对话中提交《影响 / 风险 / 验证分析》三段式，并获用户明确同意后才能动工：

1. TXT / EPUB / PDF 分页与定位算法；
2. 阅读进度持久化与恢复流程；
3. SQLite schema 与迁移脚本；
4. `ReaderEngine` / `ReadingPosition` / `ChapterLocator` 公共契约；
5. 书籍导入指纹（`BookImportFingerprint`）去重规则；
6. 数据库自愈与冷备份恢复路径。

### 3.6 Reader 安全不变式（MUST 永远成立）

- 同一本书 + 同一套设置 **MUST** 产生确定性（deterministic）分页；
- 冷启动后的 "继续阅读" **MUST** 恢复到退出时的段落/页码；
- 章节导航 **MUST** 与底部进度条一致（不得出现 TOC 高亮章节 ≠ 当前章节）；
- Widget `build()` 中 **MUST NOT** 引入任何基于 `DateTime.now()` 的逻辑；
- 分页、位置计算 **MUST NOT** 使用随机数或时间戳。

---

## 4. UI / UX 审美守则（Design Philosophy）

### 4.1 气质基调

**"无印良品 × 纸本阅读 × 克制的抹茶"**。三条宪法：

1. **禁止纯白（`#FFFFFF`）与纯黑（`#000000`）**。所有"白"是奶白（`creamSurface` / `creamBackground`），所有"黑"是深墨（`inkNightBackground` 或深棕 `creamTextMain`）。
2. **强色只用抹茶绿**（`creamPrimary` / `creamPrimaryDeep`）。温度与亮度语义才允许使用陶土橘（`highlightOrange`）。
3. **层次首选"圆角 + 背景色阶 + 暖色调分隔线"**；阴影只允许走 `NyanShadows.*` token。**严禁**自己构造 `BoxShadow`。

### 4.2 设计 Token 真相表（MUST 引用这些常量，不得新造色值）

#### 4.2.1 颜色 — `lib/core/theme/nyan_colors.dart`

**主题敏感色（MUST 通过 `NyanTheme` 扩展访问）：**

> **Sumi Dark 已按设计系统交付包（2026-06）重做为 v6 MONO（中性灰表面 + 单色 off-white 强调）**：
> 暗色**不再**建立在抹茶/橄榄家族上——抹茶是 **Cream Light 专属**品牌色。暗色里**没有任何彩色品牌强调**：
> - **表面是真中性灰阶梯**（零棕零绿），用"色调"承载层级，表面随升起逐级**变亮**（`bg < surfaceMuted < surface < surfaceRaised < overlayField`，相邻 ~1.5:1）；无纯黑/纯白。
> - **强调是单色 off-white**：主按钮是 off-white **实底 + 深墨标签**（与亮色的 cream-on-matcha 互为反相），其余"强调"元素（链接、选中描边、进度、图标）就是 light-on-dark。层次靠 fill / outline / weight，不靠 hue。
> - **浮层规则**：浮动面（dock/bar/menu/dialog/sheet）必须**明确高于其身后的面**——包括 Sumi 阅读画布 `#242424`（比平面卡片 `surface` 还亮）——故走 `surfaceRaised`，**MUST NOT** 用 `surface`；浮层**内部**嵌套的输入框/托盘/内层卡走 `overlayField`（更亮），不得沉进近黑洞。
> - 暗色唯一保留的彩色是**暖陶土错误红**（仅 danger）。

| 语义 | creamLight 值 | sumiDark v6 值 | `NyanTheme` 字段 |
|---|---|---|---|
| 页面主背景（纸色 / 暗色页底） | `#F6F3EA` | `#121212` | `background` |
| 卡片/面板表面（平面卡片/栏） | `#FFFDF8` | `#1E1E1E` | `surface` |
| 嵌入式凹陷表面（Tab 槽、Slider 轨道） | `#F1ECDD` | `#181818` | `surfaceMuted` |
| 浮动层（对话框 / Sheet / 弹出层 / dock / 浮动栏；亮色复用 surface） | `#FFFDF8` | `#303030` | `surfaceRaised` |
| 浮层内嵌字段/托盘/内层卡（Knob 等；亮色复用 surfaceMuted） | `#F1ECDD` | `#3A3A3A` | `inkNightOverlayField` |
| 正文文字 | `#3F3A34` | `#ECECEC` | `textPrimary` |
| 次级文字（说明 / 副标题） | `#5F5950` | `#ABABAB` | `textSecondary` |
| 三级文字（占位 / 单位） | `#6B6559` | `#8A8A8A` | `textMuted` |
| 主强色（按钮文字/图标/进度/tint） | `#6E7A55` | `#E2E2E2` | `primary` |
| 深强色（链接 / 选中描边 / FAB 底） | `#5A6644` | `#F4F4F4` | `primaryDeep` / `accent` |
| 实底按钮背景（亮色复用 primaryDeep） | `#5A6644` | `#ECECEC` | `primaryButtonBackground`（暗=`inkNightPrimaryFill`） |
| 实底按钮文字/图标（亮色 cream，暗色深墨） | `#FFFDF8` | `#1A1A1A` | `onPrimary`（暗=`inkNightOnPrimary`） |
| 分隔线（亮色暖调；暗色中性） | `#E5DED2` | `#333333` | `divider` |
| 卡片硬描边（暗色发光环用） | `#E5DED2` | `#474747` | `borderColor` |

**错误色（暖陶土，非临床红；暗色为唯一保留彩色，仅 danger）**——错误状态要读起来"平静、在地"而非"刺眼的 Material 红"：
creamLight `errorBackground #FBF2EC` / `errorPrimary #9C5C49` / `errorSecondary #8A6A55` / `errorAccent #ECD9CC`；
sumiDark v6 `#3A2420` / `#E59B85` / `#D29A83` / `#573730`（bg/accent 提亮以让 danger tile 浮离 `#121212` 页底）。
**破坏性按钮实底**：`errorFill`（亮色复用 `errorPrimary`，暗色 `#C24A38`）+ `onError = #FBF3E6`（两套主题均为 cream/近白）。

**U8 错误页用色**（来源 `bundle2-screens.jsx` `ErrorView`）：页面背景用 `nyan.background`（**MUST NOT** 用 `errorBackground`，该 token 保留备用）；图标容器底 `Color.lerp(nyan.surface, errorPrimary, 0.08)` + `errorPrimary@22%` 0.7px 描边；Retry 走 `NyanPrimaryButton(variant: primary)` 抹茶绿（**MUST NOT** 用 `errorAccent`）；Report 走 `NyanIcons.bugBeetle` + `nyan.textMuted`。

**原子常量（只在 `nyan_colors.dart` 与 `theme_presets.dart` 内部使用，业务代码 MUST NOT 直接引用；唯一豁免见 §4.2.6 注册表 PIN 遮罩行）：**

- cream 系列：`creamBackground / creamSurface / creamSurfaceMuted / creamPrimary / creamPrimaryDeep / creamTextMain / creamTextSecondary / creamTextMuted / creamDivider`
- ink 系列：`inkNightBackground / inkNightSurface / inkNightSurfaceMuted / inkNightSurfaceRaised / inkNightOverlayField / inkNightPrimary / inkNightTextMain / inkNightTextSecondary / inkNightTextMuted / inkNightDivider`
- ink 深阶：`inkNightPrimaryDeep`（dark preset 的 accent/深强调）、`inkNightBorder`（v6 阶梯的卡片硬描边/发光环）
- ink v6 Mono 强调：`inkNightPrimaryFill`（off-white 实底按钮背景）、`inkNightOnPrimary`（实底上的深墨标签 `#1A1A1A`）、`inkNightSelectFill`（选中对勾 + 封面环）；错误实底 `errorFillDark` + `onErrorFill`（cream，两套主题通用）

**语义色（固定值，不随主题切换，可直接引用）：**

| 用途 | 常量 | 值 |
|---|---|---|
| 高亮笔 · 黄 | `NyanColors.highlightYellow` | `#F2E58A` |
| 高亮笔 · 绿 | `NyanColors.highlightGreen` | `#A8D18D` |
| 高亮笔 · 蓝 | `NyanColors.highlightBlue` | `#9EC5E8` |
| 高亮笔 · 粉 | `NyanColors.highlightPink` | `#E8A0BF` |
| 高亮笔 · 橙 / 暖色温语义 / 警告 | `NyanColors.highlightOrange` | `#F2BE7E` |

**特殊状态色**（只在 `NyanTheme` 内定义）：`successColor` / `warningColor` / `infoColor` / 4 个 `errorXxx` / 2 个 `fabXxx`，业务代码通过 `Theme.of(context).extension<NyanTheme>()!.successColor` 等访问。

#### 4.2.2 圆角 — `lib/core/theme/nyan_radius.dart`

**One Paper 同心圆角家族（2026-06 设计系统对齐）**，由内向外随高度递增：

| 常量 | 值 | 用途 |
|---|---|---|
| `NyanRadius.chip` | `12` | **选项 chip / Pill 按钮**（嵌套最深）、stepper caret |
| `NyanRadius.control`（旧名 `small`） | `14` | 分段控件外轨、列表行图标 chip |
| `NyanRadius.cardNested`（旧名 `input`） | `16` | Sheet 内嵌卡、输入框、FAB、按钮 |
| `NyanRadius.card` | `20` | 顶层卡片、书架 item |
| `NyanRadius.dock`（旧名 `panel`） | `24` | 静止 dock / 浮动栏、对话框 |
| `NyanRadius.sheet` | `28` | dock 长成的 Sheet、所有底部 Sheet |

> `small / input / panel` 保留为 `control / cardNested / dock` 的 `const` 别名（向后兼容），新代码 SHOULD 用语义名。
> 同心内嵌可比外圈小 3pt（如 14 轨内放 11 指示器）——这是刻意的非阶梯值，不是越界。

Pill 按钮 / 分段控件指示器**不再是 stadium 胶囊**：选项 chip **MUST** 用 `RoundedRectangleBorder(NyanRadius.chip)`（12pt 方圆角），选中态仅靠"去填充 + `primaryDeep` 描边/文字"区分（见 §4.3）。

#### 4.2.3 间距 — `lib/core/theme/nyan_spacing.dart`

`NyanSpacing.space4 / 8 / 12 / 16 / 20 / 24 / 32`（全部 double 常量），以及 `NyanSpacing.minTapTarget = 44`（所有可点击元素最小命中区域）。

**MUST NOT**：使用 `10`、`14`、`18`、`22` 等非 8 的倍数（`4 / 12 / 20` 是唯一例外，已在常量表中）。控件/组件内部微距的已批准偏差见 §4.2.6 注册表。

#### 4.2.4 阴影 — `lib/core/theme/nyan_shadows.dart`

工具方法接收 `NyanTheme nyan`（不是裸 `Color`），按 `nyan.brightness` 自动选配方：

- `NyanShadows.lightCard(nyan)` — 浮动 chrome（卡片、顶栏、dock、Sheet、对话框、弹出层）。
- `NyanShadows.subtle(nyan)` — 次级浮层（Toast、轻浮动通知）。
- `NyanShadows.settingsGrouped(nyan)` — 设置分组卡片（`NyanRowGroup`）。
- `NyanShadows.shelfPinnedHeader(nyan)` — 书架吸顶标签栏向下投影，**仅在 `overlapsContent == true` 时启用**。来源 `bundle4.jsx` `box-shadow: 0 6px 14px -8px rgba(40,36,30,.22)`；暗色用 `Colors.black@32%`（暖墨色在深色背景下不可见）。
- `NyanShadows.cardSelectionGlow(nyan)` / `selectionBadgeGlow(nyan)` — 选中书格封面外发光（`primary@16%` spread 3px）与 SelectCheck 徽标发光（`primary@40%` 1px drop shadow）。来源 `bundle3.jsx` `SelectBookCard`。

配方基调：
- **Cream Light**：暖墨 drop shadow（lightCard 4%/2%@12/6px；subtle 5%@8px；grouped 1.4%@10px），墨色取自 `nyan.textPrimary`。
- **Sumi Dark（v6 MONO 中性灰阶梯）**：**"暗色无阴影"旧规已废止**。暗色用 **`0.75px` 中性描边环**（`nyan.border` / `nyan.divider` spread）+ 柔和黑色 ambient 承载层级。CSS 原型还含 `inset 0 1px 0 white@5%` 顶部 catch-light；Flutter `BoxShadow` 无 inset，需要的浮层（对话框/Sheet）在自身 decoration 上加 `Border(top: white@5%)` 补上（见 `NyanBottomSheet` / 亮度弹层）。

**MUST NOT** 自造 `BoxShadow`；需要新阴影先在 token 内定义。**MUST NOT** 写 `dark ? const [] : ...` 给暗色卡片退订阴影——描边环已承载平面分离。

#### 4.2.5 字体与字号 — `lib/core/theme/nyan_typography.dart`

- UI 字体族：`NyanTypography.uiFontFamily` = **`Noto Sans SC`**；阅读正文可选 serif：`NyanTypography.readingSerifFontFamily` = `Source Han Serif SC`。
- 字体注册：`pubspec.yaml` 已声明 `Noto Sans SC`（400/500/600）+ `Source Han Serif SC`（400/600）；字体文件**未入 Git**（体积原因），按 `assets/fonts/README.md` 手动放置。缺字体时 Flutter 回落平台字体、只打 warning；serif 阅读模式需字体就位后生效。
- 字号阶梯（**仅允许**以下 6 档）：`display 32` / `title 24` / `section 20` / `body 16` / `meta 13` / `caption 11`。其中 **`caption 11` 仅用于橄榄色 eyebrow 小标题**（`NyanTypography.eyebrowStyle(nyan.primaryDeep)`，w500 + 0.22 字距 + 大写），**MUST NOT** 用于正文、列表行或其它表面。
- **字重仅允许**：`FontWeight.w400`（Regular，正文）/ `FontWeight.w500`（Medium，按钮/标签）/ `FontWeight.w600`（SemiBold，标题/数值）。**MUST NOT** 使用 `w100–w300` 或 `w700–w900`（唯一 w300 豁免见 §4.2.6 注册表 Rest Reminder 行）。
- 阶梯外字号的已批准例外全部登记在 §4.2.6 注册表。

#### 4.2.6 交付包例外注册表（Delivery-Pack Exception Registry）

设计系统交付包（§4.6）明确规定、但落在上述 token 规则之外的值，**全部**登记于此表。使用纪律：

- 每条例外**仅限**"唯一适用处"一栏登记的位置，**MUST NOT** 扩散至正文、列表行或任何其它表面；
- 新例外必须有交付包出处（§4.6 交付包优先），**先登记进本表再使用**；
- 有常量名的走 `NyanTypography.*` / 组件私有 `_k*` 常量，**MUST NOT** 把裸字面量复制到别处。

**字号 / 字重（阶梯外）：**

| 常量 / 值 | 规格 | 唯一适用处 | 来源 |
|---|---|---|---|
| `buttonCompact 14` / `body 16` / `buttonComfortable 17` | 按 size 变体 | `NyanPrimaryButton` label | `components.jsx` |
| `15 w600`（字面量） | knob 标签 | `ReaderSettingsKnob` 标签 | `reader.jsx` `Knob` |
| `18 w600`，ls -0.1 | sheet 标题 | `NyanOnePaperSheet` 顶层标题（如 "Import Books"） | `bundle3.jsx` `ImportSheet` |
| `15 w500` | 节标题 | `ImportBookSheet` "Supported Formats" 节 | `bundle3.jsx` `ImportSheet` |
| `shelfFormatChip 9` w600 | 格式徽标 | 书架列表行 TXT/EPUB/PDF 徽标 | `bundle3.jsx` `BookListRow` |
| `shelfProgressLabel 11` mono | 进度百分比 | 书架列表行尾部（`NyanTypography.monoFontFamily`） | `bundle3.jsx` `BookListRow` |
| `pinKeyDigit 27` w500 / `pinKeyGlyph 24` | 键盘数字 / 退格图标 | `PinInputWidget` 键盘 | `bundle4.jsx` `NumPad` |
| `18 w600` / `14 w400`（字面量） | 标题 / 正文 | `ReaderErrorView`（U8） | `bundle2-screens.jsx` `ErrorView` |
| `18 w600` / `14` / `13`（字面量） | 标题 / 说明 / 提示 | `NotesListPage` 空状态 | `bundle3.jsx` `NotesList` |
| `fabLabel 13.5` w600 | FAB 标签 | `_JumpToCurrentButton`（`chapter_list_widget.dart`） | `bundle1.jsx` `ChapterDockSheet` |
| `shelfSortFieldLabel 15` | 选中 w600 `primaryDeep` / 未选 w500 `textPrimary` | `_SortFieldRow` 主标签（`bookshelf_sort_sheet.dart`） | `bundle3.jsx` `ShelfSortSheet` |
| `shelfSortFieldSub 12.5` w400 `textSecondary` | 字段行子标签 | `_SortFieldRow` 子标签 | `bundle3.jsx` `ShelfSortSheet` |
| `adminRowLabel 15` | w600/w500 | `_AdminSwitchRow` / `_AdminFlagRow` 主标签（`admin_panel.dart`） | `bundle4.jsx` `AdminPanel` |
| `adminBadgeLabel 12` w500 | 徽标芯片 | `_AdminFlagRow` 内 `FlagBadge` | `bundle4.jsx` `FlagBadge` |
| `adminHintTitle 14` w600 | 提示卡标题 | `_AdminHintRow` 标题 | `bundle4.jsx` hint card |
| `responseTitle 14` w600 lh1.25 | toast 标题 | `NyanResponse` 标题行 | `NyanResponse.jsx` |
| `responseDescription 12.5` w400 lh1.35 | toast 描述 | `NyanResponse` 描述行 | `NyanResponse.jsx` |
| `selectionHeaderTitle 18` w600 ls-0.2 | 选择模式标题 | `_buildSelectionAppBar`（`home_screen.dart`，U21） | `bundle3.jsx` `SelectionHeader` |
| `deleteConfirmTitle 19` w600 ls-0.2 | 删除确认标题 | `_DeleteBooksSheetContent` 标题（U21） | `bundle3.jsx` `DeleteConfirmSheet` |
| `13.5 w400`（字面量） | 删除确认正文 | `_DeleteBooksSheetContent` 说明行（U21） | `bundle3.jsx` `DeleteConfirmSheet` |
| `discoverBlockTitle 14.5` w600 | 标题 + 按钮标签 | Discover block 标题 & Pro nudge "Upgrade to Pro" 按钮（U22） | `U22.html` |
| `sponsoredBadge 9.5` w600 ls0.5 | 大写徽标 | Discover block "SPONSORED" 行（U22） | `U22.html` |
| `miniSuggestTitle 11.5` w600 / `miniSuggestAuthor 10.5` w400 | 书格标题 / 作者 | `_MiniSuggestTile`（U22） | `U22.html` |
| `restReminderTimer 46` **w300** | 倒计时数字；**全库唯一 w300 例外**（轻字重=平静感） | `RestReminderOverlay` 倒计时（U23） | `U23.html` `RestCountdown` |
| `restReminderTitle 21` w600 | 覆层标题 | `RestReminderOverlay` "Rest your eyes"（U23） | `U23.html` |

**间距（非 8pt 网格）：**

| 值 | 唯一适用处 | 来源 |
|---|---|---|
| `6pt` icon↔label 间隙 | `NyanPrimaryButton` 等控件**内部** icon-label 配对 | `components.jsx` |
| `14pt`（`_kBadgeTitleGap`） | `ChapterListItem` 数字徽标↔标题 | `reader.jsx` `ReaderChapterList` |
| `14pt` padding | `ReaderSettingsKnob` 容器内边距 | `reader.jsx` `Knob` |
| `14pt`（`_kCardPaddingH`） | `NyanHighlightCard` 水平内边距 | `bundle3.jsx` `HighlightCard` |
| `10pt`（`_kCardPaddingV`）+ `2pt`（`_kTitleDescGap`） | `NyanResponse` 垂直内边距 / 标题↔描述间隙 | `NyanResponse.jsx` |
| `10pt`（`_kShelfTrackVerticalPaddingBottom`） | 书架吸顶标签栏底部内边距 | `bundle4.jsx` `ShelfToolbarScreen` |
| `10pt` 行垂直内边距 | `AnimatedBookCardList` 列表行 | `bundle3.jsx` `BookListRow` |

**颜色 / 形状 / 图标 / 渐变：**

| 例外 | 规格 | 唯一适用处 | 来源 |
|---|---|---|---|
| PIN 遮罩深色墨（直引原子色的**唯一**豁免） | `NyanColors.pinOverlayInkBackground #1D211E` / `pinOverlayInk #E8E1D5`；亮色变体仍走 `NyanTheme` token | `PinOverlayPage` / `PinInputWidget`（U16） | `bundle4.jsx` `PinOverlay` |
| `StadiumBorder`（radius 999） | 全屏深色遮罩上的独立 CTA，与分段 chip 语义不同 | `RestReminderOverlay` "Continue reading" 按钮（U23） | `U23.html` |
| 渐变 | ①亮度弹层玻璃拟态模糊；②`NyanShelfProNudge` 渐变背景 + 叶片 + Upgrade 按钮（U22） | 仅此两处 | `U22.html` `ProNudge` |
| 填充图标 | `compassFilled / leafFilled / sparkleFilled / checkCircleFilled` | `NyanShelfDiscoverBlock` / `NyanShelfProNudge`（U22） | `U22.html` |
| 顶层书架切换器（`SegmentedTabStyle.shelf`） | 指示器 `surface` 实心 + `settingsGrouped`；选中 `textPrimary` w600、未选 `textMuted` w500；内边距 3pt——页面级导航语义，**MUST NOT** "修正"回 `primaryDeep` | 书架 Public / Private 切换器 | `BookshelfScreen.jsx` / `bundle3.jsx` |
| 选择模式 open-detail 快捷按钮 | 书格：24×24 圆形 ↗（`arrowUpRight`，`primaryDeep`，`surface@90%` 毛玻璃 + `divider@50%` 描边 + `0 1px 3px black@12%`）；列表行：32×32 圆形 ›（`caretRight`，`textSecondary`，`surfaceMuted` + `divider@44%` 描边）；点击导航详情页、**不改变选中状态** | 书架选择模式（U21） | `bundle3.jsx` `SelectBookCard` / `SelectBookListRow` |

### 4.3 组件样式底线（MUST）

- **Bottom Sheet / 对话框 / 弹出层**：圆角 `NyanRadius.sheet`（28pt）/`dock`（24pt），顶部 12pt 留白内含抓手（`--grabber` = `primary` 36%亮/50%暗）；底色取 `surfaceRaised`（亮色等于 surface，暗色为 v6 阶梯最高层）；阴影走 `NyanShadows.lightCard(nyan)`（暗色自带描边环）。
- **Tab / Segmented Control**：外层轨道 `NyanRadius.control`（14pt）+ 4pt 内边距 + `surfaceMuted` 底（**仅靠色调凹陷，无描边**）；内部滑动指示器同心内嵌 11pt（=14−3）；emphasis 指示器 = `surface` 实心 + `NyanShadows.settingsGrouped`，subtle 指示器 = `primary @ 16%` tint；选中文字 = `primaryDeep`，未选 = `textSecondary`；**禁止**下划线；动画固定 **280ms ease-paper**（`cubic-bezier(0.33,0.9,0.36,1)`，来源 `components/primitives.jsx`）。此规则适用于**面板内 / sheet 内的调节型分段控件**；顶层书架切换器例外见 §4.2.6 注册表。
- **Pill 按钮 / 选项 chip（低/中/高、紧凑/标准/舒展、Sans/Serif 等）**：**方圆角 `NyanRadius.chip`（12pt），不是 `StadiumBorder`**；未选 = `surfaceMuted` 底 + 透明描边 + `textSecondary` 文字；选中 = **去填充（透明底）+ `primaryDeep` 1.5px 描边 + `primaryDeep` 文字**——chip "浮离轨道"。这是本项目的招牌交互（outline-on-select），和 Material 填充 chip 截然不同。
- **Reader chrome（One Paper）**：阅读器底部**只有一块浮动纸面板**——collapsed 时是 `dock`（`OnePaperDock`，inset 12pt / `r-dock` 24），点 Chapters/Settings **原地长成 sheet**（`r-sheet` 28，`AnimatedAlign` 高度展开，`dur-grow` 320ms ease-paper），footer（章节 stepper `‹ ›` + 细进度条 + **4 个动作 Chapters/Bookmarks/Highlights/Settings**）始终钉在底部。**亮度不在 dock**：走顶栏太阳弹层（`ReaderBrightnessPopover`，玻璃拟态）+ 左缘竖向拖拽。Sheet 升起时页面 scrim + 2px 模糊（仅展开时挂载）。Bookmarks 和 Highlights 都是 push 页面，不是 sheet（"adjust→sheet；browse→page"）。**MUST NOT** 回退到边到边贴底控制条或把 Settings/Chapters 改成独立 modal sheet。
- **Action Response（全局反馈 toast，`NyanResponse`，来源 `components/surfaces/NyanResponse.jsx`）**：全 App **唯一**的"刚刚发生了什么"反馈面（导入完成 / 删除 / 跳过 / 进行中）。**左对齐卡片**而非居中胶囊——圆角 `NyanRadius.cardNested`（16pt）+ `surface` 底 + `NyanShadows.subtle(nyan)` + `--chrome-edge` 描边（亮色透明、暗色 `divider` 环）；浮动 chrome 距屏幕边缘 `NyanSpacing.space12`（左右 12pt，宽屏 maxWidth 480pt 居中，手机满宽）；卡内：左侧 36×36 状态色块（`NyanRadius.chip` 12pt + 状态 tint 底 + 20pt 图标）→ `space12` 间隙 → 标题（`responseTitle`）+ 可选描述（`responseDescription`，`textSecondary`）。**5 个状态**：`success`（`checkCircle` + `successColor` + success 13% tile）/ `error`（`warningCircle` + `errorPrimaryTextColor` + `errorBackground` tile）/ `skipped`（`skipForward` + `textMuted` + `surfaceMuted` tile）/ `info`（`info` + `infoColor` + info 13% tile）/ `loading`（`circleNotch` 旋转 + `primary` + primary 12% tile）。**MUST NOT** 回退到居中胶囊（`StadiumBorder` / radius 999）或自造 `BoxShadow`。自动消失的 toast **省略** ✕（`onDismiss` 留空，DS 契约）；`NyanResponse` 仍支持 `onDismiss` 以备常驻场景。
- **Slider**：轨道高 3–4pt 用 `surfaceMuted`，已填充段用 `primaryDeep`（亮度）或 `highlightOrange`（暖色温），thumb 10–12pt 实心同色，**无光晕、无阴影、无放大**。
- **Card**：圆角 `NyanRadius.card`（20pt），`surface` 底，`divider` 描边；**默认无阴影**；仅在书架 hover / 次级浮层必要时使用 `NyanShadows.subtle`。
- **书架列表视图（list view，来源 `bundle3.jsx` `BookListRow`）**：**单块分组面板**而非逐项独立卡片——外层 `surface` 底 + `NyanRadius.cardNested`（16pt）+ `NyanShadows.settingsGrouped` + `--chrome-edge` 描边（亮色透明、暗色 `divider` 环），各行**无自身边框/阴影**，行间用 0.5px `divider@34%` 发丝线（左右内缩 12pt）分隔。行内：左侧 44×58 竖向封面（`NyanRadius.chip`），标题 14pt w600 单行 + 作者独占一行（`textMuted`）+ 进度行（仅 `progress>0` 时显示：满宽 3pt 轨 + 11pt mono 百分比），尾部格式徽标 + `chevronRight`。为不破坏懒加载（§3.4），分组外观由 `DecoratedSliver` 承载、内部仍是 `SliverList.builder`。选中态走整行 `primaryDeep` 淡色填充（`context.selectionSurface`），不加逐行描边。**MUST NOT** 回退到逐项独立卡片 + 卡间留白的旧实现。
- **Icon**：线性 1.5pt 感——图标系统为 **Phosphor Regular**，所有图标 **MUST** 来自 `lib/core/ui/nyan_icons.dart`（`NyanIcons.*`），**MUST NOT** 直接用 `Icons.*`。填充权重仅保留给"已设书签"与主题卡选中对勾，及 §4.2.6 注册表登记的 U22 例外。
- **Haptics**：滑块拖动最多一次 `HapticFeedback.lightImpact`；翻页 **MUST NOT** 触发触感反馈。
- **Tap target**：所有可点击元素最小 44×44pt（`NyanSpacing.minTapTarget`）。

### 4.4 设计反模式（MUST NOT）

- ❌ Material3 `FilledButton` / `ElevatedButton` 默认阴影（项目已在 `NyanTheme.themeData` 里把 `elevation: 0`，不要去改回来）；
- ❌ `CircularProgressIndicator` 的默认蓝色（必须显式指定 `valueColor: AlwaysStoppedAnimation(nyan.primary)`）；
- ❌ 自造 `BoxShadow`（必须走 `NyanShadows.*` 工具；亮色 ≤12px blur，暗色 v6 阶梯的 ambient 可达 24px 但仅限 token 内部）；
- ❌ 给暗色卡片写 `dark ? const [] : ...` 退订阴影（v6 描边环已承载平面分离）；
- ❌ Pill / 选项 chip 用 `StadiumBorder`（已废止，改用 `NyanRadius.chip` 12pt 方圆角 + outline-on-select；唯一例外见 §4.2.6 注册表）；
- ❌ 高饱和色（iOS 蓝、Material 紫、霓虹任何色）；
- ❌ 大面积线性/径向渐变（已批准例外见 §4.2.6 注册表）；
- ❌ `Icons.xxx_filled` 填充图标（对勾徽标与 §4.2.6 注册表登记项除外）；
- ❌ 卡片之间加 `Divider`（层次用 `surfaceMuted` 背景色差代替）；
- ❌ 字重越界（仅允许 `w400 / w500 / w600`，`w700+` 一律 reject；唯一 w300 豁免见 §4.2.6 注册表）；
- ❌ 自制字体族，任何 `TextStyle(fontFamily: '...')` 的 `fontFamily` 必须来自 `NyanTypography`；
- ❌ 直接引用 `NyanColors.creamXxx / inkNightXxx` 原子常量到业务 Widget 里（必须走 `NyanTheme` 扩展；唯一豁免见 §4.2.6 注册表）。

### 4.5 AI 写 UI 的自检清单

生成 UI 代码前，自问并在对话中默认回答：

1. **Token**：颜色是否走 `Theme.of(context).extension<NyanTheme>()`？间距/圆角/字体/阴影是否都来自 `nyan_*.dart`？阶梯外的值是否已在 §4.2.6 注册表登记？
2. **订阅粒度**：这颗子树真正会变的字段是哪一个？我是不是用了最小的 `select` / `ValueListenableBuilder`？
3. **const**：能加 `const` 的地方都加了吗？
4. **RepaintBoundary**：这是不是一条高频重绘的长列表 / 叠加层？
5. **build 纯度**：`build()` 里有没有 `.sort()` / `.toList()` / `RegExp` / I/O？
6. **Opacity**：我有没有误用 `Opacity` 做动画？
7. **字重/字体族**：`FontWeight` 是否只在 `w400 / w500 / w600` 三档？`fontFamily` 是否来自 `NyanTypography`？

**回答全部满足才提交代码。**

### 4.6 品牌资产（Brand Assets）

设计系统交付包（`nyan-read-design-system-handoff.zip`，2026-05 版本）是本项目 UI 的最高优先级视觉参考。所有品牌 SVG 标志已存放于 `assets/brand/`，并在 `pubspec.yaml` 的 `flutter.assets` 中以目录形式注册。

| 文件 | 用途 |
|---|---|
| `assets/brand/logo-peek.svg` | 猫咪探头版（彩色），用于 About / 欢迎页 |
| `assets/brand/logo-peek-mono.svg` | 猫咪探头版（单色），用于深色背景叠加 |
| `assets/brand/logo-line.svg` | 线稿横排版，用于 Splash / 宣传素材 |
| `assets/brand/logo-line-compact.svg` | 线稿横排紧凑版，用于小尺寸场合 |
| `assets/brand/logo-curl.svg` | 猫爪卷角版，用于空状态装饰 |
| `assets/brand/logo-hana-sticker.svg` | 花朵贴纸版，用于节日 / 限定场景 |

**MUST NOT**：在上述 6 个 SVG 以外自行绘制或引入其他插画 / 贡献图；Nyan 猫 logo 是**全项目唯一允许的自定义插画**。

**MUST**：在 Widget 中引用品牌图时使用 `flutter_svg` 的 `SvgPicture.asset('assets/brand/...')` 或等效方式，不得将 SVG 手动内联为 `CustomPainter`。

> **交付包优先原则**：交付包含完整 HTML/CSS 原型（`ui_kits/nyan_read_app/index.html`）、CSS token（`colors_and_type.css`）、JSX 组件库（`components.jsx`）及各屏幕 JSX。当 UI 规范与本文件冲突时，**交付包优先**——交付包直接来自维护者的设计意图，本文件是其文字摘要，摘要落后于源文件。发现冲突时同 PR 更新本文件（含 §4.2.6 注册表）。

---

## 5. AI 协作协议（Interaction Protocol）

### 5.1 修改代码前的必经步骤

对于**任何**代码改动，AI **MUST** 按顺序执行：

1. **Read before write**：读相关源文件（含调用方 / 被调方），**不得**仅凭文件名猜测逻辑。
2. **Trace state ownership**：明确变更涉及的"单一真相源"（§3.3）是否移动或复制。
3. **Plan → Confirm → Code**：
   - **Plan**：用自然语言写出方案，列出：影响文件、影响行为、风险、回滚方式。
   - **Confirm**：等用户明确同意（"ok" / "继续" / "go"）。
   - **Code**：开始编辑。
4. **受保护面（§3.5）** 必须在 Plan 中显式触发《影响 / 风险 / 验证》三段式。

**例外**：用户明确说"直接写 / just do it / 不用解释"时，可跳过 Confirm 步骤，但仍需先输出一段不超过 3 行的 Plan。

### 5.2 注释规范

注释的唯一目的是**回答"为什么这样做"，不是"做了什么"**。

- **MUST** 对"历史踩坑点"、"反直觉决策"、"与其它模块的隐性契约"加注释（语气参考 `reader_page.dart` 中 `attachBrightnessController` 现有注释）。
- **MUST NOT** 写"自述型"注释，如：
  ```dart
  // Increment counter
  counter++;
  // Return result
  return result;
  ```
- **MUST NOT** 在代码里留 "TODO / FIXME / XXX" 没有 issue 编号。必须写成：
  ```dart
  // TODO(#142): switch to PageMetricsCapability once EPUB exposes real page numbers.
  ```
- **SHOULD**：顶层 / 公共类 / 公共方法使用 `///` Dartdoc，私有辅助使用 `//`。
- **SHOULD**：每当写"魔法数字"或"奇怪的常量"时，必须有一句注释解释取值依据（参考 `txt_reader.dart` 中 `_kPaginationSampleSize = 4000` 的写法）。

### 5.3 AI 回答的结构

与用户对话时：

- **MUST**：先给结论，再给论据（不要倒叙、不要"让我一步步分析……"）。
- **MUST**：代码引用使用 `` `file.dart:行号` `` 格式精准定位。
- **SHOULD NOT**：使用表情符号，除非用户先用了。
- **SHOULD**：多语言混写时以用户最后一条消息的主语言为准。
- **MUST NOT**：编造 API 或行号。不确定时显式说"我需要看一下 `xxx.dart`"并去读。

### 5.4 测试与 PR 纪律

- **MUST**：修改 `reader_engine/**`、`controllers/**`、`services/database_service.dart` 时附带或更新 `test/` 下的对应单测。
- **MUST**：不得为让测试通过而弱化断言（"do not weaken tests to hide bugs"）。
- **MUST**：提交信息 (commit message) 使用 Conventional Commits（`feat:` / `fix:` / `refactor:` / `perf:` / `docs:` / `test:` / `chore:`），主题 ≤ 50 字符，body 解释"为什么"。

---

## 6. 架构进展路线图（Roadmap）

### 已完成阶段归档（2026-04-20 ~ 2026-04-24）

Phase 0–4 已全部完成并验收。各阶段沉淀出的硬规则**均已并入上文规范正文**（§2–§4），此表仅作历史索引；实现细节与验收记录见对应 git 提交。

| 阶段 | 主题 | 关键产出（现为现行规范/现状） |
|---|---|---|
| Phase 0（2026-04-20） | 设计系统真相归一化 | 字体注册（`assets/fonts/README.md`）；`lib/modules/**` 字面色清零；`withOpacity → withValues` 全仓替换；SDK deprecation 清零；移除 `google_fonts` |
| Phase 1（2026-04-21） | 扑灭渲染热点 | progress 拆 `ValueNotifier`（心跳不再全局 notify）；`highlightable_text` recognizer 池化 + TextSpan 缓存；overlay 收起态短路 0 rebuild |
| Phase 2（2026-04-21） | 解析离 UI + I/O 批量化 | EPUB 解析入 `compute()`（弃 `epub_view/src` 私有 API）；PDF 异步打开 + placeholder；DB 自愈/备份清理入 `Isolate.run`；prefs 300ms 去抖 + 退出 flush；备份恢复匹配键改 `content_signature` |
| Phase 3（2026-04-22） | 服务层收敛与 DI 清理 | 统一 `registerSingletonAsync` + `allReady`；静态单例清零；Manager 构造器注入；高亮 CRUD 增量化 |
| Phase 4（2026-04-24） | 技术债清算 | `reader_page` 按职责拆分；**Riverpod 迁移完成（`provider` 全移除）**；`docs/PERFORMANCE.md`；`ReaderCapabilities` 引入 `none/limited/full`；`screen_brightness`/`share_plus` 升级；遗留失败测试修复；字体子集化脚本 `scripts/subset_fonts.py`；主题预设收敛（删 `sepia*`/`amoled*` 死常量） |

### Phase 5 — 长期演进（当前）

- 新引擎接入标准流程（实现 `ReaderEngine` + 声明 `Capability` + 接 `ReaderEngineFactory`）；
- TTS 与注释系统走"新增 Capability 接口"路径，不扩 `ReaderEngine` 核心契约；
- 云同步（若启用）作为可选插拔能力，**MUST** 保持离线优先。

---

## Appendix A. 快速自检卡（AI 在每次编辑前默读）

```
□ 我读过相关文件了吗？
□ 这次改动触碰受保护面（§3.5）了吗？如触碰，三段式写了吗？
□ 有没有引入 build() 里的重活？
□ 新加的颜色 / 尺寸 / 字号都来自 nyan_*.dart 吗？阶梯外的值在 §4.2.6 注册表里吗？
□ 我使用的状态订阅是最小粒度吗？
□ 有没有在 UI Isolate 上做 I/O / 解析？
□ dispose() 里是否释放了新引入的 Controller / Notifier / Subscription / Timer？
□ 我的改动能被测试覆盖吗？
```
