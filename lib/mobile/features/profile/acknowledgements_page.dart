import 'package:flutter/material.dart';

class AcknowledgementsPage extends StatelessWidget {
  const AcknowledgementsPage({super.key});

  static const List<String> _thanks = <String>[
    '感谢所有参与测试、反馈与内容治理的同学。',
    '感谢为西电树洞提供设计、产品、开发和运维支持的成员。',
    '感谢每一位提交 issue、建议和错误报告的用户。',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('致谢')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.58 : 0.36,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  '感谢每一位参与建设西电树洞的人',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '这个项目仍在持续迭代。每一次测试、反馈、建议和修复，都让它更接近真正可用。',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._thanks.map(
            (item) => Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: Text(item),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
