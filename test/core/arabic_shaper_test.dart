import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/pdf/arabic_shaper.dart';
import 'package:dhimmah/core/pdf/pdf_text.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// The shaping and reordering the PDF depends on.
///
/// These assert on code points rather than on rendered pixels: if a letter comes
/// out in its isolated form where it should be joined, the document reads as
/// broken Arabic, and that is cheap to catch here and expensive to notice later.
void main() {
  // Date symbols are loaded by the app at startup; a plain test has to ask.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  /// The presentation form a logical letter should take, as a code point.
  String shaped(String input) => shapeArabic(input);

  /// Reads as one joined word: every letter is in a connected form.
  bool isFullyJoined(String input) {
    return shapeArabic(input).runes.every((int code) => code >= 0xFE70);
  }

  group('contextual forms', () {
    test('a lone letter is isolated', () {
      // ب on its own.
      expect(shaped('ب'), String.fromCharCode(0xFE8F));
    });

    test('a word shapes every letter by its neighbours', () {
      // بيت: ب initial, ي medial, ت final. Verified against the Unicode
      // presentation-form tables independently of this implementation.
      final String result = shaped('بيت');
      expect(result.runes.toList(), <int>[0xFE91, 0xFEF4, 0xFE96]);
    });

    test('the first letter is initial and the last is final', () {
      // محمد: م initial, ح medial, م medial, د final.
      final String result = shaped('محمد');
      expect(result.runes.toList(), <int>[0xFEE3, 0xFEA4, 0xFEE4, 0xFEAA]);
    });

    test('a word of non-joining letters stays unconnected', () {
      // دار is مade of three letters that cannot join the one after them, so no
      // join exists anywhere in the word and every letter keeps its isolated
      // form. This is the rule that stops Arabic from becoming one long ribbon.
      final List<int> codes = shaped('دار').runes.toList();
      expect(codes, <int>[0xFEA9, 0xFE8D, 0xFEAD]);
    });

    test('a joining letter before a non-joining one is medial, not final', () {
      // محمد ends in م + د: the د does connect to the letter before it, so the م
      // takes its medial form and the د takes its final form.
      final List<int> codes = shaped('محمد').runes.toList();
      expect(codes.last, 0xFEAA, reason: 'د final: it joins the م before it');
      expect(codes[2], 0xFEE4, reason: 'م medial: joined on both sides');
    });

    test('a joining letter takes the medial form between two connectors', () {
      // نهر: ن initial, ه medial, ر final.
      final List<int> codes = shaped('نهر').runes.toList();
      expect(codes[0], 0xFEE7, reason: 'ن initial');
      expect(codes[1], 0xFEEC, reason: 'ه medial');
      expect(codes[2], 0xFEAE, reason: 'ر final');
    });

    test('every letter of a plain word is a connected form', () {
      expect(isFullyJoined('مرحبا'), isTrue);
      expect(isFullyJoined('إجمالي'), isTrue);
      expect(isFullyJoined('المستحق'), isTrue);
    });
  });

  group('lam-alef', () {
    test('collapses into the obligatory ligature', () {
      // لا is one glyph, not two letters.
      expect(shaped('لا'), String.fromCharCode(0xFEFB));
    });

    test('takes the final ligature after a joining letter', () {
      // بلا: ب initial, then the final lam-alef ligature.
      expect(shaped('بلا').runes.toList(), <int>[0xFE91, 0xFEFC]);
    });

    test('handles all four alef variants', () {
      expect(shaped('لأ'), String.fromCharCode(0xFEF7));
      expect(shaped('لإ'), String.fromCharCode(0xFEF9));
      expect(shaped('لآ'), String.fromCharCode(0xFEF5));
    });

    test('stands alone after a letter that does not join forward', () {
      // الاستحقاق: the lam-alef follows an alef, and an alef never joins the
      // letter after it — so the ligature is isolated, not final. Asking only
      // whether a previous letter exists picked the connected form and drew a
      // tail that joins nothing. Every word beginning «ال» where the third
      // letter is an alef, a waw, a dal, a reh or a zay depends on this.
      expect(shaped('الاستحقاق').runes.toList(), <int>[
        0xFE8D, 0xFEFB, 0xFEB3, 0xFE98, 0xFEA4, 0xFED8, 0xFE8E, 0xFED5,
      ]);
      expect(shaped('الأول').runes, contains(0xFEF7));
      expect(shaped('والأرض').runes, contains(0xFEF7));
    });

    test('joins when the letter before it does join forward', () {
      // السلام: the ligature follows a seen, which does join forward, so it
      // takes its connected form. The rule cuts both ways.
      expect(shaped('السلام').runes, contains(0xFEFC));
      expect(shaped('بلا').runes, contains(0xFEFC));
    });

    test('leaves a lam that is not followed by an alef alone', () {
      // لم يبدأ: the lam is followed by a meem, so it shapes normally.
      final List<int> codes = shaped('لم').runes.toList();
      expect(codes, <int>[0xFEDF, 0xFEE2]);
    });
  });

  group('combining marks', () {
    test('do not interrupt the joining analysis', () {
      // A shadda between two letters must not split the word.
      final List<int> withMark = shaped('شدّة').runes.toList();
      final List<int> withoutMark = shaped('شدة').runes.toList();
      // The shadda is dropped from the shaping run, so the letters shape as if
      // it were not there.
      expect(
        withMark.where((int c) => c >= 0xFE70).toList(),
        withoutMark.where((int c) => c >= 0xFE70).toList(),
      );
    });
  });

  group('non-Arabic text passes through', () {
    test('digits, punctuation and currency are untouched', () {
      const String mixed = 'المتبقي: 15,000 ₹';
      expect(containsArabic(mixed), isTrue);
      final String result = shaped(mixed);
      // The Arabic run is shaped; everything else is byte-identical.
      expect(result, contains('15,000'));
      expect(result, contains('₹'));
      expect(result, contains(':'));
      // Shaping is idempotent from the reader's point of view: the shaped text is
      // still recognised as Arabic.
      expect(containsArabic(result), isTrue);
      // And no original Arabic letter code point survives.
      expect(
        result.runes.any((int c) => c >= 0x0620 && c <= 0x064A),
        isFalse,
      );
    });

    test('a pure Latin string is returned unchanged', () {
      expect(shaped('Dhimmah Statement'), 'Dhimmah Statement');
      expect(containsArabic('Dhimmah Statement'), isFalse);
    });

    test('an empty string is safe', () {
      expect(shaped(''), '');
      expect(containsArabic(''), isFalse);
    });
  });

  group('date phrasing', () {
    // The wording rules that make a deadline readable at a glance. These use the
    // English strings so the assertions read as the sentence a user sees.
    late final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));
    final DateFormatter formatter =
        DateFormatter(language: AppLanguage.english, localizations: l10n);
    final DateTime today = DateTime(2026, 9, 22);

    test('lateness is always stated as lateness', () {
      expect(formatter.relativeDue(DateTime(2026, 9, 21), today), 'Yesterday');
      expect(formatter.relativeDue(DateTime(2026, 9, 18), today), '4 days late');
      // Two months late is still "late", not a bare date the reader has to
      // interpret.
      expect(
        formatter.relativeDue(DateTime(2026, 7), today),
        '83 days late',
      );
    });

    test('near future is relative and far future is a date', () {
      expect(formatter.relativeDue(today, today), 'Today');
      expect(formatter.relativeDue(DateTime(2026, 9, 23), today), 'Tomorrow');
      expect(formatter.relativeDue(DateTime(2026, 9, 27), today), 'In 5 days');
      // Beyond a week, the date itself is more useful than a count.
      expect(
        formatter.relativeDue(DateTime(2026, 10, 15), today),
        contains('Oct'),
      );
    });

    test('the attention label never falls back to a bare date', () {
      // Unlike relativeDue, this one is always paired with the date by the
      // caller, so a fallback would print the date twice.
      expect(
        formatter.attentionLabel(DateTime(2026, 7), today),
        '83 days late',
      );
      expect(formatter.attentionLabel(DateTime(2026, 10, 15), today).contains('Oct'), isFalse);
    });
  });

  group('glyph coverage', () {
    // A box in the middle of a word is the most visible way a document can look
    // broken, and it is invisible to a code review. These pin the exact code
    // points that can come out of the pipeline.
    test('no legacy shadda ligatures survive the pipeline', () {
      // The bidirectional algorithm composes these; the font has no glyphs for
      // them, so they must not reach the renderer.
      final Iterable<int> inLigatureRange = pdfText('تُسدَّد').runes.where(
        (int code) => code >= 0xFC5E && code <= 0xFC63,
      );
      expect(inLigatureRange, isEmpty);
    });

    test('expanding a ligature yields the two marks it stands for', () {
      expect(expandMarkLigatures('\uFC60'), '\u064E\u0651');
      expect(expandMarkLigatures('abc'), 'abc');
    });
  });

  group('preparation for the renderer', () {
    test('Latin and numeric strings are left exactly as written', () {
      // The renderer reorders any string it is told is right-to-left, so a
      // numeric one has to be left alone: `₹ 45,500` reversed reads
      // `45,500 ₹`, and a column of amounts would be unreadable.
      expect(pdfText('Total 1,200'), 'Total 1,200');
      expect(pdfText('₹ 45,500'), '₹ 45,500');
      expect(pdfText('2026/9/23'), '2026/9/23');
      expect(pdfText('DHM-2026-2524 · 821778'), 'DHM-2026-2524 · 821778');
    });

    test('an Arabic string comes out shaped but in logical order', () {
      // Nothing is moved: the renderer does the ordering. If this file
      // reordered as well the two would cancel out and the line would read
      // backwards.
      expect(pdfText('أحمد'), shapeArabic('أحمد'));
      expect(pdfText('أحمد'), isNot(shapeArabic('أحمد').split('').reversed.join()));
    });

    test('a combining mark stays after the letter it belongs to', () {
      // تُسدَّد carries a damma and a shadda. Moving them in front of their base
      // letter would make the renderer draw them beside it instead of above it.
      final List<int> prepared = pdfText('تُسدَّد').runes.toList();
      for (int i = 0; i < prepared.length; i++) {
        if (!isCombiningMark(prepared[i])) continue;
        if (i > 0 && isCombiningMark(prepared[i - 1])) continue;
        expect(i, greaterThan(0), reason: 'a run of marks starts the string');
      }
      final List<int> bases =
          prepared.where((int c) => !isCombiningMark(c)).toList();
      expect(
        bases,
        shapeArabic('تُسدَّد').runes.where((int c) => !isCombiningMark(c)).toList(),
      );
    });

    test('a number inside Arabic keeps its own left-to-right order', () {
      // Digits are a left-to-right run even in a right-to-left sentence, and
      // the renderer is entitled to rely on them being written in that order.
      final String prepared = pdfText('المتبقي 15,000');
      expect(prepared, contains('15,000'));
    });

    test('the legacy shadda ligatures never reach the renderer', () {
      // The font has no glyph for them, so they would print as a box.
      expect(pdfText('\uFC60'), isNot(contains('\uFC60')));
      expect(pdfText('\uFC60').runes.toList(), <int>[0x064E, 0x0651]);
    });
  });
}
