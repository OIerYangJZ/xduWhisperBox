Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((dynamic key, dynamic val) => MapEntry<String, dynamic>(key.toString(), val));
  }
  return <String, dynamic>{};
}

List<dynamic> asList(dynamic value) {
  if (value is List<dynamic>) {
    return value;
  }
  if (value is List) {
    return value.cast<dynamic>();
  }
  return <dynamic>[];
}

List<dynamic> extractList(dynamic value) {
  if (value is List) {
    return value.cast<dynamic>();
  }

  final Map<String, dynamic> map = asMap(value);
  const List<String> keys = <String>[
    'data',
    'items',
    'list',
    'rows',
    'results',
    'content',
    'records',
    'posts',
    'comments',
    'conversations',
    'requests',
  ];

  for (final String key in keys) {
    final dynamic candidate = map[key];
    if (candidate is List) {
      return candidate.cast<dynamic>();
    }
    if (candidate is Map) {
      final List<dynamic> nested = extractList(candidate);
      if (nested.isNotEmpty) {
        return nested;
      }
    }
  }

  return <dynamic>[];
}

Map<String, dynamic> extractMap(dynamic value) {
  final Map<String, dynamic> map = asMap(value);
  if (map.isEmpty) {
    return <String, dynamic>{};
  }
  const List<String> keys = <String>['data', 'item', 'post', 'profile', 'result'];
  for (final String key in keys) {
    final dynamic candidate = map[key];
    if (candidate is Map) {
      return asMap(candidate);
    }
  }

  return map;
}

String? readString(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final dynamic value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value != null) {
      final String text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
  }
  return null;
}

int? readInt(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final dynamic value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final int? parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return null;
}

bool? readBool(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final dynamic value = json[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
  }
  return null;
}

DateTime? parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    // 支持秒/毫秒时间戳。
    if (value.toString().length <= 10) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
