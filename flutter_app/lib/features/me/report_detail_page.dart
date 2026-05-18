import 'package:flutter/material.dart';

import '../../core/navigation/post_detail_nav.dart';
import '../../models/post_item.dart';
import '../../models/report_item.dart';
import '../../repositories/app_repositories.dart';

class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({
    super.key,
    required this.report,
  });

  final ReportItem report;

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  late ReportItem _report = widget.report;
  bool _loading = true;
  bool _openingTarget = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  Widget build(BuildContext context) {
    final String targetLabel = _report.targetTitle.trim().isNotEmpty
        ? '${_report.target}（${_report.targetTitle}）'
        : _report.target;
    final String statusText = _report.result.trim().isNotEmpty
        ? '${_report.status} · ${_report.result}'
        : _report.status;

    return Scaffold(
      appBar: AppBar(title: const Text('举报详情')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '举报单号：${_report.id}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text('举报对象：$targetLabel'),
                        Text('举报原因：${_report.reason}'),
                        if (_report.description.trim().isNotEmpty)
                          Text('补充说明：${_report.description}'),
                        Text('处理状态：$statusText'),
                        if (_report.createdAt.trim().isNotEmpty)
                          Text('提交时间：${_report.createdAt}'),
                        if (_report.handledAt.trim().isNotEmpty)
                          Text('处理时间：${_report.handledAt}'),
                      ],
                    ),
                  ),
                ),
                if (_canOpenTarget())
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton.icon(
                      onPressed: _openingTarget ? null : _openTargetPost,
                      icon: _openingTarget
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.open_in_new_outlined),
                      label: Text(_openingTarget ? '打开中...' : '查看被举报帖子'),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ReportItem detail =
          await AppRepositories.users.fetchMyReportDetail(widget.report.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _report = detail;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '加载举报详情失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool _canOpenTarget() {
    final String targetType = _report.targetType.trim().toLowerCase();
    final String targetId = _report.targetId.trim();
    if (targetType != 'post') {
      return false;
    }
    return targetId.isNotEmpty && targetId != 'unknown';
  }

  Future<void> _openTargetPost() async {
    final String postId = _report.targetId.trim();
    if (postId.isEmpty) {
      return;
    }

    setState(() {
      _openingTarget = true;
    });
    try {
      final PostItem post = await AppRepositories.posts.fetchPostDetail(postId);
      if (!mounted) {
        return;
      }
      await openPostDetailPage(context, post: post);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开帖子失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingTarget = false;
        });
      }
    }
  }
}
