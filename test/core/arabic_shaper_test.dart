import 'dart:convert';
import 'dart:io';

import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/pdf/pdf_text.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
// The renderer's own reordering, so a word handed over pre-ordered can be
// checked against what the renderer would have drawn. Not public API, which is
// the point: if the renderer changes it, this is what should fail.
// ignore: implementation_imports
import 'package:pdf/src/pdf/font/bidi_utils.dart' as renderer_bidi;

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

    test('the letter before a hamza on the line ends the word', () {
      // The hamza joins neither way, so nothing reaches for it. «شيء»: ش
      // initial, ي final, ء alone — a medial ي was printed there before.
      expect(shaped('شيء').runes.toList(), <int>[0xFEB7, 0xFEF2, 0xFE80]);
      // «بطء»: ب initial, ط final, ء alone.
      expect(shaped('بطء').runes.toList(), <int>[0xFE91, 0xFEC2, 0xFE80]);
      // «دفء»: nothing joins the ف from either side.
      expect(shaped('دفء').runes.toList(), <int>[0xFEA9, 0xFED1, 0xFE80]);
      // And a letter after the hamza starts afresh: «جاءت».
      expect(
        shaped('جاءت').runes.toList(),
        <int>[0xFE9F, 0xFE8E, 0xFE80, 0xFE95],
      );
    });
  });

  group('lam-alef', () {
    test('collapses into the obligatory ligature', () {
      // لا is one glyph, not two letters.
      expect(shaped('لا'), String.fromCharCode(0xFEFB));
    });

    test('forms across a vowel on the lam, which it then carries', () {
      // «أولًا»: the tanween is on the lam, and the lam and alef still join.
      expect(
        shaped('أول\u064Bا').runes.toList(),
        <int>[0xFE83, 0xFEED, 0xFEFB, 0x064B],
      );
      // «سجلًا»: the same, after a letter that joins it.
      expect(
        shaped('سجل\u064Bا').runes.toList(),
        <int>[0xFEB3, 0xFEA0, 0xFEFC, 0x064B],
      );
      // A zero-width non-joiner is written to keep them apart.
      expect(
        shaped('ل\u200Cا').runes.any((int c) => c >= 0xFEF5 && c <= 0xFEFC),
        isFalse,
      );
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
      // The font has no glyphs for these, so they must not reach the renderer.
      final Iterable<int> inLigatureRange = pdfText('تُسدَّد').runes.where(
        (int code) => code >= 0xFC5E && code <= 0xFC63,
      );
      expect(inLigatureRange, isEmpty);
    });

    test('a shadda keeps no vowel for the renderer to join it with', () {
      // The renderer's bidirectional pass composes a shadda and a vowel into
      // one of those ligatures itself, in either order, so the pair must not
      // reach it either. The shadda is the mark that changes the word.
      expect(drawableMarks('د\u0651\u064E'), 'د\u0651');
      expect(drawableMarks('د\u064E\u0651'), 'د\u0651');
      expect(drawableMarks('د\u0651\u064F'), 'د\u0651');
      expect(drawableMarks('د\u0651\u064C'), 'د\u0651');
      expect(drawableMarks('د\u0651\u0650'), 'د\u0651');
      // A ligature that arrives already composed becomes its shadda.
      expect(drawableMarks('د\uFC60'), 'د\u0651');
      // «تُسدَّد»: the damma stays, the fatha on the doubled dal goes.
      expect(
        drawableMarks('ت\u064Fسد\u0651\u064Eد'),
        'ت\u064Fسد\u0651د',
      );
    });

    test('a vowel under the letter is dropped rather than drawn over it', () {
      // The font draws a kasra above the letter, where it reads as a fatha.
      expect(drawableMarks('م\u0650ن'), 'من'); // «مِن»
      expect(drawableMarks('ذ\u0650م\u0651ة'), 'ذم\u0651ة'); // «ذِمّة»
      expect(drawableMarks('ب\u064D'), 'ب'); // kasratan
    });

    test('every other mark is left as written', () {
      expect(drawableMarks('علي\u0651'), 'علي\u0651'); // «عليّ»
      expect(drawableMarks('ت\u064Fسج\u0651ل'), 'ت\u064Fسج\u0651ل');
      expect(drawableMarks('جد\u064Bا'), 'جد\u064Bا'); // «جدًا»
      expect(drawableMarks('م\u0652'), 'م\u0652'); // sukun
      expect(drawableMarks('abc'), 'abc');
      expect(drawableMarks(''), '');
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
      // The font has no glyph for them, so they would print as a box. Split
      // into its two marks, the renderer would only join the pair again, so the
      // shadda is what is left of it.
      expect(pdfText('\uFC60'), isNot(contains('\uFC60')));
      expect(pdfText('\uFC60').runes.toList(), <int>[0x0651]);
    });
  });

  group('the order a line is drawn in', () {
    List<String> order(List<String> words, {bool rtl = true}) =>
        visualWordOrder(words, fallbackRightToLeft: rtl);

    test('an Arabic line runs from the right', () {
      expect(order(<String>['دين', 'عليّ']), <String>['عليّ', 'دين']);
    });

    test('a number keeps its place and its own order', () {
      // «30 سبتمبر 2026», read from the right: the day, the month, the year.
      expect(
        order(<String>['30', 'سبتمبر', '2026']),
        <String>['2026', 'سبتمبر', '30'],
      );
      expect(order(<String>['₹', '45,500']), <String>['₹', '45,500']);
    });

    test('a Latin run inside Arabic stays in its own order', () {
      expect(
        order(<String>['تم', 'الدفع', 'إلى', 'Ahmed', 'Ali', 'اليوم']),
        <String>['اليوم', 'Ahmed', 'Ali', 'إلى', 'الدفع', 'تم'],
      );
    });

    test('a currency sign stays with its amount', () {
      expect(
        order(<String>['عليّ', '·', '₹', '60,000']),
        <String>['₹', '60,000', '·', 'عليّ'],
      );
    });

    test('an English line keeps its order, except inside Arabic', () {
      expect(
        order(<String>['Payment', 'made', '·', 'سلفة', 'شخصية'], rtl: false),
        <String>['Payment', 'made', '·', 'شخصية', 'سلفة'],
      );
    });
  });

  group('an Arabic word in drawing order', () {
    String reversed(String shaped) =>
        String.fromCharCodes(shaped.runes.toList().reversed);

    test('is the order the renderer would draw it in', () {
      // The word is handed over reversed and left to right so the renderer
      // places it by its advance. That only works if reversing gives exactly
      // the glyphs the renderer's own bidirectional pass would have drawn.
      for (final String word in <String>[
        'شخصية:',
        'عليّ',
        'تُسدّد',
        'الاستحقاق',
        'لا',
        'لانا',
        'لأحمد',
        'لإيجار',
        'لآخر',
        'طارئ،',
        'ذمّة',
        'جدًا',
        'سبتمبر',
        'أحمد',
        'آمنة',
        'مؤسسة',
        'شيء',
        'بطء',
        'دفء',
        'جاءت',
        'هيئة',
        'مسؤول',
        'قرآن',
        'بلا',
        'مستشفى',
      ]) {
        final String shaped = pdfText(word);
        expect(
          reversedArabicWord(shaped),
          renderer_bidi.logicalToVisual(rightToLeftParagraphs(shaped)),
          reason: word,
        );
        expect(reversedArabicWord(shaped), reversed(shaped), reason: word);
      }
    });

    test('so is every Arabic word the app writes', () {
      // Every word of every Arabic string, against the renderer. «شيء» was
      // shaped with a medial ي, which the renderer quietly re-shaped while it
      // did the ordering; drawn as given, it would have printed that way.
      final Map<String, dynamic> arb = jsonDecode(
        File('lib/l10n/arb/app_ar.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final Set<String> words = <String>{
        for (final MapEntry<String, dynamic> entry in arb.entries)
          if (!entry.key.startsWith('@') && entry.value is String)
            ...(entry.value as String).split(RegExp(r'[\s{}]+')),
      };
      // The two places the renderer is wrong and the shaper right, each pinned
      // on its own below. After a lam, its pass does not make the lam-alef
      // ligature: «للاستعادة» came out as three separate letters. And it takes
      // a vowelled «أ» apart into a bare alef under two marks, which then sit
      // on top of each other: «أُغلق».
      bool rendererGetsItWrong(String word) =>
          RegExp('لل[اأإآ]').hasMatch(word) ||
          RegExp('[\u0622-\u0626][\u064B-\u0652]').hasMatch(word);

      int checked = 0;
      final List<String> differ = <String>[];
      for (final String word in words) {
        if (rendererGetsItWrong(word)) continue;
        final String shaped = pdfText(word);
        final String? drawn = reversedArabicWord(shaped);
        if (drawn == null) continue;
        checked++;
        final String renderer =
            renderer_bidi.logicalToVisual(rightToLeftParagraphs(shaped));
        if (drawn != renderer) differ.add(word);
      }
      expect(differ, isEmpty, reason: 'drawn otherwise than the renderer would');
      expect(checked, greaterThan(300), reason: 'the strings were not read');
    });

    test('a vowelled alef-hamza stays one letter', () {
      // «أُغلق»: the أ keeps its own glyph, hamza drawn in place, and the damma
      // goes on it — where the renderer drew a bare alef under a hamza mark and
      // a damma, both at the same height.
      expect(
        reversedArabicWord(pdfText('أ\u064Fغلق'))!.runes.toList().reversed.take(2),
        <int>[0xFE83, 0x064F],
      );
    });

    test('a lam before a lam-alef keeps the ligature', () {
      // «للاستعادة»: an initial lam, then the final lam-alef — where the
      // renderer's own shaping gave a medial lam and a separate alef.
      expect(
        shapeArabic('للاستعادة').runes.take(2).toList(),
        <int>[0xFEDF, 0xFEFC],
      );
    });

    test('anything the renderer has to order or shape is left to it', () {
      for (final String word in <String>[
        '2026م', // a number
        '(سلفة)', // brackets, which mirror
        'سلفةA', // a Latin letter
        '«سلفة»',
        '٤٥٠', // Arabic-Indic digits are a number
        'گل', // a Persian letter the shaper does not know
        'ﷲ', // a ligature it does not make
        'Ahmed',
        ':',
      ]) {
        expect(reversedArabicWord(pdfText(word)), isNull, reason: word);
      }
    });
  });

  group('right-to-left text for the renderer', () {
    // The renderer's bidirectional pass throws on a paragraph that opens with
    // «لا»: a person called «لانا» could not be given a statement.
    test('a line that opens with «لا» no longer breaks the renderer', () {
      for (final String text in <String>[
        'لانا',
        'لا توجد دفعات',
        'لابتوب جديد',
        'لأحمد',
        'دفعة أولى\nلا شيء بعدها',
        'ﷲ',
        'أُغلق الدين', // an alef-hamza carrying a vowel
        'ؤُ',
      ]) {
        final String prepared = rightToLeftParagraphs(pdfText(text));
        expect(
          () => renderer_bidi.logicalToVisual(prepared),
          returnsNormally,
          reason: text,
        );
        // The mark is not drawn: the pass takes it out.
        expect(
          renderer_bidi.logicalToVisual(prepared).runes,
          isNot(contains(0x200F)),
          reason: text,
        );
      }
    });

    test('it is the pass itself that fails without the mark', () {
      // The negative control: if the renderer stops failing, this is the test
      // that says the guard can go.
      expect(
        () => renderer_bidi.logicalToVisual(pdfText('لانا')),
        throwsA(isA<RangeError>()),
      );
    });

    test('a line that opens with anything else is handed over untouched', () {
      // The mark would make a Latin-first line right-to-left.
      for (final String text in <String>[
        'Ahmed لانا',
        '2026 لا',
        '(سلفة)',
        '₹ 500',
        '',
      ]) {
        final String shaped = pdfText(text);
        expect(rightToLeftParagraphs(shaped), shaped, reason: text);
      }
      // Line by line: only the Arabic one is marked.
      expect(
        rightToLeftParagraphs(pdfText('Note\nلانا')),
        'Note\n\u200F${pdfText('لانا')}',
      );
    });

    test('the right-to-left mark changes nothing that is drawn', () {
      for (final String text in <String>['أحمد لانا', 'سلفة شخصية', 'عليّ']) {
        final String shaped = pdfText(text);
        expect(
          renderer_bidi.logicalToVisual(rightToLeftParagraphs(shaped)),
          renderer_bidi.logicalToVisual(shaped),
          reason: text,
        );
      }
    });
  });
}
