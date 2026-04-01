import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/core/network/api_exception.dart';
import 'package:xdu_treehole_web/repositories/auth_repository.dart';
import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/state/mobile_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  String? _errorMessage;
  String? _attemptId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _attemptId != null) {
      Future<void>.microtask(_pollLoginResult);
    }
  }

  Future<void> _startLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final XidianAuthSessionResult result = await ref
          .read(authRepositoryProvider)
          .createXidianAuthSession(platform: 'mobile', nextPath: '/');
      final authorizeUrl = (result.authorizeUrl ?? '').trim();
      if (authorizeUrl.isEmpty) {
        throw ApiException(message: '统一认证地址生成失败');
      }
      _attemptId = result.attemptId;
      final launched = await launchUrl(
        Uri.parse(authorizeUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw ApiException(message: '无法拉起统一认证页面');
      }
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('登录跳转失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pollLoginResult() async {
    final attemptId = _attemptId;
    if (attemptId == null || attemptId.isEmpty || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .fetchXidianAuthSession(attemptId);
      if (!mounted) {
        return;
      }
      if (result.isAuthenticated && (result.token ?? '').isNotEmpty) {
        _attemptId = null;
        try {
          final profile = await ref.read(userRepositoryProvider).fetchProfile();
          AuthStore.instance.setCurrentUser(profile);
        } catch (_) {}
        if (!mounted) {
          return;
        }
        ref.invalidate(feedControllerProvider);
        ref.invalidate(notificationsControllerProvider);
        ref.invalidate(messagesControllerProvider);
        context.go('/');
        return;
      }
      if (result.isFailed) {
        _attemptId = null;
        _showError(result.message ?? '统一认证登录失败');
        return;
      }
      _showError('统一认证尚未完成，请在浏览器中完成认证后返回此处重试。');
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('登录失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: MobileTheme.primaryOf(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.forum_outlined,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '西电树洞',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '欢迎回来',
                style: TextStyle(fontSize: 15, color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '移动端统一认证浏览器登录',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.divider),
                ),
                child: Text(
                  '登录时会跳转到西电统一认证页面输入密码。树洞前端和树洞后端都不会接收你的统一认证密码。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              FilledButton.icon(
                onPressed: _isLoading ? null : _startLogin,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_browser_rounded),
                label: Text(_isLoading ? '处理中...' : '前往统一认证登录'),
              ),
              if (_attemptId != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pollLoginResult,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('我已完成认证，刷新登录状态'),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '完成统一认证后返回 App，登录状态会自动同步。',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
