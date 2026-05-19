import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';

class DisplaySettingsPage extends ConsumerStatefulWidget {
  const DisplaySettingsPage({super.key});

  @override
  ConsumerState<DisplaySettingsPage> createState() => _DisplaySettingsPageState();
}

class _DisplaySettingsPageState extends ConsumerState<DisplaySettingsPage> {
  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('外观'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeOption(
              title: '跟随系统',
              value: ThemeMode.system,
              current: ref.read(appSettingsProvider).themeMode,
              onTap: () => _setBrightness(ThemeMode.system, ctx),
            ),
            _ThemeOption(
              title: '浅色',
              value: ThemeMode.light,
              current: ref.read(appSettingsProvider).themeMode,
              onTap: () => _setBrightness(ThemeMode.light, ctx),
            ),
            _ThemeOption(
              title: '深色',
              value: ThemeMode.dark,
              current: ref.read(appSettingsProvider).themeMode,
              onTap: () => _setBrightness(ThemeMode.dark, ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setBrightness(ThemeMode mode, BuildContext dialogContext) async {
    await ref.read(appSettingsProvider.notifier).setBrightness(mode);
    if (!mounted) return;
    Navigator.pop(dialogContext);
    _showToast('已切换到 ${_themeModeLabel(mode)}');
  }

  String _themeModeLabel(ThemeMode mode) {
    if (mode == ThemeMode.system) return '跟随系统';
    if (mode == ThemeMode.light) return '浅色';
    if (mode == ThemeMode.dark) return '深色';
    return '未知';
  }

  void _showLanguageDialog() {
    final currentLocale = ref.read(appSettingsProvider).locale;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('语言'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LocaleOption(
              title: '简体中文',
              locale: const Locale('zh', 'CN'),
              current: currentLocale,
              onTap: () => _setLocale(const Locale('zh', 'CN'), ctx),
            ),
            _LocaleOption(
              title: '繁體中文',
              locale: const Locale.fromSubtags(
                languageCode: 'zh',
                scriptCode: 'Hant',
              ),
              current: currentLocale,
              onTap: () => _setLocale(
                const Locale.fromSubtags(
                  languageCode: 'zh',
                  scriptCode: 'Hant',
                ),
                ctx,
              ),
            ),
            _LocaleOption(
              title: 'English',
              locale: const Locale('en', 'US'),
              current: currentLocale,
              onTap: () => _setLocale(const Locale('en', 'US'), ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setLocale(Locale loc, BuildContext dialogContext) async {
    await ref.read(appSettingsProvider.notifier).setLocale(loc);
    if (!mounted) return;
    Navigator.pop(dialogContext);
    _showToast('已切换到 ${_localeLabel(loc)}');
  }

  String _localeLabel(Locale loc) {
    final code = loc.scriptCode != null && loc.scriptCode!.isNotEmpty
        ? '${loc.languageCode}_${loc.scriptCode}'
        : '${loc.languageCode}_${loc.countryCode ?? ''}';
    if (code == 'zh_CN') return '简体中文';
    if (code == 'zh_Hant' || code == 'zh_TW') return '繁體中文';
    if (code == 'en_US' || code == 'en_') return 'English';
    return '${loc.languageCode}_${loc.countryCode ?? ''}';
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('界面设置'),
        backgroundColor: colors.background,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTileCard([
            _buildListTile(
              icon: Icons.brightness_6_outlined,
              title: '外观主题',
              subtitle: _themeModeLabel(settings.themeMode),
              onTap: _showThemeDialog,
            ),
            _buildListTile(
              icon: Icons.language_outlined,
              title: '多语言',
              subtitle: _localeLabel(settings.locale ?? const Locale('zh', 'CN')),
              onTap: _showLanguageDialog,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildTileCard(List<Widget> children) {
    final colors = MobileColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(
        children: List<Widget>.generate(children.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Divider(height: 0.5, indent: 56, color: colors.divider);
          }
          return children[index ~/ 2];
        }),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = MobileColors.of(context);
    return ListTile(
      leading: Icon(icon, color: colors.textSecondary, size: 20),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: colors.textTertiary),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.title,
    required this.value,
    required this.current,
    required this.onTap,
  });

  final String title;
  final ThemeMode value;
  final ThemeMode current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return ListTile(
      title: Text(title),
      trailing: selected
          ? Icon(Icons.check, color: MobileTheme.primaryOf(context))
          : null,
      onTap: onTap,
    );
  }
}

class _LocaleOption extends StatelessWidget {
  const _LocaleOption({
    required this.title,
    required this.locale,
    required this.current,
    required this.onTap,
  });

  final String title;
  final Locale locale;
  final Locale? current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected =
        locale.languageCode == current?.languageCode &&
        locale.countryCode == current?.countryCode;
    return ListTile(
      title: Text(title),
      trailing: selected
          ? Icon(Icons.check, color: MobileTheme.primaryOf(context))
          : null,
      onTap: onTap,
    );
  }
}
