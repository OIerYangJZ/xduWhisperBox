import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/state/mobile_providers.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'package:xdu_treehole_web/core/auth/auth_store.dart';

/// 发帖页 — Instagram 极简风格
/// 无卡片、无冗余设置项、底部工具栏图标操作
class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _imagePicker = ImagePicker();

  String _selectedChannel = '综合';
  List<String> _selectedTags = [];
  PostStatus _postStatus = PostStatus.ongoing;

  final _anonymousAliasController = TextEditingController();
  bool _isAnonymous = false;
  String _anonymousAlias = '';

  int? _selectedPinDurationMinutes;
  bool _showPinSelector = false;
  bool _isLevelOneUser =
      AuthStore.instance.currentUser?.isLevelOneUser ?? false;

  final List<XFile> _selectedImages = [];
  final List<String> _uploadedImageIds = [];
  bool _isUploading = false;
  bool _isPublishing = false;

  List<String> _channels = [];
  bool _isLoadingChannels = true;

  // Inline selector states
  bool _showChannelSelector = false;
  bool _showTagSelector = false;
  bool _showStatusSelector = false;

  // Visibility
  bool _privateOnly = false;

  @override
  void initState() {
    super.initState();
    _loadChannels();
    _loadUserLevel();
    _contentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _anonymousAliasController.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    try {
      final postRepo = ref.read(postRepositoryProvider);
      final channels = await postRepo.fetchChannels();
      if (mounted) {
        setState(() {
          // 过滤掉"全部"，它不是真实频道
          _channels = channels.isNotEmpty
              ? channels.where((c) => c != '全部').toList()
              : ['综合', '学习', '吐槽日常', '失物招领', '二手交易', '找搭子'];
          _isLoadingChannels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _channels = ['综合', '学习', '吐槽日常', '失物招领', '二手交易', '找搭子'];
          _isLoadingChannels = false;
        });
      }
    }
  }

  Future<void> _loadUserLevel() async {
    try {
      final profile = await ref.read(userRepositoryProvider).fetchProfile();
      AuthStore.instance.setCurrentUser(profile);
      if (!mounted) return;
      setState(() {
        _isLevelOneUser = profile.isLevelOneUser;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLevelOneUser =
            AuthStore.instance.currentUser?.isLevelOneUser ?? false;
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        final maxImages = 9 - _selectedImages.length;
        final imagesToAdd = images.take(maxImages).toList();

        setState(() {
          _selectedImages.addAll(imagesToAdd);
        });

        _uploadImages(imagesToAdd);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
    }
  }

  Future<void> _uploadImages(List<XFile> images) async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);

      for (final image in images) {
        final bytes = await image.readAsBytes();
        final base64Data = base64Encode(bytes);
        final fileName = image.name;
        final contentType = _getContentType(image.path);

        try {
          final uploadedImage = await postRepo.uploadImage(
            fileName: fileName,
            contentType: contentType,
            dataBase64: base64Data,
          );
          _uploadedImageIds.add(uploadedImage.id);
        } catch (e) {
          debugPrint('图片上传失败: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('图片上传失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  String _getContentType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _generateAnonymousAlias() {
    final adjectives = ['神秘', '路过的', '隔壁的', '匿名的', '安静的', '好奇的', '悠闲的', '低调的'];
    final nouns = ['同学', '路人', '学长', '学弟', '学妹', '小伙伴', '小伙伴', '小伙伴'];
    final adj =
        adjectives[(DateTime.now().millisecondsSinceEpoch ~/ 13) %
            adjectives.length];
    final noun =
        nouns[(DateTime.now().millisecondsSinceEpoch ~/ 17) % nouns.length];
    return '$adj$noun';
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (index < _uploadedImageIds.length) {
        _uploadedImageIds.removeAt(index);
      }
    });
  }

  Future<void> _handlePublish() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入帖子内容')));
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);
      final input = CreatePostInput(
        title: _titleController.text.trim(),
        content: content,
        channel: _selectedChannel,
        tags: _selectedTags,
        allowComment: true,
        allowDm: !_isAnonymous,
        privateOnly: _privateOnly,
        status: _postStatus,
        hasImage: _selectedImages.isNotEmpty,
        imageUploadIds: _uploadedImageIds,
        useAnonymousAlias: _isAnonymous,
        anonymousAlias: _isAnonymous ? _anonymousAliasController.text : null,
        pinDurationMinutes: _selectedPinDurationMinutes,
      );

      await postRepo.createPost(input);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('发布成功！')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发布失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  void _confirmDiscard() {
    if (_titleController.text.isEmpty &&
        _contentController.text.isEmpty &&
        _selectedImages.isEmpty) {
      context.pop();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃编辑？'),
        content: const Text('确定要放弃当前编辑内容吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              this.context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: MobileTheme.error),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
  }

  bool get _canPublish =>
      _contentController.text.trim().isNotEmpty && !_isPublishing;

  bool get _canPin => _isLevelOneUser;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final contentLen = _contentController.text.length;
    final canPublish = _canPublish;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        scrolledUnderElevation: 0.5,
        toolbarHeight: 48,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textPrimary),
          onPressed: _confirmDiscard,
        ),
        title: Text(
          '$contentLen / 2000',
          style: TextStyle(
            fontSize: 13,
            color: contentLen > 2000 ? MobileTheme.error : colors.textSecondary,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: canPublish ? _handlePublish : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                disabledBackgroundColor: colors.divider,
                backgroundColor: MobileTheme.primaryOf(context),
              ),
              child: _isPublishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('发布'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 频道选择行
                  _buildCompactSelector(
                    label: '频道',
                    value: _selectedChannel,
                    isExpanded: _showChannelSelector,
                    onTap: () {
                      setState(() {
                        _showChannelSelector = !_showChannelSelector;
                        _showTagSelector = false;
                        _showStatusSelector = false;
                      });
                    },
                    children: _isLoadingChannels
                        ? [const SizedBox(width: 16)]
                        : _channels
                              .map(
                                (c) => _PillChip(
                                  label: c,
                                  isSelected: c == _selectedChannel,
                                  onTap: () {
                                    setState(() {
                                      _selectedChannel = c;
                                      _showChannelSelector = false;
                                    });
                                  },
                                ),
                              )
                              .toList(),
                  ),

                  Divider(height: 0.5, color: colors.divider),

                  // 标题输入（无边框极简）
                  TextField(
                    controller: _titleController,
                    maxLength: 50,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '标题（选填）',
                      hintStyle: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    ),
                  ),

                  // 正文输入（minLines: 8，多行动态扩展）
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 8,
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.textPrimary,
                      height: 1.6,
                    ),
                    decoration: InputDecoration(
                      hintText: '分享你的想法...',
                      hintStyle: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    ),
                  ),

                  // 已选标签横排（紧凑）
                  if (_selectedTags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _selectedTags
                            .map(
                              (tag) => _SelectedTagChip(
                                label: tag,
                                onRemove: () {
                                  setState(() {
                                    _selectedTags.remove(tag);
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),

                  // 匿名昵称编辑行（仅在匿名模式下显示）
                  if (_isAnonymous)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 16,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _anonymousAliasController,
                              maxLength: 20,
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: '自定义匿名昵称（选填）',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: colors.textTertiary,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                counterText: '',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 已选状态（内联紧凑展示）
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(children: [_StatusBadge(status: _postStatus)]),
                  ),

                  // 图片预览横排
                  if (_selectedImages.isNotEmpty) _buildImagePreview(),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // 上传进度提示
          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '图片上传中...',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
              ),
            ),

          // 底部工具栏
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                top: BorderSide(color: colors.divider, width: 0.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 内联选择器展开区（频道 / 标签 / 状态）
                  if (_showChannelSelector ||
                      _showTagSelector ||
                      _showStatusSelector ||
                      _showPinSelector)
                    _buildInlineSelectorArea(),

                  // 工具栏图标行
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Row(
                      children: [
                        // 图片按钮
                        _ToolbarIconButton(
                          icon: Icons.image_outlined,
                          onTap: _pickImages,
                        ),
                        // 标签按钮
                        _ToolbarIconButton(
                          icon: Icons.tag,
                          onTap: () {
                            setState(() {
                              _showTagSelector = !_showTagSelector;
                              _showChannelSelector = false;
                              _showStatusSelector = false;
                            });
                          },
                        ),
                        // 状态按钮
                        _ToolbarIconButton(
                          icon: _postStatus == PostStatus.resolved
                              ? Icons.check_circle
                              : _postStatus == PostStatus.closed
                              ? Icons.lock
                              : Icons.help_outline,
                          onTap: () {
                            setState(() {
                              _showStatusSelector = !_showStatusSelector;
                              _showChannelSelector = false;
                              _showTagSelector = false;
                            });
                          },
                        ),
                        // 匿名按钮
                        _ToolbarIconButton(
                          icon: _isAnonymous
                              ? Icons.visibility_off
                              : Icons.visibility_off_outlined,
                          isActive: _isAnonymous,
                          onTap: () {
                            setState(() {
                              _isAnonymous = !_isAnonymous;
                              if (_isAnonymous) {
                                _anonymousAlias = _generateAnonymousAlias();
                                _anonymousAliasController.text =
                                    _anonymousAlias;
                              } else {
                                _anonymousAlias = '';
                                _anonymousAliasController.clear();
                              }
                            });
                          },
                        ),
                        // 置顶按钮
                        if (_canPin)
                          _ToolbarIconButton(
                            icon: _selectedPinDurationMinutes != null
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            isActive: _selectedPinDurationMinutes != null,
                            onTap: () {
                              setState(() {
                                _showPinSelector = !_showPinSelector;
                                _showChannelSelector = false;
                                _showTagSelector = false;
                                _showStatusSelector = false;
                              });
                            },
                          ),
                        const Spacer(),
                        // 可见性选项
                        _VisibilitySelector(
                          privateOnly: _privateOnly,
                          onChanged: (privateOnly) {
                            setState(() {
                              _privateOnly = privateOnly;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSelector({
    required String label,
    required String value,
    required bool isExpanded,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    final colors = MobileColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: MobileTheme.primaryWithAlpha(context, 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MobileTheme.primaryOf(context),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: colors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(spacing: 6, runSpacing: 6, children: children),
          ),
      ],
    );
  }

  Widget _buildInlineSelectorArea() {
    final colors = MobileColors.of(context);
    if (_showStatusSelector) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: PostStatus.values.map((s) {
            final isSelected = s == _postStatus;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _postStatus = s;
                    _showStatusSelector = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MobileTheme.primaryWithAlpha(context, 0.12)
                        : colors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? MobileTheme.primaryOf(context)
                          : colors.divider,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        s == PostStatus.resolved
                            ? Icons.check_circle
                            : s == PostStatus.closed
                            ? Icons.lock
                            : Icons.help_outline,
                        size: 13,
                        color: isSelected
                            ? MobileTheme.primaryOf(context)
                            : colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        s.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? MobileTheme.primaryOf(context)
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    if (_showTagSelector) {
      return _TagInlineSheet(
        selectedTags: _selectedTags,
        onSelect: (tags) {
          setState(() {
            _selectedTags = tags;
            _showTagSelector = false;
          });
        },
        onClose: () {
          setState(() {
            _showTagSelector = false;
          });
        },
      );
    }

    if (_showPinSelector) {
      const pinOptions = <_PinOption>[
        _PinOption(label: '不置顶', minutes: null),
        _PinOption(label: '30 分钟', minutes: 30),
        _PinOption(label: '1 小时', minutes: 60),
        _PinOption(label: '2 小时', minutes: 120),
        _PinOption(label: '3 小时', minutes: 180),
        _PinOption(label: '1 天', minutes: 1440),
        _PinOption(label: '3 天', minutes: 4320),
      ];
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.push_pin,
                  size: 16,
                  color: MobileTheme.primaryOf(context),
                ),
                const SizedBox(width: 6),
                Text(
                  '发帖后立即置顶',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MobileTheme.primaryOf(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: pinOptions.map((opt) {
                final isSelected = opt.minutes == _selectedPinDurationMinutes;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPinDurationMinutes = opt.minutes;
                      _showPinSelector = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? MobileTheme.primaryWithAlpha(context, 0.12)
                          : colors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? MobileTheme.primaryOf(context)
                            : colors.divider,
                      ),
                    ),
                    child: Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? MobileTheme.primaryOf(context)
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildImagePreview() {
    final colors = MobileColors.of(context);
    return SizedBox(
      height: 80,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length + 1,
        itemBuilder: (context, index) {
          if (index == _selectedImages.length) {
            return GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 80,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.divider),
                ),
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 24,
                  color: colors.textSecondary,
                ),
              ),
            );
          }

          final image = _selectedImages[index];
          return Stack(
            children: [
              Container(
                width: 80,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: colors.background,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(image.path), fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 4,
                right: 10,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PillChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? MobileTheme.primaryWithAlpha(context, 0.12)
              : colors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MobileTheme.primaryOf(context) : colors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? MobileTheme.primaryOf(context)
                : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SelectedTagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _SelectedTagChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: MobileTheme.primaryWithAlpha(context, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MobileTheme.primaryWithAlpha(context, 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: MobileTheme.primaryOf(context),
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 12,
              color: MobileTheme.primaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PostStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final displayLabel = status.label;
    final displayColor = status == PostStatus.resolved
        ? MobileTheme.success
        : status == PostStatus.closed
        ? MobileTheme.textSecondary
        : MobileTheme.primaryOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: displayColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        displayLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: displayColor,
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolbarIconButton({
    required this.icon,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive
              ? MobileTheme.primaryWithAlpha(context, 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isActive
              ? MobileTheme.primaryOf(context)
              : colors.textSecondary,
        ),
      ),
    );
  }
}

class _VisibilitySelector extends StatelessWidget {
  final bool privateOnly;
  final ValueChanged<bool> onChanged;

  const _VisibilitySelector({
    required this.privateOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return PopupMenuButton<String>(
      offset: const Offset(0, -120),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colors.surface,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            privateOnly ? Icons.lock_outline : Icons.public,
            size: 18,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_up, size: 18, color: colors.textTertiary),
        ],
      ),
      onSelected: (value) {
        switch (value) {
          case 'all':
            onChanged(false);
            break;
          case 'private':
            onChanged(true);
            break;
        }
      },
      itemBuilder: (context) => [
        _buildVisibilityItem(
          context,
          'all',
          Icons.public,
          '所有人可见',
          !privateOnly,
        ),
        _buildVisibilityItem(
          context,
          'private',
          Icons.lock_outline,
          '仅自己可见',
          privateOnly,
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildVisibilityItem(
    BuildContext context,
    String value,
    IconData icon,
    String label,
    bool isSelected,
  ) {
    final colors = MobileColors.of(context);
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected
                ? MobileTheme.primaryOf(context)
                : colors.textSecondary,
          ),
          const SizedBox(width: 10),
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
          const Spacer(),
          if (isSelected)
            Icon(Icons.check, size: 16, color: MobileTheme.primaryOf(context)),
        ],
      ),
    );
  }
}

class _TagInlineSheet extends StatefulWidget {
  final List<String> selectedTags;
  final Function(List<String>) onSelect;
  final VoidCallback onClose;

  const _TagInlineSheet({
    required this.selectedTags,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_TagInlineSheet> createState() => _TagInlineSheetState();
}

class _TagInlineSheetState extends State<_TagInlineSheet> {
  late List<String> _tempSelected;
  final _customTagController = TextEditingController();

  final _allTags = [
    '求助',
    '学习',
    '二手',
    '组队',
    '经验',
    '吐槽',
    '交友',
    '活动',
    '租房',
    '实习',
    '考研',
    '保研',
    '出国',
    '竞赛',
    '社团',
  ];

  @override
  void initState() {
    super.initState();
    _tempSelected = List.from(widget.selectedTags);
  }

  @override
  void dispose() {
    _customTagController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_tempSelected.contains(tag)) {
        _tempSelected.remove(tag);
      } else {
        if (_tempSelected.length < 5) {
          _tempSelected.add(tag);
        }
      }
    });
  }

  void _addCustomTag() {
    final input = _customTagController.text.trim();
    if (input.isEmpty) return;
    final newTags = input
        .split(RegExp(r'[,，\s\n]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && !_tempSelected.contains(t))
        .toList();

    if (newTags.isEmpty) return;
    final remaining = 5 - _tempSelected.length;
    if (remaining <= 0) return;

    setState(() {
      _tempSelected.addAll(newTags.take(remaining));
      _customTagController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '标签（${_tempSelected.length}/5）',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      widget.onSelect(_tempSelected);
                    },
                    child: Text(
                      '完成',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MobileTheme.primaryOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 预设标签
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _allTags.map((tag) {
              final isSelected = _tempSelected.contains(tag);
              return GestureDetector(
                onTap: () => _toggleTag(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MobileTheme.primaryWithAlpha(context, 0.12)
                        : colors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? MobileTheme.primaryOf(context)
                          : colors.divider,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? MobileTheme.primaryOf(context)
                          : colors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // 自定义标签输入
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customTagController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '自定义标签',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: colors.textTertiary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: MobileTheme.primaryOf(context),
                      ),
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addCustomTag(),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _addCustomTag,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('添加'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinOption {
  final String label;
  final int? minutes;
  const _PinOption({required this.label, required this.minutes});
}
