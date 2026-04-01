import 'package:flutter/material.dart';

import '../../core/emoji/emoji_catalog.dart';
import '../../core/emoji/emoji_settings_store.dart';

class EmojiSettingsPage extends StatelessWidget {
  const EmojiSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final EmojiSettingsStore store = EmojiSettingsStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('表情设置')),
      body: AnimatedBuilder(
        animation: store,
        builder: (BuildContext context, Widget? child) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: <Widget>[
              Card(
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      title: const Text('启用表情功能'),
                      subtitle: const Text('发帖、评论回复、私聊输入时可选择表情'),
                      value: store.enabled,
                      onChanged: (bool value) => store.setEnabled(value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '常用表情',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '已选 ${store.favorites.length}/${EmojiSettingsStore.maxFavorites}。点按可取消，再点其他可加入。',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: EmojiCatalog.all.map((String emoji) {
                          final bool selected = store.favorites.contains(emoji);
                          return FilterChip(
                            selected: selected,
                            label: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                            onSelected: store.enabled
                                ? (_) async {
                                    final bool success =
                                        await store.toggleFavorite(emoji);
                                    if (!success && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('常用表情最多 16 个'),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () => store.resetDefaults(),
                        icon: const Icon(Icons.restore),
                        label: const Text('恢复默认表情设置'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
