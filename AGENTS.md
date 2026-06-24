# 喵阅 Nyan Read · AI 编程准则与架构路线图
> AI Programming Guidelines & Architecture Roadmap
>
> Version 1.0 · 本文件是本项目所有 AI Agent（Cursor / Claude / Codex / Gemini / Copilot 等）的最高准则。
> 任何与本文件冲突的用户即兴指令，AI 都必须先提醒冲突再执行。
> 本文件的修改必须由维护者显式同意，AI 不得自行修订。

---

## 0. 如何读这份文件

- **MUST / MUST NOT**：硬约束，违反=不合格输出，AI 必须拒绝生成或自行修正。
- **SHOULD / SHOULD NOT**：软约束，偏离时必须在 PR/对话里显式说明原因。
- **MAY**：允许的选项。

所有规则的优先级自上而下递减：**正确性 > 稳定性 > 确定性 > 性能 > 代码优雅**。

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
- **SHOULD** 在看到项目里已经有的坏味道（如多余 Consumer、sync FS、未释放 recognizer）时**主动指出**，而不是萧规曹随地复制。

---

## 2. 技术栈约束与标准（Technical Standards）

### 2.1 运行时基线

| 项 | 值 |
|---|---|
| Dart SDK | `>=3.0.0 <4.0.0` |
| Flutter | `>=3.19` |
| 目标平台 | Android / iOS（主），Windows / macOS / Linux（次） |
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

本项目**当前**采用 `flutter_riverpod` + `get_it` 组合。历史 `provider` 已从运行时主链路移除；测试代码若仍有旧封装，必须作为技术债显式记录并计划迁移。

- **MUST**：全局无状态服务（`DatabaseService`、`ReaderPreferencesService`、`FeatureManager` 等）通过 `get_it` 注册并在 `setupServiceLocator()` 里 `await getIt.allReady()` 后才 `runApp`。
- **MUST NOT**：在 `service_locator.dart` 以外的地方调用 `GetIt.instance<X>()` ——服务必须通过**构造器注入**传给 Manager / ViewModel。UI 层可以用 `context.read<X>()` / `context.watch<X>()`。
- **MUST**：订阅粒度遵循"**最小订阅原则**"：
  - 只读一次用 `context.read<X>()`；
  - 只需单字段变化用 `context.select<X, T>((x) => x.field)` 或 `Selector<X, T>`；
  - **SHOULD NOT** 在 `build()` 顶层用 `context.watch<X>()`，除非整颗子树的确依赖 `X` 的任意变化。
- **MUST**：高频变化的单值（progress、brightness、warmth、pagination page index）**MUST** 用 `ValueNotifier<T>` + `ValueListenableBuilder` 暴露，**不得**塞进 `ChangeNotifier.notifyListeners()` 的主干事件流。
- **MUST NOT**：在同一个 `ChangeNotifier` 里混放"结构性状态（章节、错误、能力）"与"高频连续值（progress）"——前者触发整树 Selector 重算，后者需要局部 listenable。

### 2.4 持久化规范（当前栈：`sqflite` + `shared_preferences` + `flutter_secure_storage`）

- **sqflite**：用于书籍元数据、书签、高亮、阅读位置、统计。
  - **MUST** 所有表变更走 `_onUpgrade` + 增量 `ALTER TABLE`，不得 DROP 用户表。
  - **MUST** 批量写（>3 条）使用 `db.batch()` 或 `db.transaction()`。
  - **MUST** schema 变更递增 `version`，并在 PR 描述中给出**数据迁移说明**与**回滚方案**。
  - **MUST NOT** 使用 `ConflictAlgorithm.replace` 于 `books` 表（会级联删除高亮/书签，历史痛点）。
- **shared_preferences**：用于 UI 配置（字号、主题、亮度、排序偏好）。
  - **MUST** 对"滑块类连续输入"的 setter 使用 `Debouncer(300ms)` 批量落盘，不得每次滑动都 `setDouble`。
  - **MUST NOT** 用它存放**任何**用户创作数据（书签、高亮、笔记）。
- **flutter_secure_storage**：仅用于 PIN 哈希与隐私书架密钥。
  - **MUST NOT** 存明文密码；**MUST** salt + hash。
- **缓存大小**：封面图缓存 **SHOULD** 控制在 100MB 以内，**MUST** 有 LRU 淘汰策略。

### 2.5 第三方包纪律

- **MUST NOT** 引用任何包的 `package:xxx/src/...` 路径（私有 API）。当前已存在的 `package:epub_view/src/...` 是已知技术债，不得再新增。
- **MUST** 新增依赖时在 PR 里给出：用途、体积影响、可替代方案、最近一次 commit 时间、是否支持 null-safety。

---

## 3. 架构蓝图（Architecture Blueprint）

### 3.1 分层契约

```
┌──────────────────────────────────────────────────────────┐
│  Presentation Layer   (lib/modules/**/widgets, pages)    │
│  —— Widgets、Gesture、Selector/ValueListenable 订阅       │
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
3. **层次首选"圆角 + 背景色阶 + 暖色调分隔线"**；阴影只允许走 `NyanShadows.lightCard` / `subtle` / `settingsGrouped`（均 ≤12px blur，≤5% alpha）。**严禁**自己构造 `BoxShadow`。

### 4.2 设计 Token 真相表（MUST 引用这些常量，不得新造色值）

#### 4.2.1 颜色 — `lib/core/theme/nyan_colors.dart`

**主题敏感色（MUST 通过 `NyanTheme` 扩展访问）：**

> **Sumi Dark 色阶已按设计系统交付包（2026-06）重新调校为 v3 高度阶梯（elevation ladder）**：
> 暗色用"色调"承载层级——表面随升起逐级**变亮**（`bg < surfaceMuted < surface < surfaceRaised`，相邻保持可见亮度差）。

| 语义 | creamLight 值 | sumiDark 值 | `NyanTheme` 字段 |
|---|---|---|---|
| 页面主背景（纸色 / 暗色页底） | `#F6F3EA` | `#181B16` | `background` |
| 卡片/面板表面（+1 层） | `#FFFDF8` | `#242922` | `surface` |
| 嵌入式凹陷表面（Tab 槽、Slider 轨道，刚高于页底） | `#F1ECDD` | `#1D211B` | `surfaceMuted` |
| 最高浮层（对话框 / Sheet / 弹出层；亮色复用 surface） | `#FFFDF8` | `#2E342B` | `surfaceRaised` |
| 正文文字 | `#3F3A34` | `#ECE6DB` | `textPrimary` |
| 次级文字（说明 / 副标题） | `#5F5950` | `#BBB3A6` | `textSecondary` |
| 三级文字（占位 / 单位） | `#6B6559` | `#9A948B` | `textMuted` |
| 主强色（抹茶绿按钮底） | `#6E7A55` | `#A9B690` | `primary` |
| 深强色（选中描边 / accent） | `#5A6644` | `#B7C69E` | `primaryDeep` / `accent` |
| 分隔线（暖调描边） | `#E5DED2` | `#3D443A` | `divider` |
| 卡片硬描边（暗色发光环用） | `#E5DED2` | `#474E42` | `borderColor` |

**错误色（暖陶土，非临床红）**——设计系统交付包要求错误状态读起来"平静、在地"而非"刺眼的 Material 红"：
creamLight `errorBackground #FBF2EC` / `errorPrimary #9C5C49` / `errorSecondary #8A6A55` / `errorAccent #ECD9CC`；
sumiDark `#241D18` / `#CE9A86` / `#B6967F` / `#3A2D24`。

