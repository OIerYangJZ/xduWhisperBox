import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';

/// 我的评论列表页
class MyCommentsPage extends ConsumerStatefulWidget {
  const MyCommentsPage({super.key});

  @override
  ConsumerState<MyCommentsPage> createState() => _MyCommentsPageState();
}

class _MyCommentsPageState extends ConsumerState<MyCommentsPage> {
  bool _isLoading = true;
  List<dynamic> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _comments = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text('我的评论'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _comments.isEmpty
              ? _buildEmptyView()
              : _buildList(),
    );
  }

  Widget _buildEmptyView() {
    final colors = MobileColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.comment_outlined,
              size: 64, color: colors.textTertiary),
          SizedBox(height: 16),
          Text('暂无评论',
              style: TextStyle(fontSize: 16, color: colors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildList() {
    final colors = MobileColors.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _comments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: colors.divider.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('评论内容...',
                  style:
                      TextStyle(fontSize: 14, color: colors.textPrimary)),
              SizedBox(height: 8),
              Text('发表于 帖子标题',
                  style:
                      TextStyle(fontSize: 12, color: colors.textTertiary)),
            ],
          ),
        );
      },
    );
  }
}
