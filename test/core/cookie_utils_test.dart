import 'package:acgn_index/core/utils/cookie_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cookie 头工具', () {
    test('解析名称与值并忽略空白', () {
      expect(parseCookieHeader(' sid = abc ; token=xyz; '), <String, String>{
        'sid': 'abc',
        'token': 'xyz',
      });
    });

    test('忽略空项、无等号项与空名称', () {
      expect(parseCookieHeader('; broken; =empty; ok=1; a=b=c'), <String, String>{
        'ok': '1',
        'a': 'b=c',
      });
    });

    test('按请求头格式输出并跳过空名称', () {
      expect(
        formatCookieHeader(<String, String>{'sid': 'abc', '': 'x', 'token': 'y'}),
        'sid=abc; token=y',
      );
    });
  });
}
