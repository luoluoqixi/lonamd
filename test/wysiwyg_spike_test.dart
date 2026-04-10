import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' as ui;

/// Spike test: Verify that a near-zero fontSize TextStyle causes
/// characters to occupy near-zero visual width in a TextPainter,
/// while getPositionForOffset still returns correct character indices.
void main() {
  group('Zero-width TextStyle spike', () {
    const normalStyle = TextStyle(
      fontSize: 16,
      fontFamily: 'monospace',
    );

    const hiddenStyle = TextStyle(
      fontSize: 0.01,
      height: 0.01,
      letterSpacing: -1,
      color: Color(0x00000000), // transparent
    );

    test('hidden marks occupy near-zero width', () {
      // Normal: "**hello**" all at 16px
      final normalPainter = TextPainter(
        text: TextSpan(text: '**hello**', style: normalStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      // WYSIWYG: "**" hidden + "hello" normal + "**" hidden
      final wysiwygPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(text: '**', style: normalStyle.merge(hiddenStyle)),
            TextSpan(text: 'hello', style: normalStyle),
            TextSpan(text: '**', style: normalStyle.merge(hiddenStyle)),
          ],
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      // "hello" alone
      final helloOnlyPainter = TextPainter(
        text: TextSpan(text: 'hello', style: normalStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final normalWidth = normalPainter.width;
      final wysiwygWidth = wysiwygPainter.width;
      final helloOnlyWidth = helloOnlyPainter.width;

      // Print widths for manual inspection
      // ignore: avoid_print
      print('Normal "**hello**" width: $normalWidth');
      // ignore: avoid_print
      print('WYSIWYG (hidden marks) width: $wysiwygWidth');
      // ignore: avoid_print
      print('"hello" only width: $helloOnlyWidth');

      // The WYSIWYG width should be much closer to "hello" width than normal
      // Allow some tolerance (hidden chars might still take tiny space)
      expect(
        wysiwygWidth,
        lessThan(normalWidth),
        reason: 'Hidden marks should reduce total width',
      );

      // The hidden marks should add less than 5px total
      expect(
        (wysiwygWidth - helloOnlyWidth).abs(),
        lessThan(5.0),
        reason: 'Hidden marks should add near-zero width',
      );
    });

    test('getPositionForOffset returns correct indices with hidden marks', () {
      final painter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(text: '**', style: normalStyle.merge(hiddenStyle)),
            TextSpan(text: 'hello', style: normalStyle),
            TextSpan(text: '**', style: normalStyle.merge(hiddenStyle)),
          ],
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      // The text buffer is "**hello**" (9 chars)
      // Character at index 0-1 = "**" (hidden)
      // Character at index 2-6 = "hello" (visible)
      // Character at index 7-8 = "**" (hidden)

      // Position at the very start should be offset 0
      final startPos = painter.getPositionForOffset(const Offset(0, 0));
      expect(startPos.offset, lessThanOrEqualTo(2),
          reason: 'Start offset should be at or before the visible text');

      // Position somewhere in the middle of "hello" should be between 2 and 7
      final midX = painter.width / 2;
      final midPos = painter.getPositionForOffset(Offset(midX, 0));
      expect(midPos.offset, greaterThanOrEqualTo(2));
      expect(midPos.offset, lessThanOrEqualTo(7));

      // Verify all 9 character positions can be enumerated via getOffsetForCaret
      for (int i = 0; i <= 9; i++) {
        final offset = painter.getOffsetForCaret(
          TextPosition(offset: i),
          Rect.zero,
        );
        // Should not throw and should return finite values
        expect(offset.dx.isFinite, isTrue,
            reason: 'Caret offset at index $i should be finite');
      }
    });

    test('fallback: transparent color only (same width but invisible)', () {
      const transparentStyle = TextStyle(
        color: Color(0x00000000),
      );

      final painter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(text: '**', style: normalStyle.merge(transparentStyle)),
            TextSpan(text: 'hello', style: normalStyle),
            TextSpan(text: '**', style: normalStyle.merge(transparentStyle)),
          ],
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final normalPainter = TextPainter(
        text: TextSpan(text: '**hello**', style: normalStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      // With transparent color only, width should be approximately the same
      // (characters still occupy space)
      // ignore: avoid_print
      print('Transparent-only width: ${painter.width}');
      // ignore: avoid_print
      print('Normal width: ${normalPainter.width}');

      expect(
        (painter.width - normalPainter.width).abs(),
        lessThan(1.0),
        reason: 'Transparent color should not change layout width',
      );
    });
  });
}
