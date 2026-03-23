// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get settingsTitle => '设置';

  @override
  String get appearance => '外观';

  @override
  String get themePreset => '预设主题';

  @override
  String get readingSettings => '阅读设置';

  @override
  String get pageTurnMode => '翻页模式';

  @override
  String get pageTurnModeTap => '点击翻页';

  @override
  String get pageTurnModeSwipe => '滑动翻页';

  @override
  String get pageTurnModeDisabled => '禁用翻页';

  @override
  String get pageTurnTap => '点击';

  @override
  String get pageTurnSwipe => '滑动';

  @override
  String get pageTurnDisabled => '禁用';

  @override
  String get pageAnimation => '翻页动画';

  @override
  String get pageAnimationFade => '平滑淡入淡出';

  @override
  String get pageAnimationPaper => '仿真纸张效果';

  @override
  String get pageAnimationNone => '无动画';

  @override
  String get pageAnimFade => '淡入淡出';

  @override
  String get pageAnimPaper => '仿真';

  @override
  String get pageAnimNone => '无';

  @override
  String get readingReminder => '阅读提醒';

  @override
  String get readingReminderSubtitle => '提醒我休息一下';

  @override
  String get reminderInterval => '提醒间隔';

  @override
  String reminderMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get dataManagement => '数据管理';

  @override
  String get deleteFilesOnRemove => '删除时移除文件';

  @override
  String get deleteFilesOnRemoveSubtitle => '删除书籍时同时删除本地文件';

  @override
  String get lockPrivateShelf => '锁定私密书架';

  @override
  String get tts => 'TTS (语音朗读)';

  @override
  String get ads => '广告';

  @override
  String get adsSubtitle => '显示广告 (免费版)';

  @override
  String get upgradeToPro => '升级到专业版';

  @override
  String get adminPanel => '管理面板';

  @override
  String get language => '语言';

  @override
  String get bookDetails => '书籍详情';

  @override
  String get title => '标题';

  @override
  String get author => '作者';

  @override
  String get format => '格式';

  @override
  String get privacy => '隐私';

  @override
  String get privateShelf => '隐私书架';

  @override
  String get publicShelf => '公开书架';

  @override
  String get readingProgress => '阅读进度';

  @override
  String get added => '添加时间';

  @override
  String get lastRead => '最后阅读';

  @override
  String get fileLocation => '文件位置';

  @override
  String get startReading => '开始阅读';

  @override
  String get copyPath => '复制路径';

  @override
  String get filePathCopied => '文件路径已复制到剪贴板';

  @override
  String get fileExists => '文件存在';

  @override
  String get fileNotFound => '文件未找到';

  @override
  String get unknown => '未知';

  @override
  String get never => '从未';

  @override
  String get backToBookshelf => '返回书架';

  @override
  String get retry => '重试';

  @override
  String get reportToDeveloper => '报告给开发者';

  @override
  String get showTechnicalDetails => '显示技术细节';

  @override
  String get hideTechnicalDetails => '隐藏技术细节';

  @override
  String get couldNotLaunchEmail => '无法启动邮件客户端';

  @override
  String failedToOpenEmail(String error) {
    return '打开邮件失败: $error';
  }

  @override
  String get addNote => '添加笔记';

  @override
  String get editNote => '编辑笔记';

  @override
  String get addNoteHint => '在此添加您的笔记...';

  @override
  String get delete => '删除';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get selected => '已选择';

  @override
  String get viewDetails => '查看详情';

  @override
  String get moveToPublic => '移至公开书架';

  @override
  String get moveToPrivate => '移至隐私书架';

  @override
  String get selectAll => '全选';

  @override
  String get deselectAll => '取消全选';

  @override
  String get appTitle => 'Nyan Read ฅ^•ﻌ•^ฅ';

  @override
  String get enjoyReading => '享受阅读时光';

  @override
  String get listView => '列表视图';

  @override
  String get gridView => '网格视图';

  @override
  String get sort => '排序';

  @override
  String get sortBy => '排序方式';

  @override
  String get sortOrderAsc => '升序';

  @override
  String get sortOrderDesc => '降序';

  @override
  String get lastReadAsc => '最近阅读升序';

  @override
  String get lastReadDesc => '最近阅读降序';

  @override
  String get addedAsc => '添加时间升序';

  @override
  String get addedDesc => '添加时间降序';

  @override
  String get titleAsc => '书名升序';

  @override
  String get titleDesc => '书名降序';

  @override
  String get lockPrivacyShelf => '锁定隐私书架';

  @override
  String get unlockPrivacyShelf => '解锁隐私书架';

  @override
  String deleteBooksTitle(int count) {
    return '⚠️ 删除 $count 本书？';
  }

  @override
  String get actionCannotBeUndone => '此操作无法撤销。';

  @override
  String get alsoDeleteLocalFiles => '同时删除本地文件';

  @override
  String deletedBooks(int count) {
    return '已删除 $count 本书';
  }

  @override
  String movedBooks(int count, String shelf) {
    return '已将 $count 本书移至$shelf书架';
  }

  @override
  String get emptyPrivateShelf => '这个私密空间还是空的。\n在公开书架选择书籍，点击锁定图标即可移动到这里。';

  @override
  String get emptyShelfInstructions => '你的书架还是空的！\n点击下方的 + 按钮导入书籍。';

  @override
  String get importFiles => '导入文件';

  @override
  String get importBooksTitle => '导入书籍';

  @override
  String get importBooksSubtitle => '从设备中选择文件，加入你的书架。';

  @override
  String get importBooksEmptySubtitle => '从设备中导入第一本书，开始阅读。';

  @override
  String get importFilesSubtitle => '选择一个或多个受支持的电子书文件。';

  @override
  String get supportedFormats => '支持的格式';

  @override
  String get supportedFormatsSubtitle => '目前支持 TXT、EPUB 和 PDF。';

  @override
  String get supportedFormatsDescription =>
      'Nyan Read 目前支持从设备中导入 TXT、EPUB 和 PDF 文件。';

  @override
  String get importingBooksTitle => '导入中';

  @override
  String get importingBooksSubtitle => '正在将你选择的文件加入书架...';

  @override
  String importedBooks(int count, String shelf) {
    return '已将 $count 本书导入$shelf书架！';
  }

  @override
  String get emptyShelfMessage => '这里空空如也，导入一本书吧？';

  @override
  String get privacyShelfLocked => '隐私书架已锁定';

  @override
  String get setPrivacyPassword => '设置隐私密码';

  @override
  String get password => '密码';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get passwordsDoNotMatch => '密码不匹配';

  @override
  String get unlockPrivacyShelfTitle => '解锁隐私书架';

  @override
  String get invalidPassword => '密码错误';

  @override
  String get unlock => '解锁';

  @override
  String get fontSize => '字体大小';

  @override
  String get lineHeight => '行高';

  @override
  String get themeCream => '奶油';

  @override
  String get themeSepia => '棕褐';

  @override
  String get themeSumi => '墨色';

  @override
  String get themeCharcoal => '炭黑';

  @override
  String get tableOfContents => '目录';

  @override
  String get addBookmark => '添加书签';

  @override
  String get bookmarks => '书签';

  @override
  String get highlightsAndNotes => '高亮与笔记';

  @override
  String allBooksInLibrary(int count) {
    return '所有书籍已在书库中（已跳过 $count 个重复项）。';
  }

  @override
  String duplicatesSkipped(int count) {
    return '已跳过 $count 个重复项。';
  }

  @override
  String get noChaptersDetected => '未检测到章节';

  @override
  String chapterCount(int count) {
    return '$count 章';
  }

  @override
  String chapterName(int index) {
    return '第 $index 章';
  }

  @override
  String bookmarksTitle(int count) {
    return '书签 ($count)';
  }

  @override
  String get noBookmarksYet => '暂无书签';

  @override
  String bookmarkName(int index) {
    return '书签 #$index';
  }

  @override
  String failedToDeleteBookmark(String error) {
    return '删除书签失败：$error';
  }

  @override
  String notesAndHighlightsTitle(int count) {
    return '笔记与高亮 ($count)';
  }

  @override
  String get noHighlightsYet => '暂无高亮';

  @override
  String get longPressToCreateHighlight => '长按文本创建高亮';

  @override
  String highlightName(int index) {
    return '高亮 #$index';
  }

  @override
  String paragraphIndex(int index) {
    return '段落 $index';
  }

  @override
  String get themeCreamLight => '奶油白';

  @override
  String get themeSumiDark => '墨色黑';

  @override
  String get timeToday => '今天';

  @override
  String get timeYesterday => '昨天';

  @override
  String get timeThreeDaysAgo => '3天前';

  @override
  String get timeSevenDaysAgo => '7天前';

  @override
  String get timeLongAgo => '很久以前';

  @override
  String get neverRead => '从未阅读';

  @override
  String get errorFileNotFound => '这本书好像迷路了。\n找不到源文件，它可能已被移动或删除。';

  @override
  String get errorUnsupportedFormat => 'Nyan 还不能读取这种格式。\n当前暂不支持该文件类型。';

  @override
  String get errorParseFailed => '书页像是粘在一起了。\n文件解析失败，可能已经损坏。';

  @override
  String get errorUnknown => '发生了意外错误。\n请稍后再试。';

  @override
  String get emptyShelfTitle => '书架正在等待新的故事';

  @override
  String get emptyShelfSubtitle => '导入一本书开始阅读';

  @override
  String get exportData => '导出阅读数据';

  @override
  String get exportDataSubtitle => '将书籍、高亮和书签备份为 JSON';

  @override
  String get saveToDevice => '保存到设备';

  @override
  String get saveToDeviceSubtitle => '选择设备上的文件夹';

  @override
  String get shareVia => '通过以下方式分享';

  @override
  String get shareViaSubtitle => 'Gmail、Drive、Quick Share 等';

  @override
  String get importData => '导入阅读数据';

  @override
  String get importDataSubtitle => '从之前导出的 JSON 文件恢复';

  @override
  String importSuccess(int count) {
    return '成功恢复 $count 本书！';
  }

  @override
  String importFailed(String error) {
    return '导入失败：$error';
  }
}
