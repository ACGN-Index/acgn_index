import 'package:acgn_index/core/errors/app_exception.dart';

/// 常用 JSONPath 子集求值。
///
/// 支持 `$`、`.key`、`['key']`、`[n]`、`[*]`，返回全部匹配并跳过 null。
/// 超出该子集的语法直接抛 [RuleFormatException]，避免静默返回错误结果。
List<Object?> evaluateJsonPath(Object? root, String expression) {
  if (root == null) {
    return const <Object?>[];
  }
  final steps = _JsonPathParser(expression).parse();
  var current = <Object?>[root];
  for (final step in steps) {
    current = step.apply(current);
    if (current.isEmpty) {
      return const <Object?>[];
    }
  }
  return current;
}

sealed class _JsonPathStep {
  const _JsonPathStep();

  List<Object?> apply(List<Object?> input);
}

final class _KeyStep extends _JsonPathStep {
  const _KeyStep(this.key);

  final String key;

  @override
  List<Object?> apply(List<Object?> input) {
    final result = <Object?>[];
    for (final value in input) {
      if (value is Map<Object?, Object?>) {
        final matched = value[key];
        if (matched != null) {
          result.add(matched);
        }
      }
    }
    return result;
  }
}

final class _IndexStep extends _JsonPathStep {
  const _IndexStep(this.index);

  final int index;

  @override
  List<Object?> apply(List<Object?> input) {
    final result = <Object?>[];
    for (final value in input) {
      if (value is List<Object?>) {
        final resolved = index < 0 ? value.length + index : index;
        if (resolved >= 0 && resolved < value.length) {
          final matched = value[resolved];
          if (matched != null) {
            result.add(matched);
          }
        }
      }
    }
    return result;
  }
}

final class _WildcardStep extends _JsonPathStep {
  const _WildcardStep();

  @override
  List<Object?> apply(List<Object?> input) {
    final result = <Object?>[];
    for (final value in input) {
      if (value is List<Object?>) {
        result.addAll(value.where((item) => item != null));
      } else if (value is Map<Object?, Object?>) {
        result.addAll(value.values.where((item) => item != null));
      }
    }
    return result;
  }
}

final class _JsonPathParser {
  _JsonPathParser(this.source);

  final String source;
  int _index = 0;

  List<_JsonPathStep> parse() {
    _skipWhitespace();
    if (!_consume(r'$')) {
      throw RuleFormatException(
        r'JSONPath 必须以 $ 开头：'
        '$source',
      );
    }
    final steps = <_JsonPathStep>[];
    while (true) {
      _skipWhitespace();
      if (_isEnd) {
        break;
      }
      final char = source[_index];
      if (char == '.') {
        _index++;
        if (!_isEnd && source[_index] == '.') {
          throw RuleFormatException('JSONPath 暂不支持递归下降：$source');
        }
        final key = _readKey();
        if (key.isEmpty) {
          throw RuleFormatException('JSONPath 缺少属性名：$source');
        }
        steps.add(_KeyStep(key));
      } else if (char == '[') {
        steps.add(_readBracket());
      } else {
        throw RuleFormatException('JSONPath 无法解析：$source');
      }
    }
    return steps;
  }

  _JsonPathStep _readBracket() {
    _expect('[');
    _skipWhitespace();
    if (_consume('*')) {
      _skipWhitespace();
      _expect(']');
      return const _WildcardStep();
    }
    if (!_isEnd && (source[_index] == "'" || source[_index] == '"')) {
      final quote = source[_index];
      _index++;
      final start = _index;
      while (!_isEnd && source[_index] != quote) {
        _index++;
      }
      if (_isEnd) {
        throw RuleFormatException('JSONPath 字符串未闭合：$source');
      }
      final key = source.substring(start, _index);
      _index++;
      _skipWhitespace();
      _expect(']');
      return _KeyStep(key);
    }
    final start = _index;
    while (!_isEnd && source[_index] != ']') {
      _index++;
    }
    if (_isEnd) {
      throw RuleFormatException('JSONPath 下标未闭合：$source');
    }
    final raw = source.substring(start, _index).trim();
    _index++;
    final index = int.tryParse(raw);
    if (index == null) {
      throw RuleFormatException('JSONPath 下标必须是整数：$raw');
    }
    return _IndexStep(index);
  }

  String _readKey() {
    final start = _index;
    while (!_isEnd) {
      final char = source[_index];
      if (char == '.' || char == '[' || _isWhitespace(char)) {
        break;
      }
      _index++;
    }
    return source.substring(start, _index);
  }

  bool get _isEnd => _index >= source.length;

  bool _consume(String char) {
    if (!_isEnd && source[_index] == char) {
      _index++;
      return true;
    }
    return false;
  }

  void _expect(String char) {
    if (!_consume(char)) {
      throw RuleFormatException('JSONPath 语法错误 "$source"：期望 "$char"');
    }
  }

  void _skipWhitespace() {
    while (!_isEnd && _isWhitespace(source[_index])) {
      _index++;
    }
  }

  bool _isWhitespace(String char) {
    final code = char.codeUnitAt(0);
    return code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D;
  }
}
