import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/admin_models.dart';
import '../../../repositories/admin_repository.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';

class AdminReviewListPage extends ConsumerStatefulWidget {
  const AdminReviewListPage({super.key});

  @override
  ConsumerState<AdminReviewListPage> createState() => _AdminReviewListPageState();
}

class _AdminReviewListPageState extends ConsumerState<AdminReviewListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _type = 'post';
  String _status = 'pending';
  List<AdminReviewItem> _items = [];
  bool _isLoading = true;
  bool _isActionBusy = false;

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final items = await _repo.fetchReviews(
        type: _type,
        status: _status,
        keyword: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showToast('加载失败: $e');
    }
  }

  Future<void> _handleAction(AdminReviewItem item, String action) async {
    setState(() => _isActionBusy = true);
    try {
      await _repo.handleReview(
        targetType: item.targetType,
        targetId: item.id,
        action: action,
      );
      _showToast('操作成功');
      _load();
    } catch (e) {
      _showToast('操作失败: $e');
    } finally {
      if (mounted) setState(() => _isActionBusy = false);
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('内容审核'),
        centerTitle: true,
        backgroundColor: colors.surface,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'post', label: Text('帖子'), icon: Icon(Icons.article_outlined)),
                          ButtonSegment(value: 'comment', label: Text('评论'), icon: Icon(Icons.comment_outlined)),
                        ],
                        selected: {_type},
                        onSelectionChanged: (val) {
                          setState(() => _type = val.first);
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('待审核')),
                        DropdownMenuItem(value: 'approved', child: Text('已通过')),
                        DropdownMenuItem(value: 'rejected', child: Text('已驳回')),
                        DropdownMenuItem(value: 'all', child: Text('全部')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _status = val);
                          _load();
                        }
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索关键词...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? const Center(child: Text('暂无审核项'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) => _buildReviewCard(_items[i]),
                    ),
            ),
    );
  }

  Widget _buildReviewCard(AdminReviewItem item) {
    final colors = MobileColors.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                _buildStatusChip(item.reviewStatus),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.content,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('作者: ${item.authorNickname} (${item.authorAlias})', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                  Text('账号: ${item.authorEmail} · 学号: ${item.authorStudentId}', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                  Text('时间: ${item.createdAt}', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _isActionBusy ? null : () => _handleAction(item, 'approve'),
                  child: const Text('通过'),
                ),
                OutlinedButton(
                  onPressed: _isActionBusy ? null : () => _handleAction(item, 'reject'),
                  style: OutlinedButton.styleFrom(foregroundColor: MobileTheme.error),
                  child: const Text('驳回'),
                ),
                OutlinedButton(
                  onPressed: _isActionBusy ? null : () => _handleAction(item, 'risk'),
                  style: OutlinedButton.styleFrom(foregroundColor: MobileTheme.warning),
                  child: const Text('风险'),
                ),
                IconButton(
                  onPressed: _isActionBusy ? null : () => _handleAction(item, 'delete'),
                  icon: const Icon(Icons.delete_outline, color: MobileTheme.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    String label = '未知';
    if (status == 'pending') { color = Colors.orange; label = '待审核'; }
    else if (status == 'approved') { color = Colors.green; label = '通过'; }
    else if (status == 'rejected') { color = Colors.red; label = '驳回'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
