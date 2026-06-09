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
  String get themePresetSubtitle => '阅读时的 Nyan Read 外观';

  @override
  String get readingSettings => '阅读设置';

  @override
  String get reading => '阅读';

  @override
  String get readerQuickProgressSubtitle => '章节跳转与阅读位置';

  @override
  String get readerQuickToolsSubtitle => '书签、笔记与完整设置';

  @override
  String get readerQuickOpenFullSettings => '全部设置';

  @override
  String get readerMenuBackToQuick => '快捷';

  @override
  String get readerEdgeBrightnessOn => '左缘滑动调亮：开';

  @override
  String get readerEdgeBrightnessOff => '左缘滑动调亮：关';

  @override
  String get pageTurnMode => '翻页模式';

  @override
  String get pageTurnModeSubtitle => '阅读时翻页的方向';

  @override
  String get pageTurnModeTap => '点击翻页';

  @override
  String get pageTurnModeSwipe => '滑动翻页';

  @override
  String get pageTurnModeDisabled => '禁用翻页';

  @override
  String get pageTurnModeLeftRight => '左右翻页';

  @override
  String get pageTurnModeUpDown => '上下翻页';

  @override
  String get pageTurnTap => '点击';

  @override
  String get pageTurnSwipe => '滑动';

  @override
  String get pageTurnDisabled => '禁用';

  @override
  String get readerFontFamily => '字体';

  @override
  String get readerFontFamilySans => '无衬线';

  @override
  String get readerFontFamilySerif => '衬线';

  @override
  String get pageAnimation => '翻页动画';

  @override
  String get pageAnimationFade => '方向性淡入过渡';

  @override
  String get pageAnimationPaper => '仿真纸张效果';

  @override
  String get pageAnimationNone => '无动画';

  @override
  String get pageAnimFade => '方向淡入';

  @override
  String get pageAnimPaper => '仿真';

  @override
  String get pageAnimNone => '无';

  @override
  String get readingReminder => '阅读提醒';

  @override
  String get readingReminderSubtitle => '章节跳转与阅读位置';

  @override
  String get reminderInterval => '提醒间隔';

  @override
  String get reminderIntervalSubtitle => '多久提醒你回来阅读一次';

  @override
  String reminderMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get reminderEvery15min => '每 15 分钟';

  @override
  String get reminderEvery30min => '每 30 分钟';

  @override
  String get reminderEveryHour => '每小时';

  @override
  String get reminderEvery2hours => '每 2 小时';

  @override
  String get reminderDaily => '每天';

  @override
  String get dataManagement => '数据管理';

  @override
  String get deleteFilesOnRemove => '删除时移除文件';

  @override
  String get deleteFilesOnRemoveSubtitle => '删除书籍时一并移除原始文件';

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
  String get upgradeToProSubtitle => '解锁私密书架等专业功能';

  @override
  String get pro => '专业版';

  @override
  String get about => '关于';

  @override
  String get lockPrivacyShelfSubtitle => '需要 PIN 码才能打开';

  @override
  String get adminPanel => '管理面板';

  @override
  String get adminPanelTitle => '管理 / 开发模式';

  @override
  String get adminPanelModeSection => '模式控制';

  @override
  String get adminProModeEnabled => '启用专业模式';

  @override
  String get adminProModeSubtitle => '解锁私密书架并关闭广告';

  @override
  String get adminForceUnlockPrivacyShelf => '强制解锁私密书架';

  @override
  String get adminForceUnlockPrivacyShelfSubtitle => '跳过密码校验';

  @override
  String get adminFeatureFlagsSection => '功能开关状态';

  @override
  String get adminStateOn => '开启';

  @override
  String get adminStateOff => '关闭';

  @override
  String get adminPanelHintTitle => '内部控制面板';

  @override
  String get adminPanelHintSubtitle => '用于调试和功能能力验证，不影响阅读数据。';

  @override
  String get language => '语言';

  @override
  String get languageSubtitle => '应用界面语言';

  @override
  String get bookDetails => '书籍详情';

  @override
  String get bookDetailsOverviewSection => '概览';

  @override
  String get bookDetailsSourceSection => '来源';

  @override
  String get originalPath => '原始路径';

  @override
  String get unknownAuthor => '未署名';

  @override
  String get readyToStart => '准备开始';

  @override
  String get title => '标题';

  @override
  String get author => '作者';

  @override
  String get format => '格式';

  @override
  String get bookFormatEpub => 'EPUB';

  @override
  String get bookFormatTxt => 'TXT';

  @override
  String get bookFormatPdf => 'PDF';

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
  String get lastOpened => '上次打开';

  @override
  String get bookDetailsSourceSummaryDownloads => '存储于下载目录';

  @override
  String get bookDetailsSourceSummaryImported => '导入的文件';

  @override
  String get bookDetailsFullTitle => '完整书名';

  @override
  String get fileLocation => '文件位置';

  @override
  String get startReading => '开始阅读';

  @override
  String get continueReading => '继续阅读';

  @override
  String get copyPath => '复制路径';

  @override
  String get filePathCopied => '文件路径已复制到剪贴板';

  @override
  String get fileExists => '文件存在';

  @override
  String get fileNotFound => '文件未找到';

  @override
  String get fileUnavailableCta => '文件不可用';

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
  String get addNoteHint => '写点什么…';

  @override
  String get deleteNote => '删除笔记';

  @override
  String get delete => '删除';

  @override
  String get remove => '移出';

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
  String get bookshelf => '书架';

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
    return '移出 $count 本书？';
  }

  @override
  String get actionCannotBeUndone => '它们会从当前书架中移出。';

  @override
  String get alsoDeleteLocalFiles => '同时删除本地文件';

  @override
  String deletedBooks(int count) {
    return '已移出 $count 本书';
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
  String get importBooksSubtitle => '继续向书架添加书籍。';

  @override
  String get importBooksEmptySubtitle => '导入第一本书，开始阅读。';

  @override
  String get importFilesSubtitle => '浏览并打开 .txt、.epub 或 .pdf 文件';

  @override
  String get supportedFormats => '支持的格式';

  @override
  String get supportedFormatsSubtitle => '纯文本、电子书和文档文件。';

  @override
  String get supportedFormatsDescription =>
      'Nyan Read 目前支持从设备中导入 TXT、EPUB 和 PDF 文件。';

  @override
  String get importingBooksTitle => '导入中';

  @override
  String get importingBooksSubtitle => '正在把书放进书架…';

  @override
  String importedBooks(int count, String shelf) {
    return '已导入 $count 本书';
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
  String get pinEnter => '输入 PIN';

  @override
  String get pinSet => '设置 PIN';

  @override
  String get pinConfirm => '确认 PIN';

  @override
  String get pinMismatch => '两次 PIN 不一致，请重试';

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
  String get readerMenuDisplay => '显示';

  @override
  String get readerMenuText => '文本';

  @override
  String get readerMenuTheme => '主题';

  @override
  String get readingTheme => '阅读主题';

  @override
  String readerSheetProgressSubtitle(String percent) {
    return '阅读进度 $percent';
  }

  @override
  String get readerBrightness => '亮度';

  @override
  String get readerSoftwareDimModeActive => '已进入屏幕调暗模式';

  @override
  String get readerBrightnessHint => '调整阅读光线';

  @override
  String get readerWarmth => '暖色温';

  @override
  String get readerWarmthHint => '降低夜间刺眼感';

  @override
  String get readerFollowSystemBrightness => '跟随系统亮度';

  @override
  String get readerAutoBrightness => '自动';

  @override
  String get readerBrightnessFollowingSystem => '跟随系统亮度';

  @override
  String get readerTypographyFineTune => '精细调整';

  @override
  String get readerTypographyFineTuneSubtitle => '字体大小与行高';

  @override
  String get readerFontSizeHint => '调大或调小';

  @override
  String get readerLineHeightHint => '调整阅读节奏';

  @override
  String get readerBrightnessDim => '暗';

  @override
  String get readerBrightnessNormal => '正常';

  @override
  String get readerBrightnessBright => '亮';

  @override
  String get readerWarmthLow => '低';

  @override
  String get readerWarmthMedium => '中';

  @override
  String get readerWarmthHigh => '高';

  @override
  String get readerTypographyCompact => '紧凑';

  @override
  String get readerTypographyStandard => '标准';

  @override
  String get readerTypographyComfortable => '舒展';

  @override
  String get readerTypographyPreviewSample => '春日和风，纸页轻响，阅读让时间慢下来。';

  @override
  String readerResetSection(String section) {
    return '重置$section';
  }

  @override
  String get readerResetAppearance => '恢复默认';

  @override
  String get readerResetAppearanceHint => '字体、行距、主题、暖色温与亮度模式';

  @override
  String get readerResetCurrentTab => '重置本页';

  @override
  String get readerResetCurrentTabHint => '仅恢复当前分区';

  @override
  String get readerResetAll => '全部重置';

  @override
  String get readerResetAllConfirmTitle => '要重置全部阅读外观吗？';

  @override
  String get readerResetAllConfirmMessage => '将恢复字体、行距、主题、暖色温与亮度的默认设置。';

  @override
  String get readerResetAllConfirmAction => '全部重置';

  @override
  String get tableOfContents => '目录';

  @override
  String readerSettingsProgressHint(Object pct) {
    return '阅读进度 $pct%';
  }

  @override
  String chapterOfCount(int current, int total) {
    return '第 $current 章 / 共 $total 章';
  }

  @override
  String get readerDockChapters => '目录';

  @override
  String get readerDockHighlights => '高亮';

  @override
  String get jumpToCurrentChapter => '定位当前章节';

  @override
  String chapterListProgressLabel(int current, int total) {
    return '已读 $current / $total 章';
  }

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
  String bookmarksSavedCount(int count) {
    return '已存 $count 个';
  }

  @override
  String get noBookmarksYet => '暂无书签';

  @override
  String get bookmarkContextTitle => '阅读痕迹';

  @override
  String get bookmarkContextDescription => '点开片段返回原文，左滑即可删除。';

  @override
  String get bookmarkEmptyDescription => '想重温的段落，会留在这里。';

  @override
  String get bookmarkEmptyHint => '阅读时轻点书签即可保存';

  @override
  String get bookmarkNoteTag => '有笔记';

  @override
  String bookmarkName(int index) {
    return '书签 #$index';
  }

  @override
  String failedToDeleteBookmark(String error) {
    return '删除书签失败：$error';
  }

  @override
  String get bookmarkAdded => '已添加书签';

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
  String get themeCreamLightHint => '温暖纸感，默认';

  @override
  String get themeSumiDark => '墨色黑';

  @override
  String get themeSumiDarkHint => '深夜护眼';

  @override
  String get themeMatchSystem => '跟随系统';

  @override
  String get themeMatchSystemHint => '随设备深色模式切换';

  @override
  String get pageTurnLeftRight => '左右翻页';

  @override
  String get pageTurnLeftRightHint => '水平翻页';

  @override
  String get pageTurnUpDown => '上下翻页';

  @override
  String get pageTurnUpDownHint => '垂直翻页';

  @override
  String get languageEnglishHint => 'English';

  @override
  String get languageChineseHint => '中文 · 简体中文';

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
  String get errorFileNotFoundTitle => '这本书迷路了';

  @override
  String get errorFileNotFoundBody => '找不到源文件——它可能已被移动或删除。';

  @override
  String get errorUnsupportedFormatTitle => 'Nyan 还不能读取这种格式';

  @override
  String get errorUnsupportedFormatBody => '暂不支持该文件类型。';

  @override
  String get errorParseFailedTitle => '书页像是粘在一起了';

  @override
  String get errorParseFailedBody => '无法打开此文件，它可能已损坏。';

  @override
  String get errorUnknownTitle => '出了点问题';

  @override
  String get errorUnknownBody => '发生了意外错误，请稍后再试。';

  @override
  String get emptyShelfTitle => '书架正在等待新的故事';

  @override
  String get emptyShelfSubtitle => '导入一本书开始阅读';

  @override
  String get exportData => '导出数据';

  @override
  String get exportDataSubtitle => '保存到设备或分享';

  @override
  String get exportDataSheetSubtitle => '选择阅读数据的保存方式';

  @override
  String get saveToDevice => '保存到设备';

  @override
  String get saveToDeviceSubtitle => '将 JSON 备份存储到文件';

  @override
  String get shareVia => '分享...';

  @override
  String get shareViaSubtitle => '通过 Gmail、Drive 等应用发送';

  @override
  String get importData => '导入数据';

  @override
  String get importDataSubtitle => '从备份文件恢复';

  @override
  String importSuccess(int count) {
    return '成功恢复 $count 本书！';
  }

  @override
  String importFailed(String error) {
    return '导入失败：$error';
  }
}