> **U8 Reader Error View 用色说明（2026-06，来源 `bundle2-screens.jsx` `ErrorView`）**：
> - **页面背景**：错误页使用 `nyan.background`（标准页底色），**MUST NOT** 用 `errorBackground`。
> - **图标容器底色**：`Color.lerp(nyan.surface, errorPrimary, 0.08)` — 对应 CSS `color-mix(in srgb, var(--error-primary) 8%, var(--nyan-surface))`。
> - **图标容器描边**：`errorPrimary.withValues(alpha: 0.22)`（0.7px 描边）。
> - **Retry 按钮**：`NyanPrimaryButton(variant: primary)` — 抹茶绿，**MUST NOT** 用 `errorAccent`。
> - **Report 按钮**：`NyanIcons.bugBeetle`（`ph-bug-beetle`）+ `nyan.textMuted`。
> - `errorBackground` token 保留备用；**MUST NOT** 用作全屏错误页背景。

**原子常量（只在 `nyan_colors.dart` 与 `theme_presets.dart` 内部使用，业务代码 MUST NOT 直接引用）：**

- cream 系列：`creamBackground / creamSurface / creamSurfaceMuted / creamPrimary / creamPrimaryDeep / creamTextMain / creamTextSecondary / creamTextMuted / creamDivider`
- ink 系列：`inkNightBackground / inkNightSurface / inkNightSurfaceMuted / inkNightSurfaceRaised / inkNightPrimary / inkNightTextMain / inkNightTextSecondary / inkNightTextMuted / inkNightDivider`
- ink 深阶：`inkNightPrimaryDeep`（dark preset 的 accent/深强调）、`inkNightBorder`（v3 阶梯的卡片硬描边/发光环）

**语义色（固定值，不随主题切换，可直接引用）：**

| 用途 | 常量 | 值 |
|---|---|---|
| 高亮笔 · 黄 | `NyanColors.highlightYellow` | `#F2E58A` |
| 高亮笔 · 绿 | `NyanColors.highlightGreen` | `#A8D18D` |
| 高亮笔 · 蓝 | `NyanColors.highlightBlue` | `#9EC5E8` |
| 高亮笔 · 粉 | `NyanColors.highlightPink` | `#E8A0BF` |
| 高亮笔 · 橙 / 暖色温语义 / 警告 | `NyanColors.highlightOrange` | `#F2BE7E` |

**特殊状态色**（只在 `NyanTheme` 内定义）：`successColor` / `warningColor` / `infoColor` / 4 个 `errorXxx` / 2 个 `fabXxx`，业务代码通过 `Theme.of(context).extension<NyanTheme>()!.successColor` 等访问。

> **例外 — Privacy PIN 全屏遮罩深色墨（交付包对齐，2026-06，来源 `screens/bundle4.jsx` `PinOverlay`）**：U16 全屏 PIN 遮罩的**深色变体**使用一组**专属墨色字面值**——页底 `#1D211E`、前景墨 `#E8E1D5`——与交付包 mock 严格一致（mock 没有复用标准 sumi token `#181B16` / `#ECE6DB`，而是另选了这两个略偏橄榄的近黑/暖白）。这两个值游离于两套 `NyanTheme` 预设之外，故定义在 `NyanColors.pinOverlayInkBackground` / `pinOverlayInk`，并**仅由** PIN 遮罩组件（`PinOverlayPage` / `PinInputWidget`）直接引用。**亮色变体仍走 `NyanTheme` token**（`background` / `textPrimary` / `textMuted` / `primary` / `primaryDeep`）。这是 §2.2.3"业务 Widget MUST NOT 直接引用原子色常量"的一处**显式豁免**，仅限此遮罩。

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

**MUST NOT**：使用 `10`、`14`、`18`、`22` 等非 8 的倍数（`4 / 12 / 20` 是唯一例外，已在常量表中）。

> **例外 — 交互控件内部间隙（Claude Design 系统对齐，2026-05）**：`NyanPrimaryButton` 的图标↔文字间隙固定为 **6pt**（来源：`components.jsx` 设计 spec）。此例外**仅限**控件内部 icon-label 配对（按钮、Pill 等），**MUST NOT** 用于卡片、列表、页面层级的布局间距。

> **例外 — 章节列表行内部间隙（交付包对齐，2026-06，来源 `reader.jsx` `ReaderChapterList`）**：`ChapterListItem` 的数字徽标↔标题间隙固定为 **14pt**（`_kBadgeTitleGap`，来源：`reader.jsx` `gap: 14`）。此例外**仅限** `ChapterListItem` 徽标与标题之间，**MUST NOT** 用于其它列表行、卡片或页面级布局间距。

> **例外 — Reader 设置 Knob 内边距（交付包对齐，2026-06，来源 `reader.jsx` `Knob`）**：`ReaderSettingsKnob` 的内边距固定为 **14pt**（`padding: 14`，来源：`reader.jsx`）。此例外**仅限** `ReaderSettingsKnob` 容器本身，**MUST NOT** 用于卡片、列表、页面层级的布局间距。

> **例外 — Highlights & Notes 卡片水平内边距（交付包对齐，2026-06，来源 `screens/bundle3.jsx` `HighlightCard`）**：`NyanHighlightCard` 的水平内边距固定为 **14pt**（`_kCardPaddingH`，来源：`bundle3.jsx` `padding: "12px 14px"`）。此例外**仅限** `NyanHighlightCard` 容器本身，**MUST NOT** 用于其它卡片、列表、页面级布局间距。

> **例外 — Action Response 卡片内部间距（交付包对齐，2026-06，来源 `components/surfaces/NyanResponse.jsx`）**：全局反馈 toast `NyanResponse` 的卡片**垂直内边距固定为 10pt**（`_kCardPaddingV`，来源：`NyanResponse.jsx` `padding: "10px 12px"`；水平 12pt 走 `NyanSpacing.space12`），标题↔描述间隙固定为 **2pt**（`_kTitleDescGap`，来源：`marginTop: 2`）。这两个值仅为对齐交付包的卡片内部微距。此例外**仅限** `nyan_response.dart` 容器本身，**MUST NOT** 用于其它卡片、列表、页面级布局间距。

> **例外 — 书架吸顶标签栏底部间距（交付包对齐，2026-06，来源 `screens/bundle4.jsx` `ShelfToolbarScreen`）**：`bookshelf_shelf_toolbar.dart` 的 `_kShelfTrackVerticalPaddingBottom` 固定为 **10pt**（来源：`bundle4.jsx` tab wrapper `marginBottom: 10`）。此值比 8pt 网格大 2pt（§4.6 交付包优先）。此例外**仅限**书架吸顶标签栏的底部内边距，**MUST NOT** 用于其它卡片、列表或页面级布局间距。

> **例外 — 书架列表行垂直内边距（交付包对齐，2026-06，来源 `screens/bundle3.jsx` `BookListRow` / `SelectBookListRow`）**：`animated_book_card.dart`（`AnimatedBookCardList`）的行垂直内边距固定为 **10pt**（来源：`bundle3.jsx` `padding: "10px 12px"`）。此值比 8pt 网格大 2pt（§4.6 交付包优先）。此例外**仅限** `AnimatedBookCardList` 行内边距，**MUST NOT** 用于卡片、页面或其它列表级布局间距。

