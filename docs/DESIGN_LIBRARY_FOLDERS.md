# 设计蓝图：书库文件夹（目录树授权）+ 书籍管理

> 状态：**Phase A gate 已通过（2026-07-18 模拟器会话，见 §10）**，原生四方法已实现并实测
> 对应审查问题：`CODEBASE_ANALYSIS.md` §6 #3（persistable URI 配额）
> 动工前提：schema 变更（Phase C）触发 §3.5-3 三段式；上架前补一次真机 sanity pass（OEM 皮肤 + 真 SD 卡 + 性能面）

---

## 1. 背景与研究结论

Android 持久化 URI 授权有平台配额：`MAX_PERSISTED_URI_GRANTS`（AOSP `UriGrantsManagerService` 内部常量，**官方文档不写**）——Android 11 前 128，11 起 512。当前"逐文件持授权"方案下，大书库会撞上限。超限行为**已实测定论（§10）**：`takePersistableUriPermission` 永不报错，系统静默 LRU 剪枝回收最旧授权（AOSP 源码读得对，CommonsWare"新请求失败"的说法错）。

**选定方向：`ACTION_OPEN_DOCUMENT_TREE` 目录树授权。**

- 一个"书库文件夹"授权 = 1 个配额名额，递归覆盖整棵子树（含未来新增文件）；
- 子文件的 child document URI 直接可被 `openInputStream` 打开，**不占配额**——现有原生读取方法零改动；
- 完全满足"不复制、只引用"的产品约束；零 Play 政策风险（SAF 是官方推荐路径）。

否决的替代项：`MANAGE_EXTERNAL_STORAGE`（Play 政策高危，官方劝退非文件管理器类）；`READ_MEDIA_*`/MediaStore（scoped storage 下不覆盖非媒体文档）。

已知平台限制（写进 UI 引导文案）：API 30+ 不能选存储根目录、SD 卡根、`Download` **根目录**、`Android/data|obb`——但 **Download 的子目录可以正常授权**（§10 实测）。引导用户使用 `Documents/Books` 类子目录即可。

参考：
- https://developer.android.com/training/data-storage/shared/documents-files
- https://developer.android.com/about/versions/11/privacy/storage
- https://commonsware.com/blog/2020/06/13/count-your-saf-uri-permission-grants.html
- AOSP `frameworks/base/services/core/java/com/android/server/uri/UriGrantsManagerService.java`

## 2. 数据模型

### 2.1 来源（零 schema 变更）

- `BookSourceType` 新增 `androidTreeUri = 'android_tree_uri'`（加入 `_knownValues`）；
- `sourceLocator` 存 child document URI 全串（`content://…/tree/<treeId>/document/<childId>`）——树 ID 内嵌于 URI，"属于哪个文件夹"靠解析 locator 前缀，无需新列；
- **已授权文件夹的注册表 = 系统 `getPersistedUriPermissions()` 本身**，不建表、不存偏好——单一真相源在系统侧；
- 指纹去重：`BookImportFingerprint` 的 switch 把 `androidTreeUri` 按 `androidContentUri` 同路处理（采样走临时副本），指纹字节规则不变（§3.5-5 仅加法扩展）。

### 2.2 书籍管理（schema v9 → v10，触发 §3.5-3）

```sql
ALTER TABLE books ADD COLUMN finished_at INTEGER;        -- null = 未标记读完
ALTER TABLE books ADD COLUMN archived INTEGER DEFAULT 0; -- 1 = 归档，主书架不显示
```

- 无回填需求（默认值即正确语义）；增量 ALTER，符合迁移纪律；
- 书架热索引升级为含 `archived` 维度（迁移内重建 `idx_books_privacy_*`）；
- 阅读状态为**推导值**，不落库：`已读完` = `finished_at != null`；`在读` = 进度 >0 且未读完；`未读` = 进度 ==0。

## 3. 原生层（`MainActivity.kt`，全部走既有 `ioExecutor`）

