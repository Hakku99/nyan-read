with open(r'c:\Projects\nyan-read\lib\modules\reader\widgets\reader_menu.dart', 'r', encoding='utf-8') as f:
    code = f.read().replace('\r\n', '\n')

# 2. Update build method
code = code.replace(
    '''    final themeManager = context.watch<ThemeManager>();
    // Use the global app theme for the menu, decoupled from the reader's background color
    final activeTheme = themePresets[themeManager.currentPreset]!;''',
    '''    final appTheme = Theme.of(context);'''
)

code = code.replace(
    '''                // 1. Progress Slider
                _buildProgressSection(context, controller, activeTheme),

                const SizedBox(height: 24),

                // 2. Brightness Slider
                _buildBrightnessSection(context, controller, activeTheme),

                const SizedBox(height: 24),
                Divider(
                    height: 1,
                    color: themeManager.currentPreset == ThemePreset.creamLight
                        ? const Color(0xFFE6E2D8)
                        : activeTheme.divider.withOpacity(0.5)),
                const SizedBox(height: 24),

                // 3. Settings Row (Font, Line Height)
                _buildTypographySection(context, controller, activeTheme),

                const SizedBox(height: 24),
                Divider(
                    height: 1,
                    color: themeManager.currentPreset == ThemePreset.creamLight
                        ? const Color(0xFFE6E2D8)
                        : activeTheme.divider.withOpacity(0.5)),
                const SizedBox(height: 24),

                // 4. Themes (Background Colors)
                _buildThemeSection(context, controller, activeTheme),

                const SizedBox(height: 24),
                Divider(
                    height: 1,
                    color: themeManager.currentPreset == ThemePreset.creamLight
                        ? const Color(0xFFE6E2D8)
                        : activeTheme.divider.withOpacity(0.5)),
                const SizedBox(height: 20),

                // 5. Bottom Navigation Actions
                _buildBottomActions(context, controller, activeTheme),''',
    '''                // 1. Progress Slider
                _buildProgressSection(context, controller, appTheme),

                const SizedBox(height: 24),

                // 2. Brightness Slider
                _buildBrightnessSection(context, controller, appTheme),

                const SizedBox(height: 24),
                Divider(
                    height: 1,
                    color: appTheme.dividerColor.withOpacity(0.5)),
                const SizedBox(height: 24),

                // 3. Settings Row (Font, Line Height)
                _buildTypographySection(context, controller, appTheme),

                const SizedBox(height: 24),
                Divider(
                    height: 1,
                    color: appTheme.dividerColor.withOpacity(0.5)),
                const SizedBox(height: 24),

                // 4. Themes (Background Colors)
                _buildThemeSection(context, controller, appTheme),

                const SizedBox(height: 24),
                Divider(
                    height: 1,
                    color: appTheme.dividerColor.withOpacity(0.5)),
                const SizedBox(height: 20),

                // 5. Bottom Navigation Actions
                _buildBottomActions(context, controller, appTheme),'''
)

