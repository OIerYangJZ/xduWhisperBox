import 'package:flutter/material.dart';

import '../../core/media/image_picker_adapter.dart';
import '../../core/media/picked_image_data.dart';
import '../../core/network/api_exception.dart';
import '../../repositories/app_repositories.dart';
import '../../features/legal/terms_of_service_page.dart';
import '../../features/legal/community_guidelines_page.dart';
import 'verify_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  PickedImageData? _selectedAvatar;

  bool _agreeTerms = false;
  bool _isBusy = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册账号')),
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
                      Text(
                        '创建西电树洞账号',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text('注册后需完成邮箱验证码认证。'),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _emailController,
                        onChanged: (_) {
                          setState(() {});
                        },
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: '校园邮箱',
                          hintText: 'example@stu.xidian.edu.cn',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '密码',
                          hintText: '至少 6 位',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '确认密码',
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nicknameController,
                        decoration: const InputDecoration(
                          labelText: '用户昵称',
                          hintText: '例如：洞主-雾蓝',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _buildStudentIdHint(_emailController.text.trim()),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFE5EAF3),
                            child: _selectedAvatar == null
                                ? const Icon(Icons.person_outline, color: Color(0xFF5B6B88))
                                : ClipOval(
                                    child: Image.network(
                                      _selectedAvatar!.previewDataUrl,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) {
                                        return const Icon(Icons.image_not_supported_outlined);
                                      },
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text('头像（可选）'),
                                Text(
                                  _selectedAvatar == null
                                      ? '未选择图片'
                                      : _selectedAvatar!.fileName,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isBusy ? null : _pickAvatar,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('上传'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Checkbox(
                            value: _agreeTerms,
                            onChanged: _isBusy
                                ? null
                                : (bool? value) {
                                    setState(() {
                                      _agreeTerms = value ?? false;
                                    });
                                  },
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _isBusy
                                  ? null
                                  : () {
                                      setState(() {
                                        _agreeTerms = !_agreeTerms;
                                      });
                                    },
                              child: const Text.rich(
                                TextSpan(
                                  children: <InlineSpan>[
                                    TextSpan(text: '我已阅读并同意'),
                                    TextSpan(
                                      text: '《用户协议》',
                                      style: TextStyle(
                                        color: Color(0xFF0E7490),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(text: '与'),
                                    TextSpan(
                                      text: '《社区规范》',
                                      style: TextStyle(
                                        color: Color(0xFF0E7490),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const _TermsRoute(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('《用户协议》',
                                style: TextStyle(fontSize: 12)),
                          ),
                          const Text(' · ', style: TextStyle(fontSize: 12)),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const _GuidelinesRoute(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('《社区规范》',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      if (_errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            _errorText!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      FilledButton.tonalIcon(
                        onPressed: _isBusy ? null : _sendCode,
                        icon: const Icon(Icons.mark_email_read_outlined),
                        label: const Text('先发送验证码'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _isBusy ? null : _register,
                        icon: _isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.app_registration_rounded),
                        label: Text(_isBusy ? '提交中...' : '注册并去认证'),
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
      setState(() {
        _errorText = '仅支持西电校内邮箱（@stu.xidian.edu.cn 或 @xidian.edu.cn）。';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      final String? debugCode = await AppRepositories.auth.sendEmailCode(email);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            debugCode == null
                ? '验证码已发送至 $email'
                : '验证码已发送（内测模式验证码：$debugCode）',
          ),
        ),
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('发送失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _register() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();
    final String nickname = _nicknameController.text.trim();
    final String studentId = _studentIdFromEmail(email);

    if (!_isCampusEmail(email)) {
      _showError('邮箱格式不符合校内认证要求。');
      return;
    }
    if (password.length < 6) {
      _showError('密码长度至少 6 位。');
      return;
    }
    if (password != confirmPassword) {
      _showError('两次输入的密码不一致。');
      return;
    }
    if (nickname.isEmpty) {
      _showError('请输入用户昵称。');
      return;
    }
    if (!_isValidStudentId(studentId)) {
      _showError('邮箱前缀将作为学号，请使用 6-20 位字母或数字。');
      return;
    }
    if (!_agreeTerms) {
      _showError('请先勾选用户协议与社区规范。');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      await AppRepositories.auth.register(
        email: email,
        password: password,
        nickname: nickname,
        avatarFileName: _selectedAvatar?.fileName,
        avatarContentType: _selectedAvatar?.contentType,
        avatarDataBase64: _selectedAvatar?.dataBase64,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VerifyPage(
            campusEmail: email,
            password: password,
          ),
        ),
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('注册失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  bool _isCampusEmail(String email) {
    return email.endsWith('@stu.xidian.edu.cn') ||
        email.endsWith('@xidian.edu.cn');
  }

  String _studentIdFromEmail(String email) {
    final int idx = email.indexOf('@');
    if (idx <= 0) {
      return '';
    }
    return email.substring(0, idx).trim();
  }

  bool _isValidStudentId(String value) {
    return RegExp(r'^[0-9A-Za-z]{6,20}$').hasMatch(value);
  }

  String _buildStudentIdHint(String email) {
    final String studentId = _studentIdFromEmail(email);
    if (studentId.isEmpty) {
      return '学号将自动从邮箱前缀生成（例如 2023123456@stu.xidian.edu.cn -> 2023123456）';
    }
    return '学号将自动生成为：$studentId';
  }

  Future<void> _pickAvatar() async {
    try {
      final List<PickedImageData> selected = await pickImageFiles(multiple: false);
      if (!mounted || selected.isEmpty) {
        return;
      }
      setState(() {
        _selectedAvatar = selected.first;
      });
    } catch (error) {
      _showError('头像选择失败：$error');
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

class _TermsRoute extends StatelessWidget {
  const _TermsRoute();

  @override
  Widget build(BuildContext context) {
    return const TermsOfServicePage();
  }
}

class _GuidelinesRoute extends StatelessWidget {
  const _GuidelinesRoute();

  @override
  Widget build(BuildContext context) {
    return const CommunityGuidelinesPage();
  }
}
