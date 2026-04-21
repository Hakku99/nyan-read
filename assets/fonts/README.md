# assets/fonts — 本地字体资产

本目录存放喵阅 UI 与阅读正文使用的中文字体。**字体文件未纳入 Git 仓库**（体积原因），需要手动下载后放到本目录。

## 1. 必需字体清单

| 文件名 | 用途 | 来源 | 许可证 |
|---|---|---|---|
| `NotoSansSC-Regular.ttf`  | UI 正文（w400）      | Google Fonts / Noto CJK | SIL OFL 1.1 |
| `NotoSansSC-Medium.ttf`   | UI 标签/按钮（w500） | Google Fonts / Noto CJK | SIL OFL 1.1 |
| `NotoSansSC-SemiBold.ttf` | UI 标题（w600）      | Google Fonts / Noto CJK | SIL OFL 1.1 |
| `SourceHanSerifSC-Regular.otf`  | 阅读 serif 正文（w400） | Adobe / 思源宋体 | SIL OFL 1.1 |
| `SourceHanSerifSC-SemiBold.otf` | 阅读 serif 强调（w600） | Adobe / 思源宋体 | SIL OFL 1.1 |

## 2. 下载方式

### Noto Sans SC（思源黑体 · Google 版）

从 Google Fonts 下载 OTF/TTF 子集，或直接使用 Adobe 的思源黑体（更全）：

- Google Fonts 页面：<https://fonts.google.com/noto/specimen/Noto+Sans+SC>
- GitHub 原始 OFL 字体仓库：<https://github.com/notofonts/noto-cjk/tree/main/Sans/SubsetOTF/SC>
  - 将 `NotoSansCJKsc-Regular.otf` / `Medium.otf` / `Semibold.otf` **重命名为** TTF 同名文件放入本目录（Flutter 同时支持 TTF 和 OTF，但 `pubspec.yaml` 里写的是 `.ttf` 扩展，要么改扩展名要么改 `pubspec.yaml`）。

### Source Han Serif SC（思源宋体）

- Adobe GitHub 官方仓库：<https://github.com/adobe-fonts/source-han-serif/tree/release/OTF/SimplifiedChinese>
  - 下载 `SourceHanSerifSC-Regular.otf` 与 `SourceHanSerifSC-SemiBold.otf`，直接放入本目录。

## 3. 包体预算

**只打包上述 5 个文件**，预计增量约 **+14–20 MB**（WOFF2 子集化可压到 ~6 MB，但目前项目未启用子集化流程）。

如需进一步压缩：
- 使用 `pyftsubset` 做中文常用字子集（GB2312 ~6700 字），单档可降到 ~2 MB；
- 相关脚本放到 `scripts/subset_fonts.py`（目前未实现，见 §6 Phase 4 tech-debt）。

## 4. 为什么不走 `google_fonts` 在线加载？

产品原则 §1.1 第 2 条：**离线优先，无网络请求**。
`google_fonts` 包会在首次使用时发起 HTTPS 请求下载字体到缓存目录，违反隐私不透传原则。已在 Phase 0 中从 `pubspec.yaml` 移除该依赖。

## 5. 缺失字体时的行为

- **编译**：不会失败。`pubspec.yaml` 里的 `fonts:` 段引用不存在的文件时，`flutter build` 只打印 warning。
- **运行**：Flutter 回落到平台 CJK 默认字体：
  - Android：Noto Sans CJK SC（系统预装）
  - iOS：苹方（PingFang SC）
  - Windows：微软雅黑
- **副作用**：`Source Han Serif SC`（serif 阅读模式）在所有平台上**都无默认回落**，阅读设置里选 serif 会显示 sans 字体。

## 6. 验证字体已生效

```bash
flutter clean
flutter pub get
flutter run
```

打开 App 后，主界面任意中文文本应显示为 Noto Sans SC（字形特征：CJK 统一汉字字面饱满、"永"字笔画均匀）。若仍为苹方/微软雅黑，说明字体文件未放对位置或重命名错误。
