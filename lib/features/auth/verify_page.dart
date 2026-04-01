import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/home_shell.dart';

class VerifyPage extends StatefulWidget {
  const VerifyPage({
    super.key,
    required this.campusEmail,
    this.password,
  });

  final String campusEmail;
  final String? password;

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final TextEditingController _codeController = TextEditingController();
  String? _errorText;
  bool _isBusy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('校园身份认证')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      '认证说明',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text('前台不会公开你的真实身份，后台仅用于安全审查与追责。'),
                    const SizedBox(height: 12),
                    Text('认证邮箱：${widget.campusEmail}'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: '邮箱验证码',
                        hintText: '输入 6 位验证码',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                    ),
                    if (_errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    FilledButton(
                      onPressed: _isBusy ? null : _submit,
                      child: Text(_isBusy ? '认证中...' : '完成认证并进入首页'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isBusy ? null : _resend,
                      child: const Text('重新发送验证码'),
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

  Future<void> _submit() async {
    if (_codeController.text.trim().length != 6) {
      setState(() {
        _errorText = '请输入 6 位验证码。';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      final AuthLoginResult result = await AppRepositories.auth.verifyEmail(
        email: widget.campusEmail,
        code: _codeController.text.trim(),
        password: widget.password,
      );

      if (!mounted) {
        return;
      }

      if (!result.verified) {
        setState(() {
          _errorText = '认证结果异常，请稍后重试。';
        });
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeShell()),
        (Route<dynamic> route) => false,
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('认证失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      final String? debugCode =
          await AppRepositories.auth.resendCode(widget.campusEmail);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            debugCode == null
                ? '验证码已重新发送。'
                : '验证码已重新发送（内测模式验证码：$debugCode）。',
          ),
        ),
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('重发失败：$error');
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