code = code.replace(
    '''  Widget _buildProgressSection(
      BuildContext context, ReaderController controller, NyanTheme theme) {''',
    '''  Widget _buildProgressSection(
      BuildContext context, ReaderController controller, ThemeData theme) {'''
)
code = code.replace(
    '''            activeColor: theme.primary,
            inactiveColor: theme.preset == ThemePreset.creamLight
                ? const Color(0xFFE6E2D8)
                : theme.divider.withOpacity(0.3),''',
    '''            activeColor: theme.colorScheme.primary,
            inactiveColor: theme.dividerColor.withOpacity(0.3),'''
)
code = code.replace(
    '''  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required NyanTheme theme,
  }) {''',
    '''  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {'''
)
code = code.replace(
    '''        decoration: BoxDecoration(
          color: theme.preset == ThemePreset.creamLight
              ? NyanTheme.creamRecess
              : theme.surface.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 24,
          color: theme.textSecondary,
        ),''',
    '''        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 24,
          color: theme.colorScheme.onSurfaceVariant,
        ),'''
)
code = code.replace(
    '''  Widget _buildBrightnessSection(
      BuildContext context, ReaderController controller, NyanTheme theme) {''',
    '''  Widget _buildBrightnessSection(
      BuildContext context, ReaderController controller, ThemeData theme) {'''
)
code = code.replace(
    '''              decoration: BoxDecoration(
                color: theme.preset == ThemePreset.creamLight
                    ? NyanTheme.creamRecess
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.wb_sunny_rounded,
                  size: 22, color: theme.textSecondary.withOpacity(0.6)),''',
    '''              decoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.wb_sunny_rounded,
                  size: 22, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),'''
)
code = code.replace(
    '''                activeColor: theme.textSecondary
                    .withOpacity(0.8), // Darker grey for brightness
                inactiveColor: theme.divider.withOpacity(0.5),''',
    '''                activeColor: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                inactiveColor: theme.dividerColor.withOpacity(0.5),'''
)
code = code.replace(
    '''                    color: controller.followSystem
                        ? theme.primary
                        : Colors.grey.withOpacity(0.5),''',
    '''                    color: controller.followSystem
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.5),'''
)
code = code.replace(
    '''              decoration: BoxDecoration(
                color: theme.preset == ThemePreset.creamLight
                    ? NyanTheme.creamRecess
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),''',
    '''              decoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),'''
)
code = code.replace(
    '''  Widget _buildTypographySection(
      BuildContext context, ReaderController controller, NyanTheme theme) {''',
    '''  Widget _buildTypographySection(
      BuildContext context, ReaderController controller, ThemeData theme) {'''
)
code = code.replace(
    '''          color: theme.divider.withOpacity(0.1),''',
    '''          color: theme.dividerColor.withOpacity(0.1),'''
)
code = code.replace(
    '''  Widget _buildStepper(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onRemove,
    required VoidCallback onAdd,
    required NyanTheme theme,
  }) {''',
    '''  Widget _buildStepper(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onRemove,
    required VoidCallback onAdd,
    required ThemeData theme,
  }) {'''
)
code = code.replace(
    '''            color: theme.textSecondary.withOpacity(0.5),''',
    '''            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),'''
)
code = code.replace(
    '''                    Icon(Icons.remove_rounded, size: 22, color: theme.primary),''',
    '''                    Icon(Icons.remove_rounded, size: 22, color: theme.colorScheme.primary),'''
)
code = code.replace(
    '''                    color: theme.textPrimary,''',
    '''                    color: theme.colorScheme.onSurface,'''
)
code = code.replace(
    '''                child: Icon(Icons.add_rounded, size: 22, color: theme.primary),''',
    '''                child: Icon(Icons.add_rounded, size: 22, color: theme.colorScheme.primary),'''
)

code = code.replace(
    '''  Widget _buildThemeSection(
      BuildContext context, ReaderController controller, NyanTheme theme) {''',
    '''  Widget _buildThemeSection(
      BuildContext context, ReaderController controller, ThemeData theme) {'''
)
code = code.replace(
    '''  Widget _buildColorBtn(BuildContext context, ReaderController c, Color color,
      NyanTheme currentTheme,
      {bool isDark = false, String? label}) {''',
    '''  Widget _buildColorBtn(BuildContext context, ReaderController c, Color color,
      ThemeData currentTheme,
      {bool isDark = false, String? label}) {'''
)
code = code.replace(
    '''                color: isSelected
                    ? currentTheme.primary
                    : const Color(0xFFE6E2D8), // Subtle border for unselected''',
    '''                color: isSelected
                    ? currentTheme.colorScheme.primary
                    : currentTheme.dividerColor, // Subtle border for unselected'''
)
code = code.replace(
    '''                    color: isDark ? Colors.white : currentTheme.primary,''',
    '''                    color: isDark ? Colors.white : currentTheme.colorScheme.primary,'''
)
code = code.replace(
    '''                color: isSelected
                    ? currentTheme.primary
                    : currentTheme.textSecondary.withOpacity(0.7),''',
    '''                color: isSelected
                    ? currentTheme.colorScheme.primary
                    : currentTheme.colorScheme.onSurfaceVariant.withOpacity(0.7),'''
)

code = code.replace(
    '''  Widget _buildBottomActions(
      BuildContext context, ReaderController controller, NyanTheme theme) {''',
    '''  Widget _buildBottomActions(
      BuildContext context, ReaderController controller, ThemeData theme) {'''
)
code = code.replace(
    '''                  color: isActive
                      ? theme.primary // Sage Green if active
                      : theme.textSecondary.withOpacity(0.8),''',
    '''                  color: isActive
                      ? theme.colorScheme.primary // Sage Green if active
                      : theme.colorScheme.onSurfaceVariant.withOpacity(0.8),'''
)
import builtins
with open(r'c:\Projects\nyan-read\lib\modules\reader\widgets\reader_menu.dart', 'w', encoding='utf-8') as f:
    f.write(code)
