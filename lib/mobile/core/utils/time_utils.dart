import 'package:intl/intl.dart';

/// 统一的时间格式化工具
/// - 5 分钟以内: now
/// - 5 分钟 ~ 1 小时: 5min, 40min
/// - 1 小时 ~ 24 小时: 1h, 20h
/// - 1 天 ~ 7 天: 3d, 6d
/// - 7 天及以上: Sep 30, 2025
String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inMinutes < 5) {
    return 'now';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes}min';
  } else if (diff.inHours < 24) {
    return '${diff.inHours}h';
  } else if (diff.inDays < 7) {
    return '${diff.inDays}d';
  } else {
    return DateFormat('MMM d, yyyy').format(dateTime);
  }
}
