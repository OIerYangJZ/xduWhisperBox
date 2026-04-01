import 'package:flutter/material.dart';

import '../../models/my_comment_item.dart';
import '../../repositories/app_repositories.dart';

class MyCommentsPage extends StatefulWidget {
  const MyCommentsPage({super.key});

  @override
  State<MyCommentsPage> createState() => _MyCommentsPageState();
}

class _MyCommentsPageState extends State<MyCommentsPage> {
  List<MyCommentItem> _items = const <MyCommentItem>[];
  bool _loading = true;
  bool _actionBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的评论')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _items.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (BuildContext context, int index) {
                final MyCommentItem row = _items[index];
                return Card(
                  child: ListTile(
                    title: Text(row.postTitle),
                    subtitle: Text('${row.content}\n${row.timeText}'),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 8,
                      children: <Widget>[
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('原帖跳转下一步接入。')),
                            );
                          },
                          child: const Text('原帖'),
                        ),
                        TextButton(
                          onPressed: _actionBusy ? null : () => _delete(row.id),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
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
      final List<MyCommentItem> items = await AppRepositories.users.fetchMyComments();
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

  Future<void> _delete(String commentId) async {
    setState(() {
      _actionBusy = true;
    });

    try {
      await AppRepositories.users.deleteMyComment(commentId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('评论删除成功。')),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }
}
