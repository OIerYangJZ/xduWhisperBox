import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../repositories/app_repositories.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.initialEmail,
    this.lockEmail = false,
  });

  final String? initialEmail;
  final bool lockEmail;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail?.trim() ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('邮箱重置密码')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        '使用注册邮箱找回密码',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('先发送验证码，再输入新密码完成修改。'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailController,
                        enabled: !_busy && !widget.lockEmail,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: '校园邮箱',
                          hintText: 'example@stu.xidian.edu.cn',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _codeController,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: '邮箱验证码',
                          hintText: '6 位数字',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _newPasswordController,
                        enabled: !_busy,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '新密码',
                          hintText: '至少 6 位',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _confirmPasswordController,
                        enabled: !_busy,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '确认新密码',
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _sendCode,
                        icon: const Icon(Icons.mark_email_read_outlined),
                        label: const Text('发送重置验证码'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _busy ? null : _submitReset,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(_busy ? '提交中...' : '确认修改密码'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendCode() async {
    final String email = _emailController.text.trim();
    if (!_isCampusEmail(email)) {
      _setError('仅支持西电校内邮箱（@stu.xidian.edu.cn 或 @xidian.edu.cn）。');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppRepositories.auth.sendPasswordResetCode(email);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('验证码已发送至 $email')),
      );
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('发送失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _submitReset() async {
    final String email = _emailController.text.trim();
    final String code = _codeController.text.trim();
    final String newPassword = _newPasswordController.text.trim();
    final String confirm = _confirmPasswordController.text.trim();

    if (!_isCampusEmail(email)) {
      _setError('邮箱格式不符合校内认证要求。');
      return;
    }
    if (code.length != 6) {
      _setError('请输入 6 位验证码。');
      return;
    }
    if (newPassword.length < 6) {
      _setError('新密码长度至少 6 位。');
      return;
    }
    if (newPassword != confirm) {
      _setError('两次输入的新密码不一致。');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppRepositories.auth.resetPasswordByEmail(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码修改成功，请使用新密码登录。')),
      );
      Navigator.of(context).maybePop();
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('修改失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  bool _isCampusEmail(String email) {
    return email.endsWith('@stu.xidian.edu.cn') ||
        email.endsWith('@xidian.edu.cn');
  }

  void _setError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _error = message;
    });
  }
}
