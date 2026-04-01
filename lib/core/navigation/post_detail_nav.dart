import 'package:flutter/material.dart';

import '../../repositories/app_repositories.dart';
import '../../models/post_item.dart';
import '../../features/post/post_detail_page.dart';
import 'url_query_state.dart';

Future<PostItem?> openPostDetailPage(
  BuildContext context, {
  required PostItem post,
}) async {
  setPostIdOnUrl(post.id);
  try {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailPage(post: post),
      ),
    );
    try {
      return await AppRepositories.posts.fetchPostDetail(post.id);
    } catch (_) {
      return null;
    }
  } finally {
    setPostIdOnUrl(null);
  }
}