#### 4.2.4 阴影 — `lib/core/theme/nyan_shadows.dart`

三个工具方法**现在接收 `NyanTheme nyan`（不再是裸 `Color`）**，并按 `nyan.brightness` 自动选配方：

- `NyanShadows.lightCard(nyan)` — 浮动 chrome（卡片、顶栏、dock、Sheet、对话框、弹出层）。
- `NyanShadows.subtle(nyan)` — 次级浮层（Toast、轻浮动通知）。
- `NyanShadows.settingsGrouped(nyan)` — 设置分组卡片（`NyanRowGroup`）。
- `NyanShadows.shelfPinnedHeader(nyan)` — 书架吸顶标签栏的向下投影，**仅在 `overlapsContent == true` 时启用**（内容滚动至标签栏下方时才显示）。来源：`screens/bundle4.jsx` ShelfToolbarScreen tab wrapper `box-shadow: 0 6px 14px -8px rgba(40,36,30,.22)`；暗色使用 `Colors.black@32%`（暖墨色在深色背景下不可见）。

- **Cream Light**：暖墨 drop shadow（lightCard 4%/2%@12/6px；subtle 5%@8px；grouped 1.4%@10px），墨色取自 `nyan.textPrimary`。
- **Sumi Dark（v3 高度阶梯，2026-06 修订）**：**"暗色无阴影"旧规已废止**。暗色用 **`0.75px` 发光描边环**（`nyan.divider` 88/66/50% spread）+ 柔和黑色 ambient 承载层级，让升起的表面读成独立平面。
  - CSS 还含 `inset 0 1px 0 white@5%` 顶部 catch-light；Flutter `BoxShadow` 无 inset 模式，故该 1px 内高光**不在阴影 token 内**——需要的浮层（对话框/Sheet）在自身 decoration 上加 `Border(top: white@5%)` 顶边补上（见 `NyanBottomSheet` / 亮度弹层）。

**MUST NOT** 自造 `BoxShadow`；需要新阴影先在 token 内定义。**MUST NOT** 再写 `dark ? const [] : ...` 给暗色卡片退订阴影——环已承载平面分离。

#### 4.2.5 字体与字号 — `lib/core/theme/nyan_typography.dart`

- UI 字体族：`NyanTypography.uiFontFamily` = **`Noto Sans SC`**
- 阅读正文可选 serif：`NyanTypography.readingSerifFontFamily` = `Source Han Serif SC`
- 字号阶梯（**仅允许**以下 6 档）：`display 32` / `title 24` / `section 20` / `body 16` / `meta 13` / `caption 11`。其中 **`caption 11` 仅用于橄榄色 eyebrow 小标题**（`NyanTypography.eyebrowStyle(nyan.primaryDeep)`，w500 + 0.22 字距 + 大写），**MUST NOT** 用于正文、列表行或其它表面。
- **字重仅允许**：`FontWeight.w400`（Regular，正文）/ `FontWeight.w500`（Medium，按钮/标签）/ `FontWeight.w600`（SemiBold，标题/数值）。**MUST NOT** 使用 `w100–w300` 或 `w700–w900`。

> **例外 — 交互控件标签字号（Claude Design 系统对齐，2026-05）**：`NyanPrimaryButton` 的 label 文字按 size 变体使用 **14 / 16 / 17pt**（compact / standard / comfortable，来源：`components.jsx` 设计 spec）。这三个值是控件标签**专属**——**MUST NOT** 出现在正文、标题或任何其它表面。常量定义见 `NyanTypography.buttonCompact` / `NyanTypography.buttonComfortable`（body 16 复用 `NyanTypography.body`）。

> **例外 — Reader 设置 Knob 标签字号（交付包对齐，2026-06，来源 `reader.jsx` `Knob`）**：`ReaderSettingsKnob` 的标签文字使用 **15pt w600**（来源：`reader.jsx` knob label style）。此值介于阶梯 `body 16` 与 `meta 13` 之间，是刻意的非阶梯值（§4.6 交付包优先）。此例外**仅限** `ReaderSettingsKnob` 标签，**MUST NOT** 出现在正文、列表行或其它表面。

> **例外 — One Paper 模态 Sheet 标题字号（交付包对齐，2026-06，来源 `screens/bundle3.jsx` `ImportSheet`）**：`NyanOnePaperSheet` 内的模态 sheet 标题（如 "Import Books"）使用 **18pt w600**，`letterSpacing: -0.1`（来源：`bundle3.jsx` `font: "600 18px/1.2"`）。此值介于阶梯 `section 20` 与 `body 16` 之间，是 One Paper 浮层标题的专属字号（§4.6 交付包优先）。此例外**仅限** `NyanOnePaperSheet` 内的顶层标题，**MUST NOT** 出现在正文、列表行、卡片或其它表面。

> **例外 — Import Sheet "Supported Formats" 节标签字号（交付包对齐，2026-06，来源 `screens/bundle3.jsx` `ImportSheet`）**：`ImportBookSheet` 的 Supported Formats 节标题使用 **15pt w500**（来源：`bundle3.jsx` `font: "500 15px/1.2"`）。此值介于阶梯 `body 16` 与 `meta 13` 之间（§4.6 交付包优先）。此例外**仅限** `ImportBookSheet` 内的该节标题，**MUST NOT** 出现在其它表面。

> **例外 — 书架列表行微标签（交付包对齐，2026-06，来源 `screens/bundle3.jsx` `BookListRow`）**：list-view 书行的两个微标签低于字号阶梯——格式徽标（TXT / EPUB / PDF）**9pt w600**，尾部阅读百分比 **11pt monospace**（`NyanTypography.monoFontFamily`）。这两个值是**书架列表行专属**——**MUST NOT** 出现在正文、标题或任何其它表面。常量定义见 `NyanTypography.shelfFormatChip`（9）/ `NyanTypography.shelfProgressLabel`（11）。§4.6 交付包优先。

> **例外 — Privacy PIN 键盘字号（交付包对齐，2026-06，来源 `screens/bundle4.jsx` `NumPad`）**：U16 全屏 PIN 键盘的数字键使用 **27pt w500**、退格图标（`ph-backspace`）**24pt**，均落在 6 档阶梯之外（§4.6 交付包优先）。这两个值是 `PinInputWidget` 键盘**专属**——**MUST NOT** 出现在正文、标题或任何其它表面。常量定义见 `NyanTypography.pinKeyDigit`（27）/ `NyanTypography.pinKeyGlyph`（24）。

> **例外 — Reader Error View 字号（交付包对齐，2026-06，来源 `screens/bundle2-screens.jsx` `ErrorView`）**：U8 错误视图的标题使用 **18pt w600**（`font: "600 18px/1.25"`），正文使用 **14pt w400**（`font: "400 14px/1.5"`），两者均落在 6 档阶梯之外（§4.6 交付包优先）。这两个值是 `ReaderErrorView` **专属**——**MUST NOT** 出现在正文列表行、卡片或其它表面。

> **例外 — Notes & Highlights 空状态字号（交付包对齐，2026-06，来源 `screens/bundle3.jsx` `NotesList` empty state）**：`NotesListPage` 空状态标题使用 **18pt w600**（`font: "600 18px/1.25"`），说明行使用 **14pt w400**，提示行使用 **13pt w400**，均落在 6 档阶梯之外（§4.6 交付包优先）。这三个值是 `NotesListPage` 空状态**专属**——**MUST NOT** 出现在正文、列表行、卡片或其它表面。

