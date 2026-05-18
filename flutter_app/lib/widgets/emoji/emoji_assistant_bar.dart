import 'package:flutter/material.dart';

import '../../core/emoji/emoji_catalog.dart';
import '../../core/emoji/emoji_settings_store.dart';

class EmojiAssistantBar extends StatelessWidget {
  const EmojiAssistantBar({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final TextEditingController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: EmojiSettingsStore.instance,
      builder: (BuildContext context, Widget? child) {
        final EmojiSettingsStore store = EmojiSettingsStore.instance;
        if (!store.enabled) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.centerRight,
          child: compact
              ? IconButton(
                  onPressed: () => showEmojiPickerSheet(
                    context: context,
                    controller: controller,
                  ),
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  tooltip: '表情',
                  visualDensity: VisualDensity.compact,
                )
              : OutlinedButton.icon(
                  onPressed: () => showEmojiPickerSheet(
                    context: context,
                    controller: controller,
                  ),
                  icon: const Icon(Icons.emoji_emotions_outlined, size: 18),
                  label: const Text('表情'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
        );
      },
    );
  }
}

Future<void> showEmojiPickerSheet({
  required BuildContext context,
  required TextEditingController controller,
}) async {
  final EmojiSettingsStore store = EmojiSettingsStore.instance;
  if (!store.enabled) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '选择表情',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: store,
                builder: (BuildContext context, Widget? child) {
                  final List<String> favorites = store.favorites;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: favorites
                        .map(
                          (String emoji) => InkWell(
                            onTap: () => insertEmojiToController(
                              controller: controller,
                              emoji: emoji,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF4FA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: GridView.builder(
                  itemCount: EmojiCatalog.all.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final String emoji = EmojiCatalog.all[index];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => insertEmojiToController(
                          controller: controller,
                          emoji: emoji,
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
