class MyCommentItem {
  MyCommentItem({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.content,
    required this.timeText,
  });

  final String id;
  final String postId;
  final String postTitle;
  final String content;
  final String timeText;

  factory MyCommentItem.fromJson(Map<String, dynamic> json) {
    return MyCommentItem(
      id: (json['id'] ?? json['commentId'] ?? '').toString(),
      postId: (json['postId'] ?? json['post_id'] ?? '').toString(),
      postTitle: (json['postTitle'] ?? json['post'] ?? '原帖').toString(),
      content: (json['content'] ?? '-').toString(),
      timeText:
          (json['timeText'] ?? json['time'] ?? json['createdAt'] ?? '-')
              .toString(),
    );
  }
}