> **例外 — Chapters Sheet "Jump to current" FAB 标签字号（交付包对齐，2026-06，来源 `screens/bundle1.jsx` `ChapterDockSheet`）**：目录 Sheet 浮动按钮的标签使用 **13.5pt w600**（来源：`bundle1.jsx` `font: "600 13.5px/1"`）。此值介于阶梯 `meta 13` 与 `buttonCompact 14` 之间（§4.6 交付包优先）。此例外**仅限** `_JumpToCurrentButton`（`chapter_list_widget.dart`）标签，**MUST NOT** 出现在正文、列表行、卡片或其它表面。常量定义见 `NyanTypography.fabLabel`（13.5）。

> **例外 — 书架排序 Sheet 字段行标签字号（交付包对齐，2026-06，来源 `screens/bundle3.jsx` `ShelfSortSheet`）**：`bookshelf_sort_sheet.dart` 的字段行主标签使用 **15pt**（选中态 w600 `primaryDeep`，未选 w500 `textPrimary`；来源：`bundle3.jsx` `font: "${isSel ? 600 : 500} 15px/1.2"`）。此值介于阶梯 `body 16` 与 `meta 13` 之间（§4.6 交付包优先）。此例外**仅限** `_SortFieldRow` 主标签，**MUST NOT** 出现在正文、其它列表行或卡片表面。常量定义见 `NyanTypography.shelfSortFieldLabel`（15）。

> **例外 — 书架排序 Sheet 字段行子标签字号（交付包对齐，2026-06，来源 `screens/bundle3.jsx` `ShelfSortSheet`）**：`bookshelf_sort_sheet.dart` 的字段行子标签（如 "A → Z"、"Oldest opened first"）使用 **12.5pt w400 `textSecondary`**（来源：`bundle3.jsx` `font: "400 12.5px/1.3"`）。此值介于阶梯 `caption 11` 与 `meta 13` 之间（§4.6 交付包优先）。此例外**仅限** `_SortFieldRow` 子标签，**MUST NOT** 出现在正文、其它列表行或任何其它表面。常量定义见 `NyanTypography.shelfSortFieldSub`（12.5）。

> **例外 — Admin Panel 行标签字号（交付包对齐，2026-06，来源 `screens/bundle4.jsx` `AdminPanel`）**：`admin_panel.dart` 的 `_AdminSwitchRow` 与 `_AdminFlagRow` 主标签使用 **15pt**（选中/关闭均同；来源：`bundle4.jsx` `font: "600 15px/1.2"` / `"500 15px/1.2"`）。此值介于阶梯 `body 16` 与 `meta 13` 之间（§4.6 交付包优先）。此例外**仅限** `_AdminSwitchRow` 与 `_AdminFlagRow` 主标签，**MUST NOT** 出现在正文、其它列表行或卡片表面。常量定义见 `NyanTypography.adminRowLabel`（15）。

> **例外 — Admin Panel 功能开关徽标字号（交付包对齐，2026-06，来源 `screens/bundle4.jsx` `FlagBadge`）**：`admin_panel.dart` 的 `_AdminFlagRow` 徽标芯片文字使用 **12pt w500**（来源：`bundle4.jsx` `font: "500 12px/1"`）。此值介于阶梯 `caption 11` 与 `meta 13` 之间（§4.6 交付包优先）。此例外**仅限** `_AdminFlagRow` 内的 `FlagBadge` 文字，**MUST NOT** 出现在正文、列表行、标题或其它表面。常量定义见 `NyanTypography.adminBadgeLabel`（12）。

> **例外 — Admin Panel 提示卡标题字号（交付包对齐，2026-06，来源 `screens/bundle4.jsx` `AdminPanel` hint card）**：`admin_panel.dart` 的 `_AdminHintRow` 标题使用 **14pt w600**（来源：`bundle4.jsx` `font: "600 14px/1.2"`）。数值与 `buttonCompact` 相同但语义不同，属提示卡专属标题（§4.6 交付包优先）。此例外**仅限** `_AdminHintRow` 标题，**MUST NOT** 出现在按钮、正文、列表行或其它表面。常量定义见 `NyanTypography.adminHintTitle`（14）。

> **例外 — Action Response 卡片标题字号（交付包对齐，2026-06，来源 `components/surfaces/NyanResponse.jsx`）**：全局反馈 toast `NyanResponse` 的标题使用 **14pt w600**、行高 1.25（来源：`NyanResponse.jsx` `font: "600 14px/1.25"`）。此值介于阶梯 `body 16` 与 `meta 13` 之间（§4.6 交付包优先）。此例外**仅限** `NyanResponse` 标题行，**MUST NOT** 出现在正文、列表行、其它标题或表面。常量定义见 `NyanTypography.responseTitle`（14）。

> **例外 — Action Response 卡片描述字号（交付包对齐，2026-06，来源 `components/surfaces/NyanResponse.jsx`）**：`NyanResponse` 的描述行使用 **12.5pt w400**、行高 1.35（来源：`NyanResponse.jsx` `font: "400 12.5px/1.35"`）。此值介于阶梯 `caption 11` 与 `meta 13` 之间（§4.6 交付包优先）。此例外**仅限** `NyanResponse` 描述行，**MUST NOT** 出现在正文、列表行或其它表面。常量定义见 `NyanTypography.responseDescription`（12.5）。

> **例外 — U21 书架选择标题字号（交付包对齐，2026-06，来源 `screens/bundle3.jsx` `SelectionHeader`）**：`home_screen.dart` 的选择模式 AppBar 标题（如 "2 Selected"）使用 **18pt w600**、字距 -0.2（来源：`bundle3.jsx` `font: "600 18px/1.15"`, `letterSpacing: "-0.2px"`）。此值介于阶梯 `body 16` 与 `section 20` 之间（§4.6 交付包优先）。此例外**仅限** `_buildSelectionAppBar` 标题，**MUST NOT** 出现在正文、列表行或其它表面。常量定义见 `NyanTypography.selectionHeaderTitle`（18）。

> **例外 — U21 删除确认 Sheet 标题字号（交付包对齐，2026-06，来源 `screens/bundle3.jsx` `DeleteConfirmSheet`）**：`_DeleteBooksSheetContent` 的标题（"Delete N books?"）使用 **19pt w600**、字距 -0.2（来源：`bundle3.jsx` `font: "600 19px/1.25"`, `letterSpacing: "-0.2px"`）。此值介于阶梯 `body 16` 与 `section 20` 之间（§4.6 交付包优先）。此例外**仅限** `_DeleteBooksSheetContent` 标题行，**MUST NOT** 出现在正文、列表行或其它表面。常量定义见 `NyanTypography.deleteConfirmTitle`（19）。

> **例外 — U21 删除确认 Sheet 正文字号（交付包对齐，2026-06，来源 `screens/bundle3.jsx` `DeleteConfirmSheet`）**：`_DeleteBooksSheetContent` 的说明行使用 **13.5pt w400**（来源：`bundle3.jsx` `font: "400 13.5px/1.45"`）。此值介于阶梯 `meta 13` 与 `body 16` 之间（§4.6 交付包优先）。此例外**仅限** `_DeleteBooksSheetContent` 正文行，**MUST NOT** 出现在其它表面。字面量 `13.5` 直接写在该 widget 内，无独立常量（值已有先例：`NyanTypography.fabLabel = 13.5`）。

