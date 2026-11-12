import 'package:acgn_index/core/utils/title_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeTitle', () {
    test('抹平全角、大小写、空白与标点', () {
      expect(normalizeTitle('  ＡＢＣ　葬送的芙莉莲 第一季 '), 'abc葬送的芙莉莲第一季');
      expect(normalizeTitle('【简中】葬送的芙莉莲'), '简中葬送的芙莉莲');
      expect(normalizeTitle('SPY-FAMILY 间谍过家家'), 'spyfamily间谍过家家');
    });

    test('只有空白与标点时返回空串', () {
      expect(normalizeTitle('《》——  '), isEmpty);
    });
  });

  group('titleMatchRank', () {
    test('规范化后完全一致为 2', () {
      expect(titleMatchRank('葬送的芙莉莲', ' 葬送的芙莉莲 '), 2);
      expect(titleMatchRank('SPY-FAMILY', 'spy family'), 2);
    });

    test('互相包含为 1', () {
      expect(titleMatchRank('葬送的芙莉莲 第一季', '葬送的芙莉莲'), 1);
      expect(titleMatchRank('葬送的芙莉莲', '葬送的芙莉莲 第一季'), 1);
    });

    test('无关标题为 0', () {
      expect(titleMatchRank('进击的巨人', '葬送的芙莉莲'), 0);
      expect(titleMatchRank('', '葬送的芙莉莲'), 0);
      expect(titleMatchRank('葬送的芙莉莲', '  '), 0);
    });
  });
}
