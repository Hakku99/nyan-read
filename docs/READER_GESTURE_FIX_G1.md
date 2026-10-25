# G1：正文起始横向滑动

2026-10-25 独立整理，基于第 08 项 `90bfdf9`，不包含 G2 或第 13 项绘制候选。

正文的复合点击/横向拖动识别器会赢得手势竞争，使父层收不到普通横拖。
`ReaderSelectableText` 使用 Flutter 公共 `EditableText` 和
`TextSelectionGestureDetectorBuilder`，将无选区的普通触摸横拖转交阅读页现有的
方向、速度和距离判断。长按、选字拖动、鼠标选择及纵向滚动保留原路径。
`ReaderTextGestures` 只传递 UI 回调，不持有阅读位置；无引擎导航契约或数据库变更。

G1 保留原点击转发机制；快速连点和选字冲突由随后的 G2 提交处理。
回滚 G1 应先撤销依赖它的 G2，再撤销文本组件与阅读页接线，不需数据迁移。

拆分时恢复已保存的 G1 检查点，移除第 13 项目标截图参数与两项专属测试，
重新验证实际提交候选：**156 项通过（含 10 项手势检查）、4 项既有 Windows 跳过**。
静态检查只有两项既有 `home_screen.dart` 提示；设计 token 门禁仍有既有问题，无新增业务字面颜色。
独立回归结果记录于 `.dart_tool/gesture-g1-isolated-tests.log`；
静态检查记录于 `.dart_tool/gesture-g1-isolated-analyze.log`。

2026-10-23 的完整设备验证使用 G1＋G2＋13 联合版本，不能当作 G1 单独的设备验证。
本次拆分不重新宣称真机、iOS 实机、系统边缘或性能验收完成。
