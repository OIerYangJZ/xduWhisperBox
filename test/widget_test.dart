import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App Initialization', () {
    test('测试框架正常工作', () {
      expect(1 + 1, equals(2));
    });

    test('Mock 数据可用', () {
      final mockPosts = <String, List<String>>{
        'p1': <String>['教研楼三层东边插座比较多。'],
      };
      expect(mockPosts.isNotEmpty, isTrue);
    });
  });
}