> **例外 — U22 Sponsored Shelf Placement 字号（交付包对齐，2026-06，来源 `screens/U22 - Sponsored Shelf Placement.html`）**：`NyanShelfDiscoverBlock`（Option B Discover block）与 `NyanShelfProNudge`（Option C Pro nudge）引入 4 个专属字号，均落在 6 档阶梯之外（§4.6 交付包优先）：
> - `NyanTypography.discoverBlockTitle = 14.5` — Discover block 标题 "More stories you may like"（`600 14.5px/1.25`）及 Pro nudge "Upgrade to Pro" 按钮标签（`600 14.5px/1`），**仅限**这两处，**MUST NOT** 出现在正文、列表行或其它表面。
> - `NyanTypography.sponsoredBadge = 9.5` — "SPONSORED" 大写徽标（`600 9.5px/1`，letterSpacing 0.5），**仅限** Discover block 赞助商标识行，**MUST NOT** 出现在其它表面。
> - `NyanTypography.miniSuggestTitle = 11.5` — Discover block 书格标题（`600 11.5px/1.3`，2 行截断），**仅限** `_MiniSuggestTile`，**MUST NOT** 出现在其它表面。
> - `NyanTypography.miniSuggestAuthor = 10.5` — Discover block 书格作者（`400 10.5px/1.2`），**仅限** `_MiniSuggestTile`，**MUST NOT** 出现在其它表面。

> **新增阴影 Token — `NyanShadows.cardSelectionGlow` / `selectionBadgeGlow`（2026-06，来源 `bundle3.jsx` `SelectBookCard`）**：选中书格封面外发光（`primary@16%` spread 3px）和 SelectCheck 徽标发光（`primary@40%` 1px drop shadow）通过 `NyanShadows.cardSelectionGlow(nyan)` / `selectionBadgeGlow(nyan)` 访问，**MUST NOT** 直接构造 `BoxShadow`。

> **书架选择模式 open-detail 快捷按钮（交付包对齐，2026-06，来源 `screens/bundle3.jsx` `SelectBookCard` / `SelectBookListRow`）**：选择模式下每个书格封面右下角显示一个 **24×24 圆形 ↗ 按钮**（`ph-arrow-up-right`，`NyanIcons.arrowUpRight`，`primaryDeep` 色，`surface@90%` 毛玻璃底 + `divider@50%` 描边 + `0 1px 3px rgba(0,0,0,.12)` 阴影）；列表行右侧显示一个 **32×32 圆形 › 按钮**（`ph-caret-right`，`textSecondary` 色，`surfaceMuted` 底 + `divider@44%` 描边），两者点击均独立导航至书籍详情页，**不改变当前选中状态**。非选择模式下列表行只显示等宽的裸图标（无圆圈）。**MUST NOT** 在其它场景使用这两个按钮的圆形容器样式。

> ✅ **字体已注册（§6 Phase 0 已完成）**：`pubspec.yaml` 的 `flutter.fonts` 段已声明 `Noto Sans SC`（400/500/600）+ `Source Han Serif SC`（400/600）；字体文件存放于 `assets/fonts/`，**未纳入 Git**（体积原因）。开发者需按 `assets/fonts/README.md` 说明手动放置字体文件。缺少字体时 Flutter 打印 warning 并回落平台字体，不影响编译；但 serif 阅读模式仅在字体文件就位后生效。

### 4.3 组件样式底线（MUST）

- **Bottom Sheet / 对话框 / 弹出层**：圆角 `NyanRadius.sheet`（28pt）/`dock`（24pt），顶部 12pt 留白内含抓手（`--grabber` = `primary` 36%亮/50%暗）；底色取 `surfaceRaised`（亮色等于 surface，暗色为 v3 阶梯最高层）；阴影走 `NyanShadows.lightCard(nyan)`（暗色自带发光环）。
- **Tab / Segmented Control**（2026-06 交付包对齐）：外层轨道 `NyanRadius.control`（14pt）+ 4pt 内边距 + `surfaceMuted` 底（**仅靠色调凹陷，无描边**）；内部滑动指示器同心内嵌 11pt（=14−3）；emphasis 指示器 = `surface` 实心 + `NyanShadows.settingsGrouped`，subtle 指示器 = `primary @ 16%` tint；选中文字 = `primaryDeep`，未选 = `textSecondary`；**禁止**下划线；动画固定 **280ms ease-paper**（`cubic-bezier(0.33,0.9,0.36,1)`，来源 `components/primitives.jsx`）。此规则适用于**面板内 / sheet 内的调节型分段控件**（reader 排序/分节、排序 sheet 的升降序）。

  > **修订说明（2026-06 交付包对齐）**：此前记为外层 20pt(`card`) / 内层 16pt / 240ms / primary 实心填充；交付包 `SegmentedTabControl` 实为外层 14pt(`control`) / 内层 11pt / 280ms / surface 浮起 chip，此处更正。

  > **例外 — 顶层书架切换器（`SegmentedTabStyle.shelf`，2026-06，来源 `BookshelfScreen.jsx` / `bundle3.jsx`）**：Public / Private 这种**页面级导航**分段器不走上面的 `primaryDeep` / `textSecondary` 规则。指示器 = `surface` 实心 chip + `NyanShadows.settingsGrouped`，**选中文字 = `textPrimary` + w600**（深墨粗体，读作页面级导航而非面板内调节），未选 = `textMuted` + w500；内边距收到 **3pt**（令 11pt 指示器真正同心：14−3）。这是交付包屏幕稿明确的视觉意图（§4.6 交付包优先），**MUST NOT** 把它"修正"回 `primaryDeep`。其它分段控件仍遵循上一条。