| 方法 | 职责 |
|---|---|
| `pickLibraryFolder()` | 发 `ACTION_OPEN_DOCUMENT_TREE`（经典 `onActivityResult`，requestCode 取高位避撞插件），成功即 `takePersistableUriPermission`，返回 tree URI + 显示名 |
| `listTreeDocuments(treeUri)` | `buildChildDocumentsUriUsingTree` 递归枚举；MIME **加**文件名后缀双重过滤（部分 provider 报 octet-stream）；防御上限：深度 ≤10、条目 ≤2000 |
| `listPersistedTreePermissions()` | 过滤出 tree 授权 `[{uri, displayName}]` + 授权总数（兼作配额水位） |
| `releasePersistedPermission(uri)` | 归还授权——移除文件夹用；也供遗留逐文件书删除时归还配额 |

## 4. Dart 层编排

- **导入**：`ImportBookSheet` 加"添加书库文件夹"行（Android-only）→ pick → scan → 复用现有逐文件导入循环（指纹去重、私密归属、toast 全部复用）；差异仅：跳过 `persistReadPermission`、sourceType 写 `androidTreeUri`。**全量自动导入**（已拍板），靠去重保证幂等；
- **重扫**：文件夹管理页每行"重新扫描"→ 重跑 scan+import，只进新书；
- **访问**：`BookSourceAccess` 三个 switch 各加一个 case 转发 `androidContentUri` 分支（`isUriReadable`/`copyUriToTempFile` 通吃 child URI）。

## 5. 书籍管理与书架防臃肿

### 5.1 阅读状态 filter（已拍板）

- **位置**：书架吸顶工具栏（Public/Private 切换器）下方水平 chip 排：`全部 · 在读 · 未读 · 已读完`；
- **样式**：§4.3 chip 法条原样（`NyanRadius.chip` 12pt、outline-on-select），零新设计资产；
- **实现**：SQL 只排除归档（`WHERE archived = 0`），状态筛选在 `BookshelfViewModel` 内存过滤（列表本就整份在 VM）；
- **持久化**：选中 filter 存 `BookshelfPreferencesService`，公开/私密 tab 各记各的；
- 未读书无 `last_read_at`，现有 `last_read_at DESC` 排序天然沉底；各 filter 配 contextual 空状态。

### 5.2 读完与归档

- **标记读完**：手动为主（详情页/长按），进度 ~98% 时一次性**提示**标记（不自动改——估算进度不可靠）【默认取提示式，待维护者最终确认】；
- **归档**：`archived=1`，主书架消失，入口在排序 sheet（低频，计数显示）【默认取排序 sheet，待确认】；标记读完时顺带询问归档；多选模式加批量归档；
- **语义分工**：删除 = "不要了"（现有延迟删除+undo）；归档 = "读完收起来"（进度/书签/高亮/统计全保留，可取消归档）。

### 5.3 铁律：归档不动文件

- 归档是纯 DB 标记——**app 永不移动/改名/复制用户文件**。树授权下移动文件会换 document ID 导致 URI 失效，"替用户整理文件"是自毁行为；
- 用户自行挪文件的兜底：重扫 + **签名自愈重绑**（Phase D）——新文件签名与"源不可用"旧书一致 → 更新旧书 locator 而非新建条目，进度书签高亮无缝跟随。

### 5.4 按文件夹分组（Phase D）

树来源 locator 内嵌 tree ID → 零 schema 成本做"按书库文件夹分组"视图。用户自己的文件夹结构即书架分组。**自建标签/收藏夹 v1 不做**，等真实反馈。

## 6. 防护与遗留修复

- **配额水位**：逐文件导入路径检查授权总数 >100（兼容老设备 128 上限）→ toast 引导改用文件夹；
- **遗留归还**：删除 `androidContentUri` 书籍时调 `releasePersistedPermission`（去重保证 URI 不共享，安全）——修复现状配额只进不出；
- **移除文件夹**：警告"N 本书将不可用"（locator 前缀 LIKE 计数）+ 提供"同时移出这些书"。

## 7. 分期

