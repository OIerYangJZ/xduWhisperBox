import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/admin_models.dart';
import '../../../repositories/admin_repository.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';

class AdminReportListPage extends ConsumerStatefulWidget {
  const AdminReportListPage({super.key});

  @override
  ConsumerState<AdminReportListPage> createState() => _AdminReportListPageState();
}

class _AdminReportListPageState extends ConsumerState<AdminReportListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _status = 'pending';
  List<AdminReportEntry> _items = [];
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
      final items = await _repo.fetchReports(
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

  Future<void> _handleAction(AdminReportEntry report, String action, String label) async {
    final resultController = TextEditingController(text: '已处理: $label');
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('处理举报: $label'),
        content: TextField(
          controller: resultController,
          decoration: const InputDecoration(labelText: '处理结果说明'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionBusy = true);
    try {
      await _repo.handleReport(
        reportId: report.id,
        action: action,
        result: resultController.text.trim(),
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
        title: const Text('举报管理'),
        centerTitle: true,
        backgroundColor: colors.surface,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索单号/原因/内容...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('待处理')),
                    DropdownMenuItem(value: 'resolved', child: Text('已处理')),
                    DropdownMenuItem(value: 'closed', child: Text('已关闭')),
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
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? const Center(child: Text('暂无举报记录'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) => _buildReportCard(_items[i]),
                    ),
            ),
    );
  }

  Widget _buildReportCard(AdminReportEntry item) {
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
                    '举报 #${item.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                _buildStatusChip(item.status),
              ],
            ),
            const SizedBox(height: 12),
            Text('目标: ${item.targetType}:${item.targetId}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('原因: ${item.reason}', style: TextStyle(color: MobileTheme.error, fontWeight: FontWeight.w500)),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('说明: ${item.description}', style: TextStyle(color: colors.textPrimary)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text('举报人: ${item.reporterAlias}', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                const Spacer(),
                Text(item.createdAt, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              ],
            ),
            if (item.result.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(8)),
                child: Text('结果: ${item.result}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
            if (item.status == 'pending') ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _isActionBusy ? null : () => _handleAction(item, 'delete_content', '删除内容'),
                    child: const Text('删除内容'),
                  ),
                  OutlinedButton(
                    onPressed: _isActionBusy ? null : () => _handleAction(item, 'ban_user', '封禁用户'),
                    style: OutlinedButton.styleFrom(foregroundColor: MobileTheme.error),
                    child: const Text('封禁用户'),
                  ),
                  OutlinedButton(
                    onPressed: _isActionBusy ? null : () => _handleAction(item, 'mark_misreport', '标记误报'),
                    child: const Text('标记误报'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    String label = status;
    if (status == 'pending') { color = Colors.orange; label = '待处理'; }
    else if (status == 'resolved') { color = Colors.green; label = '已处理'; }
    else if (status == 'closed') { color = Colors.blueGrey; label = '已关闭'; }

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