- **Pill 按钮 / 选项 chip（低/中/高、紧凑/标准/舒展、Sans/Serif 等）**（2026-06）：**方圆角 `NyanRadius.chip`（12pt），不再是 `StadiumBorder`**；未选 = `surfaceMuted` 底 + 透明描边 + `textSecondary` 文字；选中 = **去填充（透明底）+ `primaryDeep` 1.5px 描边 + `primaryDeep` 文字**——chip "浮离轨道"。这是本项目的招牌交互（outline-on-select），和 Material 填充 chip 截然不同。
- **Reader chrome（One Paper，2026-06）**：阅读器底部**只有一块浮动纸面板**——collapsed 时是 `dock`（`OnePaperDock`，inset 12pt / `r-dock` 24），点 Chapters/Settings **原地长成 sheet**（`r-sheet` 28，`AnimatedAlign` 高度展开，`dur-grow` 320ms ease-paper），footer（章节 stepper `‹ ›` + 细进度条 + **4 个动作 Chapters/Bookmarks/Highlights/Settings**）始终钉在底部。**亮度不在 dock**：走顶栏太阳弹层（`ReaderBrightnessPopover`，玻璃拟态）+ 左缘竖向拖拽。Sheet 升起时页面 scrim + 2px 模糊（仅展开时挂载）。Bookmarks 和 Highlights 都是 push 页面，不是 sheet（"adjust→sheet；browse→page"）。**MUST NOT** 回退到边到边贴底控制条或把 Settings/Chapters 改成独立 modal sheet。
- **Action Response（全局反馈 toast，`NyanResponse`，2026-06 交付包对齐，来源 `components/surfaces/NyanResponse.jsx`）**：全 App **唯一**的"刚刚发生了什么"反馈面（导入完成 / 删除 / 跳过 / 进行中）。**左对齐卡片**而非居中胶囊——圆角 `NyanRadius.cardNested`（16pt）+ `surface` 底 + `NyanShadows.subtle(nyan)` + `--chrome-edge` 描边（亮色透明、暗色 `divider` 环）；浮动 chrome 距屏幕边缘 `NyanSpacing.space12`（左右 12pt，宽屏 maxWidth 480pt 居中，手机满宽）；卡内：左侧 36×36 状态色块（`NyanRadius.chip` 12pt + 状态 tint 底 + 20pt 图标）→ `space12` 间隙 → 标题（`responseTitle` 14/w600）+ 可选描述（`responseDescription` 12.5/w400，`textSecondary`）。**5 个状态**：`success`（`checkCircle` + `successColor` + success 13% tile）/ `error`（`warningCircle` + `errorPrimaryTextColor` + `errorBackground` tile）/ `skipped`（`skipForward` + `textMuted` + `surfaceMuted` tile）/ `info`（`info` + `infoColor` + info 13% tile）/ `loading`（`circleNotch` 旋转 + `primary` + primary 12% tile）。**MUST NOT** 回退到居中胶囊（`StadiumBorder` / radius 999）或自造 `BoxShadow`。自动消失的 toast **省略** ✕（`onDismiss` 留空，DS 契约）；`NyanResponse` 仍支持 `onDismiss` 以备常驻场景。
- **Slider**：轨道高 3–4pt 用 `surfaceMuted`，已填充段用 `primaryDeep`（亮度）或 `highlightOrange`（暖色温），thumb 10–12pt 实心同色，**无光晕、无阴影、无放大**。
- **Card**：圆角 `NyanRadius.card`（20pt），`surface` 底，`divider` 描边；**默认无阴影**；仅在书架 hover / 次级浮层必要时使用 `NyanShadows.subtle`。
- **书架列表视图（list view，2026-06，来源 `screens/bundle3.jsx` `BookListRow`）**：**单块分组面板**而非逐项独立卡片——外层 `surface` 底 + `NyanRadius.cardNested`（16pt）+ `NyanShadows.settingsGrouped` + `--chrome-edge` 描边（亮色透明、暗色 `divider` 环），各行**无自身边框/阴影**，行间用 0.5px `divider@34%` 发丝线（左右内缩 12pt）分隔。行内：左侧 44×58 竖向封面（`NyanRadius.chip`），标题 14pt w600 单行 + 作者独占一行（`textMuted`）+ 进度行（仅 `progress>0` 时显示：满宽 3pt 轨 + 11pt mono 百分比），尾部格式徽标 + `chevronRight`。为不破坏懒加载（§3.4），分组外观由 `DecoratedSliver` 承载、内部仍是 `SliverList.builder`。选中态走整行 `primaryDeep` 淡色填充（`context.selectionSurface`），不加逐行描边。**MUST NOT** 回退到逐项独立卡片 + 卡间留白的旧实现。
- **Icon**：线性 1.5pt 感——图标系统为 **Phosphor Regular**，所有图标 **MUST** 来自 `lib/core/ui/nyan_icons.dart`（`NyanIcons.*`），**MUST NOT** 直接用 `Icons.*`。填充权重仅保留给"已设书签"与主题卡选中对勾，以及以下 §4.6 交付包授权的例外：`NyanIcons.compassFilled`（Discover block 头图）/ `NyanIcons.leafFilled`（Pro nudge 图标）/ `NyanIcons.sparkleFilled`（Pro nudge 升级按钮）/ `NyanIcons.checkCircleFilled`（Pro nudge 特性列表），均限定于 `NyanShelfDiscoverBlock` / `NyanShelfProNudge`，**MUST NOT** 扩散至其它组件。
- **Haptics**：滑块拖动最多一次 `HapticFeedback.lightImpact`；翻页 **MUST NOT** 触发触感反馈。
- **Tap target**：所有可点击元素最小 44×44pt（`NyanSpacing.minTapTarget`）。

### 4.4 设计反模式（MUST NOT）

- ❌ Material3 `FilledButton` / `ElevatedButton` 默认阴影（项目已在 `NyanTheme.themeData` 里把 `elevation: 0`，不要去改回来）；
- ❌ `CircularProgressIndicator` 的默认蓝色（必须显式指定 `valueColor: AlwaysStoppedAnimation(nyan.primary)`）；
- ❌ 自造 `BoxShadow`（必须走 `NyanShadows.*` 工具；亮色 ≤12px blur，暗色 v3 阶梯的 ambient 可达 24px 但仅限 token 内部）；
- ❌ 给暗色卡片写 `dark ? const [] : ...` 退订阴影（v3 发光环已承载平面分离）；
- ❌ Pill / 选项 chip 用 `StadiumBorder`（已废止，改用 `NyanRadius.chip` 12pt 方圆角 + outline-on-select）；
- ❌ 高饱和色（iOS 蓝、Material 紫、霓虹任何色）；
- ❌ 大面积线性/径向渐变（已批准的例外：①亮度弹层玻璃拟态模糊；② U22 `NyanShelfProNudge` 渐变背景 + 叶片图标 + Upgrade 按钮，来源 `screens/U22 - Sponsored Shelf Placement.html` `ProNudge`，§4.6 交付包优先）；
- ❌ `Icons.xxx_filled` 填充图标（对勾徽标除外）；
- ❌ 卡片之间加 `Divider`（层次用 `surfaceMuted` 背景色差代替）；
- ❌ 字重越界（仅允许 `w400 / w500 / w600`，`w700+` 一律 reject）；
- ❌ 自制字体族，任何 `TextStyle(fontFamily: '...')` 的 `fontFamily` 必须来自 `NyanTypography`；
- ❌ 直接引用 `NyanColors.creamXxx / inkNightXxx` 原子常量到业务 Widget 里（必须走 `NyanTheme` 扩展）。

### 4.5 AI 写 UI 的自检清单

生成 UI 代码前，自问并在对话中默认回答：

1. **Token**：颜色是否走 `Theme.of(context).extension<NyanTheme>()`？间距/圆角/字体/阴影是否都来自 `nyan_*.dart`？
2. **订阅粒度**：这颗子树真正会变的字段是哪一个？我是不是用了最小的 `Selector` / `ValueListenableBuilder`？
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

> **设计系统交付包说明**：`nyan-read-design-system-handoff.zip` 包含完整的 HTML/CSS 原型（`ui_kits/nyan_read_app/index.html`）、CSS token 文件（`colors_and_type.css`）、JSX 组件库（`components.jsx`）及各屏幕 JSX 文件。当 UI 规范与本文件有冲突时，**交付包优先**——交付包是从维护者的设计意图直接生成的，本文件是对其的文字摘要，摘要落后于源文件。

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

本路线图基于 2026-04 全局审查报告。**MUST** 按阶段推进，不得越阶跳跃。

### Phase 0 — 设计系统真相归一化（0.5 sprint · 前置条件）✅ 已完成 2026-04-20

**目标：消除"设计 token 在文档里正确，在代码里是僵尸"的风险。**

