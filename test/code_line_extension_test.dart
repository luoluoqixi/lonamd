import 'package:flutter_test/flutter_test.dart';
import 'package:lonamd/lonamd.dart';

void main() {
  group('CodeLineExtension', () {
    test('get textLines', () {
      expect(''.textLines, const ['']);
      expect('abc'.textLines, const ['abc']);
      expect('abc\nfoo\nbar'.textLines, const ['abc', 'foo', 'bar']);
      expect('abc\r\nfoo\rbar'.textLines, const ['abc', 'foo', 'bar']);
    });
    test('get codeLines', () {
      expect(
          'abc\nfoo\nbar'.codeLines,
          CodeLines.of(
              const [CodeLine('abc'), CodeLine('foo'), CodeLine('bar')]));
    });

    test('get codeLinesAsync', () async {
      expect(
          await 'abc\nfoo\nbar'.codeLinesAsync,
          CodeLines.of(
              const [CodeLine('abc'), CodeLine('foo'), CodeLine('bar')]));
    });
  });
}
