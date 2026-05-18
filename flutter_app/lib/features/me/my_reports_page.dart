import 'package:flutter/material.dart';

import '../../models/report_item.dart';
import '../../repositories/app_repositories.dart';
import 'report_detail_page.dart';

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  List<ReportItem> _items = const <ReportItem>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的举报')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _items.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (BuildContext context, int index) {
                final ReportItem row = _items[index];
                return Card(
                  child: ListTile(
                    title: Text('${row.target} · ${row.reason}'),
                    subtitle: Text(
                      row.result.trim().isNotEmpty
                          ? '处理状态：${row.status} · ${row.result}'
                          : '处理状态：${row.status}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReportDetailPage(report: row),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      bottomNavigationBar: _error == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<ReportItem> items =
          await AppRepositories.users.fetchMyReports();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '加载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}
