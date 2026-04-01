import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation/url_query_state.dart';
import '../../core/network/api_exception.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/auth_repository.dart';
import '../../features/legal/terms_of_service_page.dart';
import '../../features/legal/privacy_policy_page.dart';
import '../../features/legal/community_guidelines_page.dart';
import '../admin/admin_login_page.dart';
import '../download/android_release_page.dart';
import '../../widgets/home_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isBusy = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_consumeReturnedLoginAttemptIfNeeded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFEAF3FB), Color(0xFFF6F8FB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      '西电树洞',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    const Text('仅限西电学生，使用西电统一身份认证登录。'),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFB6D7F3)),
                      ),
                      child: const Text(
                        '登录时将跳转到西电统一认证页面输入密码。树洞前端和树洞后端都不再接收你的统一认证密码。',
                        style: TextStyle(height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _isBusy ? null : _startBrowserLogin,
                      icon: _isBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.open_in_browser_rounded),
                      label: Text(_isBusy ? '跳转中...' : '前往统一认证登录'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '树洞普通用户已切换为统一认证浏览器登录，不再提供站内注册、邮箱验证和本地找回密码。',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    TextButton.icon(
                      onPressed: _isBusy
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const AdminLoginPage(),
                                ),
                              );
                            },
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('管理员后台登录'),
                    ),
                    TextButton.icon(
                      onPressed: _isBusy
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const AndroidReleasePage(),
                                ),
                              );
                            },
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('下载 Android 客户端'),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const _LoginTermsRoute(),
                          ),
                        );
                      },
                      child: const Text(
                        '用户协议 · 隐私政策 · 社区规范',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _consumeReturnedLoginAttemptIfNeeded() async {
    final String? attemptId = takeQueryParameterFromUrl('xidianAuthAttempt');
    if (attemptId == null || attemptId.isEmpty) {
      return;
    }
    await _consumeLoginAttempt(attemptId);
  }

  Future<void> _startBrowserLogin() async {
    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      final XidianAuthSessionResult result =
          await AppRepositories.auth.createXidianAuthSession(
        platform: 'web',
        nextPath: '/',
      );
      final String url = (result.authorizeUrl ?? '').trim();
      if (url.isEmpty) {
        throw ApiException(message: '统一认证地址生成失败');
      }
      final bool launched = await launchUrl(
        Uri.parse(url),
        webOnlyWindowName: '_self',
      );
      if (!launched) {
        throw ApiException(message: '无法跳转到统一认证页面');
      }
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('登录跳转失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _consumeLoginAttempt(String attemptId) async {
    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      final XidianAuthSessionResult result =
          await AppRepositories.auth.fetchXidianAuthSession(attemptId);
      if (!mounted) {
        return;
      }
      if (result.isAuthenticated && (result.token ?? '').isNotEmpty) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const HomeShell()),
          (Route<dynamic> route) => false,
        );
        return;
      }
      _showError(result.message ?? '统一认证尚未完成，请重新发起登录。');
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('登录失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorText = message;
    });
  }
}

class _LoginTermsRoute extends StatelessWidget {
  const _LoginTermsRoute();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('合规说明'),
        backgroundColor: const Color(0xFF0E7490),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildLinkCard(
            context,
            icon: Icons.description_outlined,
            title: '用户协议',
            subtitle: '了解平台服务条款与用户行为规范',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TermsOfServicePage(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildLinkCard(
            context,
            icon: Icons.shield_outlined,
            title: '隐私政策',
            subtitle: '了解我们如何收集、使用和保护您的信息',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacyPolicyPage(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildLinkCard(
            context,
            icon: Icons.groups_outlined,
            title: '社区规范',
            subtitle: '了解社区规则与内容管理政策',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CommunityGuidelinesPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF0E7490).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF0E7490)),
        ),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