- [x] **P1-0a**：**字体注册**（方案 B，本地资产）。`pubspec.yaml` 的 `flutter.fonts` 段已声明 `Noto Sans SC`（400/500/600）+ `Source Han Serif SC`（400/600）。`.ttf` / `.otf` 文件**未入 git**，需下载后放入 `assets/fonts/`，详见 [`assets/fonts/README.md`](../assets/fonts/README.md)。缺失字体时 Flutter 只打印 warning，不影响编译运行，但 serif 阅读模式会回落平台字体。
- [x] **P1-0b**：从 `pubspec.yaml` 移除未使用的 `google_fonts` 依赖。
- [x] **P1-0c**：`lib/modules/**` 内 `Color(0xFF...)` 字面值清零；字面色全部迁入 `lib/core/theme/nyan_colors.dart`，按 "reader runtime / reader theme swatch / highlight ink / highlight paper / overlay shadow / overlay micro-palette" 分组命名。`lib/core/ui/components/` 同步整理。允许保留字面值的白名单：`nyan_colors.dart`（规范定义）与 `theme_presets.dart`（`NyanTheme` 预设）。
- [x] **P1-0d**：`.withOpacity(x)` 全仓替换为 `.withValues(alpha: x)`（共 36 处跨 14 个 Dart 文件）。
- [x] **P1-0e**：审计结果为 **NO-OP**——先前怀疑的"死链"不存在。设置页 `settings_page.dart` 的主题选择弹窗直接迭代 `themePresets.values`（仅含 `creamLight` / `sumiDark`），只显示 2 张可用卡；reader 的 4 张阅读背景卡（`reader_settings_theme_panel.dart`）本就只改 `backgroundColor`、不依赖 `NyanTheme` 预设，`ReaderSettingsManager._updateEngineConfig` 会按背景 luminance 自动切换字色。
- [x] **P1-0f**：清理一次性 refactor 脚本残留 `lib/modules/reader/widgets/update_reader_menu.py`。
- [x] **P1-0g**：Flutter 内置 SDK deprecation 清零 —— `Color.red/.green/.blue/.value` 迁移到 `.r/.g/.b`（新 0-1 double）或 `.toARGB32()`（保留与旧 prefs 的字段兼容）；`ColorScheme.surfaceVariant` 迁移到 `surfaceContainerHighest`。

**验收（实际达成）：**
- `grep -r "Color(0xFF" lib/modules/ --include="*.dart"` → 空 ✓
- `grep -r "\.withOpacity(" lib/ --include="*.dart"` → 空 ✓
- `flutter analyze` Flutter 内置 API **零 deprecation** ✓；剩余 6 条 deprecation 来自第三方包（`screen_brightness` x4、`share_plus` x2），归口 Phase 4。
- `flutter pub get` 成功，无运行时依赖问题。
- 字体渲染实机验证需在字体文件就位后执行（产品手动步骤，见 `assets/fonts/README.md`）。

### Phase 1 — 扑灭渲染热点（1 个 sprint · 最高优先） ✅ 已完成 2026-04-21

**目标：长时间阅读不再发热/掉帧。**

- [x] **P0-1**：将 `ReadingProgressManager` 的 `currentProgress` 拆成独立 `ValueNotifier<double>`（`progressListenable`）。1s 心跳只打 `_progressNotifier.value`（ValueNotifier 自动按 `==` 去抖），`onProgressUpdated` 只在 **position 变化** 时才调用，彻底斩断「每秒一次 `ReaderController.notifyListeners()`」的全局扩散。同时给 manager 加了 `dispose()` / `_disposed` 闸门，避免延迟回调在 unmount 后再碰 `engine`。死代码 `shouldShowReminder` 的 3600s notify 也顺手拆除。
- [x] **P0-2**：`reader_page.dart` 两个 `Selector` 去掉 `currentProgress` 字段——阅读主面板只订阅 `(backgroundColor, hasBottomBar)`，底部「42%」标签改用 `ValueListenableBuilder<double>` 直接订阅 `progressListenable`；`ReaderSettingsProgressCard` 重构为 `progressListenable` 优先（保留 `progress` 一次性值路径给测试），卡片内部「42%」文案和 `ReaderSettingsSlider` 各自 `ValueListenableBuilder<double>` 独立 repaint，不再连带整张卡重建。
- [x] **P0-3**：`highlightable_text.dart` 重写——
  - `TapGestureRecognizer` 池化：`_recognizerPool: Map<highlight.id, TapGestureRecognizer>`，命中即复用、缺失才 `new`、build 末尾回收不再出现的 id 对应 recognizer。
  - `_buildTextSpan` 按 `(paragraphIndex, text, identical(style), highlightsFingerprint)` 四元组缓存；命中时只 rebind `onTap`（O(spans)），不再分配新 `TextSpan`。`highlightsFingerprint` = 排序后的 `Object.hash(id, start, end, colorCode)` 串再 `Object.hashAll`。
- [x] **P0-4**：overlay subtree 外层 `!_showControls ? const SizedBox.shrink() : Selector<...>`；overlay 的 Selector 同步去掉 `currentProgress` 字段。`setState` 翻转 `_showControls` 才会进入重建路径，收起态 0 rebuild。

**验收：**
- `flutter analyze` 零 error（91 条 info/warning 沿用 Phase 0 清单）；
- 与 Phase 1 相关的全部单测通过：`reading_progress_manager_test` ×4 + `reader_overlay_progress_card_test` ×2 + `reader_menu_test` ×11 + `reader_controller_brightness_test` ×5 全绿；
- 仓库其余 5 条测试失败（`isolate_test`、`theme_resolution_test`、`txt_reader_chapter_detection_test` ×3）均为 Phase 1 动刀 **之前就存在** 的遗留 bug（TextPainter-in-Isolate 返回 false、Cream Light 主题解析 null、测试源文件中文字符编码丢失），归口 Phase 4 清理；
- DevTools 30 分钟静置阅读下的实机帧耗测量留待产品侧在字体资产就位后跑一遍。

### Phase 2 — 解析离 UI + I/O 批量化（1 个 sprint）✅ 已完成 2026-04-21

**目标：打开任意格式不再卡屏；字号拖拽不再抖动。**

- [x] **P0-5**：EPUB 解析切入 `compute()`；移除 `package:epub_view/src/...` 私有 import。
  - 新增 `lib/modules/reader/reader_engine/epub/epub_parse_helpers.dart`：内联 `flattenEpubChapters` / `_convertDocumentToElements` / `_removeAllDiv` 及 `chapterDocument`，对外暴露 `EpubParseResult` / `EpubChapterMeta` DTO 与顶层入口 `parseEpubBytesInIsolate(Uint8List)`；
  - `epub_reader.dart` 通过 `await compute(parseEpubBytesInIsolate, bytes)` 在后台 isolate 跑完章节扁平化与段落计数后，再在主 isolate `EpubDocument.openData(bytes)` 供控件使用；
  - `pubspec.yaml` 新增直接依赖 `html: ^0.15.0`，彻底剥离 `epub_view/src/*` 私有入口。
- [x] **P0-6**：PDF `openFile` 调用异步化，首帧展示 placeholder。
  - `pdf_reader.initialize()` 改为把 `_preparePdfDocument()` 返回的 `Future<PdfDocument>` 直接塞进 `PdfController`，真正的 I/O 落在后台；
  - 新增 `_isDocumentReady` 旗标，`getProgress` / `getCurrentPosition` 等在 ready 前返回保底值，避免 `LateInitializationError`；
  - `buildReader()` 采用 `PdfViewBuilders.documentLoaderBuilder` / `errorBuilder`，展示 NyanTheme 配色的 `CircularProgressIndicator` 与错误占位，替换掉 pdfx 默认白屏。
