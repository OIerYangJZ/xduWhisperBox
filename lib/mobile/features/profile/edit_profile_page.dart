import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/core/config/app_config.dart';
import 'package:xdu_treehole_web/models/user_profile.dart';
import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/state/mobile_providers.dart';
import '../widgets/avatar_widget.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();

  UserProfile? _profile;
  String? _avatarUrl;
  String? _selectedAvatarBase64;
  String? _selectedAvatarFileName;
  String? _backgroundImageUrl;
  String? _selectedBgBase64;
  String? _selectedBgFileName;
  String _gender = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await ref.read(userRepositoryProvider).fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _nicknameController.text = profile.nickname;
        _bioController.text = profile.bio;
        _avatarUrl = profile.avatarUrl;
        _backgroundImageUrl = profile.backgroundImageUrl;
        _gender = profile.gender;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final base64 = base64Encode(bytes);
      final fileName = picked.name;

      setState(() {
        _selectedAvatarBase64 = base64;
        _selectedAvatarFileName = fileName;
      });
    } catch (e) {
      _showToast('图片选择失败');
    }
  }

  Future<void> _pickBackgroundImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final base64 = base64Encode(bytes);
      final fileName = picked.name;

      setState(() {
        _selectedBgBase64 = base64;
        _selectedBgFileName = fileName;
      });
    } catch (e) {
      _showToast('图片选择失败');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      _showToast('昵称不能为空');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      String? newAvatarUrl = _avatarUrl;
      String? newBgUrl = _backgroundImageUrl;

      if (_selectedAvatarBase64 != null) {
        final userRepo = ref.read(userRepositoryProvider);
        newAvatarUrl = await userRepo.uploadAvatar(
          fileName: _selectedAvatarFileName ?? 'avatar.jpg',
          contentType: 'image/jpeg',
          dataBase64: _selectedAvatarBase64!,
        );
      }

      if (_selectedBgBase64 != null) {
        final userRepo = ref.read(userRepositoryProvider);
        newBgUrl = await userRepo.uploadBackgroundImage(
          fileName: _selectedBgFileName ?? 'background.jpg',
          contentType: 'image/jpeg',
          dataBase64: _selectedBgBase64!,
        );
      }

      await ref
          .read(userRepositoryProvider)
          .updateProfile(
            nickname: nickname,
            avatarUrl: newAvatarUrl,
            bio: _bioController.text.trim(),
            backgroundImageUrl: newBgUrl,
            gender: _gender,
          );
      final updatedProfile = await ref
          .read(userRepositoryProvider)
          .fetchProfile();
      AuthStore.instance.setCurrentUser(updatedProfile);

      if (!mounted) return;

      _showToast('资料已保存');

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      _showToast('保存失败：${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('编辑资料'),
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: _saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MobileTheme.primaryOf(context),
                    ),
                  )
                : const Text(
                    '保存',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: MobileTheme.primaryOf(context),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: MobileTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 18,
                              color: MobileTheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: MobileTheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildAvatarSection(),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.divider.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nicknameController,
                            enabled: !_saving,
                            decoration: const InputDecoration(
                              labelText: '昵称',
                              hintText: '请输入昵称',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '昵称不能为空';
                              }
                              if (value.trim().length > 20) {
                                return '昵称不能超过20个字符';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _bioController,
                            enabled: !_saving,
                            maxLines: 2,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: '个性签名',
                              hintText: '介绍一下自己吧',
                              prefixIcon: Icon(Icons.edit_note_outlined),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildGenderSelector(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildBackgroundImageSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    final colors = MobileColors.of(context);
    final nickname = _nicknameController.text.isNotEmpty
        ? _nicknameController.text
        : (_profile?.nickname ?? '匿');

    String? displayUrl;
    if (_selectedAvatarBase64 != null) {
      displayUrl = 'data:image/jpeg;base64,$_selectedAvatarBase64';
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      displayUrl = _avatarUrl;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _saving ? null : _pickAvatar,
            child: Stack(
              children: [
                _buildAvatarDisplay(displayUrl, nickname),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: MobileTheme.primaryOf(context),
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 3),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _saving ? null : _pickAvatar,
            child: Text(
              '点击更换头像',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: MobileTheme.primaryOf(context),
              ),
            ),
          ),
          if (_selectedAvatarBase64 != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '已选择新图片',
                style: TextStyle(
                  fontSize: 12,
                  color: MobileTheme.success.withValues(alpha: 0.8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarDisplay(String? url, String nickname) {
    if (_selectedAvatarBase64 != null) {
      final bytes = base64Decode(_selectedAvatarBase64!);
      return CircleAvatar(
        radius: 48,
        backgroundColor: MobileTheme.primaryWithAlpha(context, 0.1),
        backgroundImage: MemoryImage(Uint8List.fromList(bytes)),
      );
    }

    return AvatarWidget(avatarUrl: url, nickname: nickname, radius: 48);
  }

  Widget _buildGenderSelector() {
    final colors = MobileColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('性别', style: TextStyle(fontSize: 14, color: colors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildGenderOption('男', Icons.male),
            const SizedBox(width: 12),
            _buildGenderOption('女', Icons.female),
            const SizedBox(width: 12),
            _buildGenderOption('', Icons.remove),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String value, IconData icon) {
    final colors = MobileColors.of(context);
    final isSelected = _gender == value;
    final label = value.isEmpty ? '不显示' : value;

    return Expanded(
      child: GestureDetector(
        onTap: _saving ? null : () => setState(() => _gender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? MobileTheme.primaryWithAlpha(context, 0.1)
                : colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? MobileTheme.primaryOf(context)
                  : colors.divider,
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? MobileTheme.primaryOf(context)
                    : colors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? MobileTheme.primaryOf(context)
                      : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundImageSection() {
    final colors = MobileColors.of(context);
    ImageProvider? imageProvider;
    if (_selectedBgBase64 != null) {
      final bytes = base64Decode(_selectedBgBase64!);
      imageProvider = MemoryImage(Uint8List.fromList(bytes));
    } else if (_backgroundImageUrl != null && _backgroundImageUrl!.isNotEmpty) {
      final resolved = AppConfig.resolveUrl(_backgroundImageUrl!);
      if (resolved.isNotEmpty) {
        imageProvider = NetworkImage(resolved);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '主页背景',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _saving ? null : _pickBackgroundImage,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.divider, width: 0.5),
                image: imageProvider != null
                    ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                    : null,
              ),
              child: imageProvider == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 32,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '点击选择背景图',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.edit,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
            ),
          ),
          if (_selectedBgBase64 != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '已选择新背景图',
                style: TextStyle(
                  fontSize: 12,
                  color: MobileTheme.success.withValues(alpha: 0.8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