| 阶段 | 内容 | 验证 |
|---|---|---|
| A | 原生四方法 + `androidTreeUri` + 访问路径 case | Kotlin 编译 + Dart 单测（normalize/去重/locator 解析）；**实机 gate**：pick→persist→枚举→读取全链路；超限真实行为（LRU vs 报错） |
| B | 导入入口 + 扫描导入循环 + **状态 filter chips**（全量导入体验前提） | 实机导入真实书库；重扫幂等 |
| C | 归档 + 读完标记 + 文件夹管理页 + 水位提示 + 遗留归还 + schema v10 | 迁移单测；实机移除授权降级正确 |
| D（可选） | 桌面端同 UX（`dart:io` 扫描、file_path 来源）；签名自愈重绑；按文件夹分组 | 单测可覆盖 |

## 8. 风险与回滚

- 全程加法（新 sourceType/原生方法/UI 入口 + 两列增量 ALTER），既有书行为不变；回滚 = 隐藏入口，已导入树书只要授权在就可读；
- 最大不确定性：第三方 DocumentsProvider 兼容性——首发只认 `com.android.externalstorage.documents`，其它 provider 降级隐藏树入口；可挂 `FeatureManager` admin flag 灰度；
- 受保护面：§3.5-3（v10 迁移，动工前三段式）、§3.5-5（指纹加法扩展，单测锁重复导入）。

## 9. 实机验证清单（Phase A gate）

1. 超限真实行为：LRU 静默回收 vs `takePersistableUriPermission` 失败；
2. tree child URI 经 `openInputStream` 读取（现有 `copyUriToTempFile` 路径）全链路；
3. 大目录（500+ 文件、多层嵌套）枚举耗时与上限行为；
4. `releasePersistableUriPermission` 归还后配额计数变化；
5. 树内移动/改名文件后 child URI 失效表现（自愈重绑的前提验证）；
6. SD 卡上的书库文件夹（reliable volume 行为）。

## 10. Gate 验证结果（2026-07-18 · 模拟器 API 36 / Android 16 · SAF Probe）

驱动工具：admin panel → Dev tools → SAF Probe（`saf_probe_page.dart`，dev-only）。

| # | 结论 | 证据 |
|---|---|---|
| 1 | **通过 · 定论**：600 次超限 persist 全部"成功"零报错，系统静默 LRU 剪到 512；**同会话内运行时授权掩盖损失（读取照常成功），冷启动后被挤掉的 URI 才抛 `SecurityException`（Permission Denial）**——损失延迟显形，比预想更隐蔽 | `attempted=600 persisted=600 failed=0, grantCountAfter=512`；重启后 fixtures 读取 → Permission Denial |
| 2 | **通过**：树子文档 URI 走生产读取链路（`copyUriToTempFile`→`openInputStream`）畅通，读取层零改动的假设成立 | 树扫描出的 p1.txt/wx1.txt 内容原样读出 |
| 3 | **通过**：600 文件 307ms、9 文件（含二级嵌套）24-29ms，无截断；书库量级无性能顾虑 | scan 计时日志 |
| 4 | **通过**：单个/批量归还即时生效（512 个 <1s），二次清理幂等返回 0；授权不存在时 release 返回 false | `released 512 grants` → `total=0` |
| 5 | **通过**：树内 `mv` 后旧 child URI 抛 `FileNotFoundException`（包装为 PlatformException，可捕获不崩溃，落进现有"源不可用"降级）；重扫在新位置找回文件——签名自愈重绑（Phase D）前提成立 | move 前后 read/scan 日志 |
| 6 | **顺延真机**：模拟器无 reliable-volume SD；连同 OEM 皮肤（MIUI/ColorOS provider 私货）与真机性能面，留给上架前 sanity pass | — |

**对设计的三条修正**：
- Download **子目录**可授权（限制只针对根目录）——UI 引导文案放宽；
- 运行时授权会掩盖持久授权丢失 → **授权健康检查不能用读探测**（会话内会假阳性），必须比对 `getPersistedUriPermissions()` 列表与书籍 locator 的树前缀；
- "新授权永远成功、最旧的悄悄死"——水位防护（§6）从"建议"升级为**必须**，且逐文件删除时的配额归还（release-on-delete）同样必须。
