import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/image_picker_adapter.dart';
import '../../core/media/markdown_clipboard_image.dart';
import '../../core/media/picked_image_data.dart';
import '../../core/state/app_providers.dart';
import '../../core/widgets/async_page_state.dart';
import '../../models/post_item.dart';
import '../../models/uploaded_image_item.dart';
import '../../widgets/emoji/emoji_assistant_bar.dart';
import '../../widgets/post_content_body.dart';
import 'create_post_controller.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  static const int _plainTextMaxLength = 3000;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _anonymousAliasController =
      TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  String? _selectedChannel;
  PostStatus _status = PostStatus.ongoing;
  bool _useAnonymousAlias = false;
  bool _useMarkdown = false;
  bool _privateOnly = false;
  int? _selectedPinDurationMinutes;
  bool _pickingImages = false;
  bool _pastingMarkdownImages = false;
  MarkdownClipboardImageDetach? _detachMarkdownPasteListener;
  final List<PickedImageData> _pickedImages = <PickedImageData>[];
  final Map<String, String> _markdownImageUploadIdsByUrl = <String, String>{};

  @override
  void initState() {
    super.initState();
    _detachMarkdownPasteListener = registerMarkdownClipboardImageListener(
      focusNode: _contentFocusNode,
      onImagesPasted: _handleMarkdownImagesPasted,
    );
    Future<void>.microtask(
      () => ref.read(createPostControllerProvider.notifier).loadChannels(),
    );
  }

  @override
  void dispose() {
    _detachMarkdownPasteListener?.call();
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _anonymousAliasController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CreatePostState state = ref.watch(createPostControllerProvider);
    final bool isBusy =
        state.submitting || _pickingImages || _pastingMarkdownImages;
    final List<String> channels =
        state.channels.isNotEmpty ? state.channels : const <String>['未分类'];
    final String selectedChannel = _deriveSelectedChannel(channels);

    return Scaffold(
      appBar: AppBar(title: const Text('发布树洞')),
      body: AsyncPageState(
        loading: state.loadingChannels,
        loadingLabel: '加载频道中...',
        error: state.error,
        onRetry: () =>
            ref.read(createPostControllerProvider.notifier).loadChannels(),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            if (isBusy)
              _ProgressCard(
                text: _pastingMarkdownImages
                    ? '上传粘贴图片中...'
                    : _pickingImages
                        ? '读取图片中...'
                        : (state.progressText ?? '提交中...'),
              ),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Shortcuts(
                    shortcuts: const <ShortcutActivator, Intent>{
                      SingleActivator(LogicalKeyboardKey.tab):
                          DoNothingAndStopPropagationIntent(),
                      SingleActivator(LogicalKeyboardKey.tab, shift: true):
                          DoNothingAndStopPropagationIntent(),
                    },
                    child: TextFormField(
                      controller: _titleController,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        hintText: '一句话概括你的问题或诉求',
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入标题';
                        }
                        if (value.trim().length < 4) {
                          return '标题至少 4 个字';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: _useMarkdown,
                    onChanged: isBusy
                        ? null
                        : _handleMarkdownToggle,
                    title: const Text('使用 Markdown 编辑'),
                    subtitle: const Text('开启后可编写 Markdown 源码，发出后按渲染效果展示'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: ValueKey<String>(
                      _useMarkdown ? 'markdown-editor' : 'plain-editor',
                    ),
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    minLines: 6,
                    maxLines: 10,
                    maxLength: _useMarkdown ? null : _plainTextMaxLength,
                    maxLengthEnforcement: _useMarkdown
                        ? null
                        : MaxLengthEnforcement.enforced,
                    autocorrect: !_useMarkdown,
                    enableSuggestions: !_useMarkdown,
                    enableIMEPersonalizedLearning: !_useMarkdown,
                    smartDashesType: _useMarkdown
                        ? SmartDashesType.disabled
                        : SmartDashesType.enabled,
                    smartQuotesType: _useMarkdown
                        ? SmartQuotesType.disabled
                        : SmartQuotesType.enabled,
                    spellCheckConfiguration: _useMarkdown
                        ? const SpellCheckConfiguration.disabled()
                        : null,
                    decoration: InputDecoration(
                      alignLabelWithHint: true,
                      labelText: _useMarkdown ? 'Markdown 源码' : '正文',
                      hintText: _useMarkdown
                          ? '# 标题\n- 列表项\n> 引用\n```dart\nprint("Hello");\n```'
                          : '描述越完整，越容易获得帮助',
                      helperText: _useMarkdown
                          ? 'Markdown 模式不限制字数，支持直接粘贴图片并自动插入链接。切换模式会清空当前正文。'
                          : '纯文本模式最多 3000 字。切换模式会清空当前正文。',
                      helperMaxLines: 2,
                    ),
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入正文';
                      }
                      if (value.trim().length < 8) {
                        return '正文至少 8 个字';
                      }
                      if (!_useMarkdown && value.length > _plainTextMaxLength) {
                        return '纯文本正文最多 $_plainTextMaxLength 字';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),
                  EmojiAssistantBar(
                    controller: _contentController,
                    compact: true,
                  ),
                  if (_useMarkdown) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '实时预览',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _contentController,
                            builder: (
                              BuildContext context,
                              TextEditingValue value,
                              Widget? child,
                            ) {
                              final String source = value.text.trim();
                              if (source.isEmpty) {
                                return const Text(
                                  '输入 Markdown 源码后，这里会显示渲染效果。',
                                  style: TextStyle(color: Colors.black54),
                                );
                              }
                              return PostContentBody(
                                content: '',
                                contentFormat: 'markdown',
                                markdownSource: source,
                                selectable: false,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedChannel,
                    decoration: const InputDecoration(labelText: '频道'),
                    items: channels
                        .map(
                          (String channel) => DropdownMenuItem<String>(
                            value: channel,
                            child: Text(channel),
                          ),
                        )
                        .toList(),
                    onChanged: isBusy
                        ? null
                        : (String? value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _selectedChannel = value;
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<PostStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: '状态'),
                    items: PostStatus.values
                        .map(
                          (PostStatus status) => DropdownMenuItem<PostStatus>(
                            value: status,
                            child: Text(status.label),
                          ),
                        )
                        .toList(),
                    onChanged: isBusy
                        ? null
                        : (PostStatus? value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _status = value;
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: '标签（可选）',
                      hintText: '例如：北校区, 学习, 周末',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _useAnonymousAlias,
                    onChanged: isBusy
                        ? null
                        : (bool value) {
                            setState(() {
                              _useAnonymousAlias = value;
                            });
                          },
                    title: const Text('本帖使用匿名身份'),
                    subtitle: const Text('仅影响当前帖子，不影响你的账号昵称'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_useAnonymousAlias) ...<Widget>[
                    TextFormField(
                      controller: _anonymousAliasController,
                      decoration: const InputDecoration(
                        labelText: '匿名昵称（可选）',
                        hintText: '例如：热心同学',
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        if (value.trim().length > 24) {
                          return '匿名昵称最长 24 个字符';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _privateOnly ? 'private' : 'public',
                    decoration: const InputDecoration(labelText: '可见范围'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'public',
                        child: Text('所有人可见'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'private',
                        child: Text('仅自己可见'),
                      ),
                    ],
                    onChanged: isBusy
                        ? null
                        : (String? value) {
                            setState(() {
                              _privateOnly = value == 'private';
                            });
                          },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _privateOnly
                        ? '仅你自己能在“我的帖子”里看到这条内容。'
                        : '公开帖子中，不匿名且你开启“允许陌生人私信”时，其他人可直接私信你。',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (state.isLevelOneUser) ...<Widget>[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      initialValue: _selectedPinDurationMinutes,
                      decoration: InputDecoration(
                        labelText: '发帖后立即置顶（可选）',
                        helperText: '当前身份：${state.userLevelLabel}',
                      ),
                      items: const <DropdownMenuItem<int?>>[
                        DropdownMenuItem<int?>(value: null, child: Text('不置顶')),
                        DropdownMenuItem<int?>(value: 30, child: Text('30 分钟')),
                        DropdownMenuItem<int?>(value: 60, child: Text('1 小时')),
                        DropdownMenuItem<int?>(value: 120, child: Text('2 小时')),
                        DropdownMenuItem<int?>(value: 180, child: Text('3 小时')),
                        DropdownMenuItem<int?>(value: 1440, child: Text('1 天')),
                        DropdownMenuItem<int?>(value: 4320, child: Text('3 天')),
                      ],
                      onChanged: isBusy
                          ? null
                          : (int? value) {
                              setState(() {
                                _selectedPinDurationMinutes = value;
                              });
                            },
                    ),
                  ],
                  const Divider(height: 28),
                  Row(
                    children: <Widget>[
                      Text(
                        '图片（${_pickedImages.length}/9）',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: isBusy ? null : _pickImages,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('选择图片'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_pickedImages.isEmpty)
                    const Text(
                      '未选择图片。支持 jpg/png/webp/gif。',
                      style: TextStyle(color: Colors.black54),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _pickedImages
                          .asMap()
                          .entries
                          .map(
                            (MapEntry<int, PickedImageData> entry) =>
                                _PickedImageCard(
                              image: entry.value,
                              onRemove: isBusy
                                  ? null
                                  : () {
                                      setState(() {
                                        _pickedImages.removeAt(entry.key);
                                      });
                                    },
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isBusy ? null : () => _submit(selectedChannel),
                      icon: const Icon(Icons.send_rounded),
                      label: Text(state.submitting ? '发布中...' : '发布帖子'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _deriveSelectedChannel(List<String> channels) {
    if (_selectedChannel != null && channels.contains(_selectedChannel)) {
      return _selectedChannel!;
    }
    final String fallback = channels.first;
    _selectedChannel = fallback;
    return fallback;
  }

  Future<void> _pickImages() async {
    if (_pickingImages) {
      return;
    }
    setState(() {
      _pickingImages = true;
    });

    try {
      final List<PickedImageData> selected =
          await pickImageFiles(multiple: true);
      if (!mounted || selected.isEmpty) {
        return;
      }

      const int maxImages = 9;
      final int remaining = maxImages - _pickedImages.length;
      if (remaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('最多上传 9 张图片')),
        );
        return;
      }

      final List<PickedImageData> accepted = selected.take(remaining).toList();
      setState(() {
        _pickedImages.addAll(accepted);
      });

      if (selected.length > accepted.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '最多上传 9 张图片，已自动保留前 $remaining 张。超出 ${selected.length - accepted.length} 张未选中。',
            ),
          ),
        );
      }

      // 检查是否有大文件
      final List<PickedImageData> largeFiles = accepted
          .where((PickedImageData img) => img.sizeBytes > 5 * 1024 * 1024)
          .toList();
      if (largeFiles.isNotEmpty && accepted.length == remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '提示：${largeFiles.length} 张图片超过 5MB，可能上传较慢。',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pickingImages = false;
        });
      }
    }
  }

  Future<void> _submit(String selectedChannel) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _pruneMarkdownImageMappings();
    final String rawContent = _contentController.text;
    final String submittedContent = _useMarkdown ? rawContent : rawContent.trim();
    final List<String> tags = _tagsController.text
        .split(RegExp(r'[,，\s\n]+'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList();
    final List<UploadPayload> uploadPayloads = _pickedImages
        .map(
          (PickedImageData image) => UploadPayload(
            fileName: image.fileName,
            contentType: image.contentType,
            dataBase64: image.dataBase64,
            sizeBytes: image.sizeBytes,
          ),
        )
        .toList();
    final CreatePostState state = ref.read(createPostControllerProvider);

    final PostItem? created =
        await ref.read(createPostControllerProvider.notifier).submit(
              title: _titleController.text.trim(),
              content: submittedContent,
              useMarkdown: _useMarkdown,
              channel: selectedChannel,
              tags: tags,
              privateOnly: _privateOnly,
              status: _status,
              useAnonymousAlias: _useAnonymousAlias,
              anonymousAlias: _useAnonymousAlias
                  ? _anonymousAliasController.text.trim()
                  : null,
              pinDurationMinutes:
                  state.isLevelOneUser ? _selectedPinDurationMinutes : null,
              uploadPayloads: uploadPayloads,
              preUploadedImageIds: _useMarkdown
                  ? _markdownImageUploadIdsByUrl.values.toList()
                  : const <String>[],
            );

    if (!mounted || created == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created.isPinned ? '帖子发布成功，已置顶展示。' : '帖子发布成功，已立即展示。',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }

  void _handleMarkdownToggle(bool value) {
    if (_useMarkdown == value) {
      return;
    }
    setState(() {
      _useMarkdown = value;
      _contentController.value = const TextEditingValue();
      _markdownImageUploadIdsByUrl.clear();
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            value
                ? '已切换到 Markdown 编辑，当前正文已清空。'
                : '已切换到纯文本编辑，当前正文已清空。',
          ),
        ),
      );
  }

  Future<void> _handleMarkdownImagesPasted(List<PickedImageData> images) async {
    if (!_useMarkdown || !mounted || images.isEmpty) {
      return;
    }

    _pruneMarkdownImageMappings();
    const int maxImages = 9;
    final int remaining =
        maxImages - (_pickedImages.length + _markdownImageUploadIdsByUrl.length);
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多上传 9 张图片')),
      );
      return;
    }

    final List<PickedImageData> accepted = images.take(remaining).toList();
    if (accepted.isEmpty) {
      return;
    }

    setState(() {
      _pastingMarkdownImages = true;
    });

    try {
      final List<String> snippets = <String>[];
      for (final PickedImageData image in accepted) {
        final UploadedImageItem uploaded =
            await ref.read(postRepositoryProvider).uploadImage(
                  fileName: image.fileName,
                  contentType: image.contentType,
                  dataBase64: image.dataBase64,
                );
        final String alt = _deriveMarkdownImageAlt(image.fileName);
        snippets.add('![$alt](${uploaded.url})');
        _markdownImageUploadIdsByUrl[uploaded.url] = uploaded.id;
      }
      _insertMarkdownSnippet(snippets.join('\n\n'));

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('已插入 ${accepted.length} 张 Markdown 图片'),
          ),
        );
      if (images.length > accepted.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '最多上传 9 张图片，超出 ${images.length - accepted.length} 张未插入。',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('粘贴图片失败：$error')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _pastingMarkdownImages = false;
        });
      }
    }
  }

  void _insertMarkdownSnippet(String snippet) {
    final TextEditingValue currentValue = _contentController.value;
    final TextSelection selection = currentValue.selection.isValid
        ? currentValue.selection
        : TextSelection.collapsed(offset: currentValue.text.length);
    final int start = selection.start.clamp(0, currentValue.text.length);
    final int end = selection.end.clamp(0, currentValue.text.length);
    final String before = currentValue.text.substring(0, start);
    final String after = currentValue.text.substring(end);

    String inserted = snippet;
    if (before.isNotEmpty && !before.endsWith('\n')) {
      inserted = '\n\n$inserted';
    }
    if (after.isNotEmpty && !after.startsWith('\n')) {
      inserted = '$inserted\n\n';
    }

    final String nextText = '$before$inserted$after';
    final int caretOffset = (before + inserted).length;
    _contentController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: caretOffset),
    );
  }

  void _pruneMarkdownImageMappings() {
    final String source = _contentController.text;
    _markdownImageUploadIdsByUrl.removeWhere(
      (String url, String _) => !source.contains(url),
    );
  }

  String _deriveMarkdownImageAlt(String fileName) {
    final String trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return '图片';
    }
    final int dotIndex = trimmed.lastIndexOf('.');
    final String baseName = dotIndex > 0 ? trimmed.substring(0, dotIndex) : trimmed;
    final String sanitized = baseName.trim();
    return sanitized.isEmpty ? '图片' : sanitized;
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _PickedImageCard extends StatelessWidget {
  const _PickedImageCard({
    required this.image,
    required this.onRemove,
  });

  final PickedImageData image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    Widget preview;
    try {
      preview = Image.memory(
        base64Decode(image.dataBase64),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 92,
      );
    } catch (_) {
      preview = Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined),
      );
    }

    final String sizeStr = _formatFileSize(image.sizeBytes);
    final bool isLargeFile = image.sizeBytes > 5 * 1024 * 1024;

    return SizedBox(
      width: 140,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      height: 92,
                      child: preview,
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          onTap: onRemove,
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    if (isLargeFile)
                      Positioned(
                        bottom: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            sizeStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                image.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              if (!isLargeFile)
                Text(
                  sizeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
