import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_providers.dart';
import '../../data/mock_data.dart';
import '../../models/post_item.dart';
import '../../models/uploaded_image_item.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/post_repository.dart';

class CreatePostState {
  const CreatePostState({
    this.channels = kChannels,
    this.loadingChannels = true,
    this.userLevel = 2,
    this.userLevelLabel = '二级用户',
    this.isLevelOneUser = false,
    this.submitting = false,
    this.progressText,
    this.error,
  });

  final List<String> channels;
  final bool loadingChannels;
  final int userLevel;
  final String userLevelLabel;
  final bool isLevelOneUser;
  final bool submitting;
  final String? progressText;
  final String? error;

  CreatePostState copyWith({
    List<String>? channels,
    bool? loadingChannels,
    int? userLevel,
    String? userLevelLabel,
    bool? isLevelOneUser,
    bool? submitting,
    String? progressText,
    String? error,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return CreatePostState(
      channels: channels ?? this.channels,
      loadingChannels: loadingChannels ?? this.loadingChannels,
      userLevel: userLevel ?? this.userLevel,
      userLevelLabel: userLevelLabel ?? this.userLevelLabel,
      isLevelOneUser: isLevelOneUser ?? this.isLevelOneUser,
      submitting: submitting ?? this.submitting,
      progressText: clearProgress ? null : (progressText ?? this.progressText),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class UploadPayload {
  UploadPayload({
    required this.fileName,
    required this.contentType,
    required this.dataBase64,
    required this.sizeBytes,
  });

  final String fileName;
  final String contentType;
  final String dataBase64;
  final int sizeBytes;
}

class CreatePostController extends StateNotifier<CreatePostState> {
  CreatePostController(this._ref) : super(const CreatePostState());

  final Ref _ref;

  Future<void> loadChannels() async {
    state = state.copyWith(loadingChannels: true, clearError: true);
    try {
      final List<String> channels =
          await _ref.read(postRepositoryProvider).fetchChannels();
      final profile = await AppRepositories.users.fetchProfile();
      state = state.copyWith(
        channels: channels.isEmpty ? kChannels : channels,
        loadingChannels: false,
        userLevel: profile.userLevel,
        userLevelLabel: profile.userLevelLabel,
        isLevelOneUser: profile.isLevelOneUser,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        loadingChannels: false,
        error: '加载频道失败：$error',
      );
    }
  }

  Future<PostItem?> submit({
    required String title,
    required String content,
    required bool useMarkdown,
    required String channel,
    required List<String> tags,
    required bool privateOnly,
    required PostStatus status,
    required bool useAnonymousAlias,
    String? anonymousAlias,
    int? pinDurationMinutes,
    required List<UploadPayload> uploadPayloads,
    List<String> preUploadedImageIds = const <String>[],
  }) async {
    state = state.copyWith(
      submitting: true,
      progressText: uploadPayloads.isEmpty ? '发布帖子中...' : '上传图片中...',
      clearError: true,
    );

    try {
      final List<String> uploadedIds = List<String>.from(preUploadedImageIds);
      final List<String> uploadedUrls = <String>[];
      for (int i = 0; i < uploadPayloads.length; i += 1) {
        state = state.copyWith(
          progressText: '上传图片 ${i + 1}/${uploadPayloads.length}...',
        );
        final UploadPayload payload = uploadPayloads[i];
        final UploadedImageItem uploaded =
            await _ref.read(postRepositoryProvider).uploadImage(
                  fileName: payload.fileName,
                  contentType: payload.contentType,
                  dataBase64: payload.dataBase64,
                );
        uploadedIds.add(uploaded.id);
        uploadedUrls.add(uploaded.url);
      }

      state = state.copyWith(progressText: '提交帖子中...');
      final PostItem created =
          await _ref.read(postRepositoryProvider).createPost(
                CreatePostInput(
                  title: title,
                  content: content,
                  contentFormat: useMarkdown ? 'markdown' : 'plain',
                  markdownSource: useMarkdown ? content : null,
                  channel: channel,
                  tags: tags,
                  allowComment: true,
                  allowDm: !useAnonymousAlias,
                  privateOnly: privateOnly,
                  status: status,
                  hasImage: uploadedIds.isNotEmpty,
                  pinDurationMinutes: pinDurationMinutes,
                  imageUploadIds: uploadedIds,
                  useAnonymousAlias: useAnonymousAlias,
                  anonymousAlias: anonymousAlias,
                ),
              );

      state = state.copyWith(
        submitting: false,
        clearProgress: true,
        clearError: true,
      );

      if (uploadedUrls.isNotEmpty) {
        return created.copyWith(
          imageUrls: uploadedUrls,
          uploadedImageIds: uploadedIds,
        );
      }
      return created;
    } catch (error) {
      state = state.copyWith(
        submitting: false,
        clearProgress: true,
        error: '发布失败：$error',
      );
      return null;
    }
  }
}

final createPostControllerProvider =
    StateNotifierProvider.autoDispose<CreatePostController, CreatePostState>(
  (Ref ref) => CreatePostController(ref),
);