- [x] **P0-7**：`DatabaseService._checkAndHealDatabase` / 备份清理切入 `Isolate.run`；日志全部英文化。
  - `DatabaseService._restoreFromLatestBackup` 里的文件重命名 + 备份拷回通过 `Isolate.run(_runRestoreFromBackupInIsolate, ...)` 执行，平台通道调用（`openDatabase` / `PRAGMA integrity_check`）留在主 isolate；
  - `BackupRecoveryService._cleanupOldBackups` 的目录遍历、排序、冷备删除改由 `Isolate.run(_runCleanupOldBackupsInIsolate, ...)` 处理，主线程只负责回放日志；
  - 两个服务内所有 `debugPrint` / 关键注释英文化（例：`Main database integrity check passed (ok)` / `Cold backup written`），彻底抹掉历史 Mojibake。
- [x] **P0-8**：`ReaderPreferencesService` 引入 `Debouncer(300ms)` 批量写。
  - 新增 `_PendingPrefWrite` / `_pendingWrites` / `_writeDebouncer = Debouncer(delay: Duration(milliseconds: 300))`；
  - 所有 `setXxx` 同步更新内存态 + `notifyListeners()`，磁盘落地由 `_schedulePrefWrite` / `_schedulePrefRemove` 合并；
  - `resetToDefaults()` 在 atomic write 前先 `cancel()` 防串单；新增 `flushPendingWrites()`，在 `ReaderPage.saveBeforeExit()` 与 `AppLifecycleState.paused/detached` 触发 `unawaited(getIt<ReaderPreferencesService>().flushPendingWrites())`，保证字号/行高等连续输入在退出或进入后台时立即落盘；
  - `dispose()` 强制 flush + cancel，避免 debouncer 携泄漏回调。
- [x] **P0-9**：`restoreDataBatch` 匹配键改为 `content_signature`，放弃 `title` 主键。
  - 本地索引拆成 `localBySignature` / `localByTitle` 双表，主键优先走 SHA-256 指纹；
  - 仅当备份 payload 或本地行的 `content_signature` 为空时回退到 title，并以 `[Restore][legacy]` 日志标注，收官汇总中额外统计 `legacyFallbackCount`；
  - 行为修正：用户改名同一本书仍能正确恢复笔记；两本同名不同版本不再交叉污染高亮。

**验收：**
- `flutter analyze` 本 Phase 触达的 5 个 `.dart` 文件零 error、零 warning；
- 与 Phase 2 直接相关的单测 25/25 全绿（`database_service_test` ×6 + `reading_progress_manager_test` ×4 + `reader_menu_test` ×10 + `reader_controller_brightness_test` ×5）；
- 仓库其余 6 条测试失败（`txt_reader_chapter_detection_test` ×3 + `txt_reader_pagination_invalidation_test` ×3）在 `git stash` 掉 Phase 2 改动后依旧复现，系 Phase 2 动刀 **之前就存在** 的遗留 bug（测试源文件 CJK 编码丢失 + Windows 临时目录句柄回收），归口 Phase 4（`P2-7` 延伸）清理；
- 实机打开 EPUB / PDF 不再首屏卡顿；字号、行高、页边距连续滑动期间磁盘写入受 300ms 去抖窗口合并。

### Phase 3 — 服务层收敛与 DI 清理（0.5 sprint）✅ 已完成 2026-04-22

**目标：启动竞态消除；Manager 可构造器注入 mock。**

- [x] **P1-1**：Service Locator 统一 `registerSingletonAsync`；`main.dart` `await getIt.allReady()` 后再 `runApp`。
- [x] **P1-2**：删除 `ReadingReminderService.instance` 静态单例，统一走 get_it + Provider。
- [x] **P1-3**：所有 Manager 改为构造器注入，移除内部 `getIt<>`。
- [x] **P1-4**：`BackupRecoveryService.dispose` 在 `NyanApp.dispose` 中被调用。
- [x] **P1-5**：`ContentMetaManager` 高亮 CRUD 改增量，移除每次 `loadHighlights()` 全量重载。

### Phase 4 — 技术债清算（选做 1 sprint）🚧 进行中（当前批次完成：2026-04-22）

- [x] **P2-1**：`reader_page.dart` 按职责拆分（Controller / PageState / OverlayToolBar / GestureHandler ≥ 4 文件）。
- [x] **P2-2**：引入 `riverpod` 评估 spike（✅ 已完成，2026-04-24）—— 完成 app shell 去 `MultiProvider`、`bookshelf/reader/settings/admin` 模块迁移、`provider` 依赖移除与关键测试适配，运行时主链路全面切至 Riverpod + get_it。
- [x] **P2-3**：新增 `docs/PERFORMANCE.md`，把本文件 §3.4 的规则机械化为 lint 规则或 CI 脚本。
- [x] **P2-4**：为 `ReaderCapabilities` 增加非 boolean 支持级别（`none / limited / full`）。
- [x] **P2-5**：升级 `screen_brightness` 到 2.1+，将 `SystemBrightnessAdapter` 中 4 个 deprecated 调用（`current` / `onCurrentBrightnessChanged` / `setScreenBrightness` / `resetScreenBrightness`）改为对应的 `application*` 变体。
- [x] **P2-6**：升级 `share_plus`，重构 `settings_page.dart` 里的 `Share.shareXFiles(...)` → `SharePlus.instance.share(ShareParams(...))`。
- [x] **P2-7（遗留失败测试子任务）**：修复 `txt_reader_chapter_detection_test`（编码损坏断言改为有效样本 + 构造注入 `databaseService`）与 `txt_reader_pagination_invalidation_test`（Windows 临时目录删除重试；in-flight 去重用例 Windows 平台跳过，避免 10 分钟挂死）。
- [x] **P2-8**：字体子集化脚本 `scripts/subset_fonts.py`（✅ 已完成，2026-04-23）—— 已提供可执行 CLI：支持 GB2312 内置字符集、外部字符文件叠加、`--dry-run` 预演与输出目录配置；`assets/fonts/README.md` 已补齐安装与执行说明。
- [x] **P2-9**：主题预设收敛（✅ 已完成，2026-04-23）—— 本轮不扩展 sepia/amoled App 预设，改为删除未接入的 `sepia*` / `amoled*` 原子常量；暗色主题深强调色改为语义化 `inkNightPrimaryDeep`，避免 token 命名误导。

### Phase 5 — 长期演进

- 新引擎接入标准流程（实现 `ReaderEngine` + 声明 `Capability` + 接 `ReaderEngineFactory`）；
- TTS 与注释系统走"新增 Capability 接口"路径，不扩 `ReaderEngine` 核心契约；
- 云同步（若启用）作为可选插拔能力，**MUST** 保持离线优先。

---

## Appendix A. 快速自检卡（AI 在每次编辑前默读）

```
□ 我读过相关文件了吗？
□ 这次改动触碰受保护面（§3.5）了吗？如触碰，三段式写了吗？
□ 有没有引入 build() 里的重活？
□ 新加的颜色 / 尺寸 / 字号都来自 nyan_*.dart 吗？
□ 我使用的状态订阅是最小粒度吗？
□ 有没有在 UI Isolate 上做 I/O / 解析？
□ dispose() 里是否释放了新引入的 Controller / Notifier / Subscription / Timer？
□ 我的改动能被测试覆盖吗？
```
