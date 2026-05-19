import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/admin_models.dart';
import '../../../repositories/admin_repository.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';

class AdminImageReviewListPage extends ConsumerStatefulWidget {
  const AdminImageReviewListPage({super.key});

  @override
  ConsumerState<AdminImageReviewListPage> createState() => _AdminImageReviewListPageState();
}

class _AdminImageReviewListPageState extends ConsumerState<AdminImageReviewListPage> {
  String _status = 'pending';
  List<AdminImageReviewItem> _items = [];
  bool _isLoading = true;
  bool _isActionBusy = false;

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final items = await _repo.fetchImageReviews(status: _status);
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

  Future<void> _handleAction(AdminImageReviewItem item, String action, String label) async {
    final noteController = TextEditingController(text: label);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('图片审核: $label'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: '审核备注'),
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
      await _repo.handleImageReview(
        uploadId: item.id,
        action: action,
        note: noteController.text.trim(),
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
        title: const Text('图片审核'),
        centerTitle: true,
        backgroundColor: colors.surface,
        actions: [
          DropdownButton<String>(
            value: _status,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'pending', child: Text('待审核')),
              DropdownMenuItem(value: 'approved', child: Text('已通过')),
              DropdownMenuItem(value: 'rejected', child: Text('已拒绝')),
              DropdownMenuItem(value: 'risk', child: Text('风险项')),
              DropdownMenuItem(value: 'all', child: Text('全部')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _status = val);
                _load();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? const Center(child: Text('暂无待审核图片'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) => _buildImageCard(_items[i]),
                    ),
            ),
    );
  }

  Widget _buildImageCard(AdminImageReviewItem item) {
    final colors = MobileColors.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackPositioned.fill,
              children: [
                Image.network(
                  item.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildStatusChip(item.status),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.uploaderAlias, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(item.createdAt, style: TextStyle(fontSize: 10, color: colors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _isActionBusy ? null : () => _handleAction(item, 'approve', '通过'),
                      icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _isActionBusy ? null : () => _handleAction(item, 'risk', '标记风险'),
                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _isActionBusy ? null : () => _handleAction(item, 'reject', '拒绝'),
                      icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    if (status == 'pending') color = Colors.orange;
    else if (status == 'approved') color = Colors.green;
    else if (status == 'rejected') color = Colors.red;
    else if (status == 'risk') color = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}
