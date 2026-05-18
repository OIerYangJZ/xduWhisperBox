import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/auth_repository.dart';
import '../../features/legal/terms_of_service_page.dart';
import '../../features/legal/privacy_policy_page.dart';
import '../../features/legal/community_guidelines_page.dart';
import '../admin/admin_login_page.dart';
import '../download/android_release_page.dart';
import '../../widgets/home_shell.dart';
import 'register_page.dart';
import 'reset_password_page.dart';
import 'verify_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isBusy = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                    const Text('仅限西电学生，使用学生邮箱注册并登录。'),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _identifierController,
                      enabled: !_isBusy,
                      decoration: const InputDecoration(
                        labelText: '学号或学生邮箱',
                        hintText: '2023123456 或 2023123456@stu.xidian.edu.cn',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      enabled: !_isBusy,
                      obscureText: _obscurePassword,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: _isBusy
                              ? null
                              : () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
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
                      onPressed: _isBusy ? null : _login,
                      icon: _isBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(_isBusy ? '登录中...' : '登录'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isBusy
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const RegisterPage(),
                                      ),
                                    );
                                  },
                            child: const Text('注册账号'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextButton(
                            onPressed: _isBusy
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const ResetPasswordPage(),
                                      ),
                                    );
                                  },
                            child: const Text('忘记密码'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '注册、验证码和密码找回仅支持 @stu.xidian.edu.cn 学生邮箱。',
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

  Future<void> _login() async {
    final String identifier = _identifierController.text.trim();
    final String password = _passwordController.text.trim();
    if (identifier.isEmpty) {
      _showError('请输入学号或学生邮箱。');
      return;
    }
    if (password.isEmpty) {
      _showError('请输入密码。');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      final AuthLoginResult result = await AppRepositories.auth.login(
        identifier: identifier,
        password: password,
      );
      if (!mounted) {
        return;
      }
      if (result.verified && (result.token ?? '').isNotEmpty) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const HomeShell()),
          (Route<dynamic> route) => false,
        );
        return;
      }
      final String email = result.email?.trim() ?? '';
      if (email.isEmpty) {
        _showError('登录结果异常，请稍后重试。');
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => VerifyPage(campusEmail: email)),
      );
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
      appBar: AppBar(title: const Text('协议与规范')),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('用户协议'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TermsOfServicePage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隐私政策'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacyPolicyPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('社区规范'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CommunityGuidelinesPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
