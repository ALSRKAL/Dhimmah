import 'package:dhimmah/core/utils/search_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Search matches words the way a reader of Arabic sees them.
///
/// A plain `contains` told «أحمد» and «احمد» apart, so a person saved with the
/// hamza could not be found by typing the name the way most keyboards type it.
void main() {
  bool same(String a, String b) => foldForSearch(a) == foldForSearch(b);

  group('letters written more than one way are one letter', () {
    test('every alef with a mark is an alef', () {
      for (final String form in <String>['أحمد', 'إحمد', 'آحمد', 'ٱحمد']) {
        expect(same(form, 'احمد'), isTrue, reason: form);
      }
    });

    test('a hamza typed as its own mark folds the same way', () {
      // ا followed by U+0654 HAMZA ABOVE, which some keyboards produce.
      expect(same('ا\u0654حمد', 'احمد'), isTrue);
    });

    test('alef maqsura and yeh match', () {
      expect(same('على', 'علي'), isTrue);
    });

    test('teh marbuta and heh match', () {
      expect(same('فاطمة', 'فاطمه'), isTrue);
    });
  });

  group('marks that do not change the word are ignored', () {
    test('vowel marks', () {
      expect(foldForSearch('مُحَمَّد'), foldForSearch('محمد'));
    });

    test('the tatweel', () {
      expect(foldForSearch('محـــمد'), foldForSearch('محمد'));
    });
  });

  group('digits and case', () {
    test('Arabic-Indic and extended digits read as Western digits', () {
      expect(foldForSearch('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(foldForSearch('۰۱۲'), '012');
    });

    test('Latin letters ignore case', () {
      expect(foldForSearch('Ahmed'), 'ahmed');
    });

    test('distinct letters stay distinct', () {
      expect(same('سعد', 'سعيد'), isFalse);
      expect(same('هند', 'هيد'), isFalse);
    });
  });

  group('searchMatches', () {
    test('finds a folded needle inside a longer text', () {
      expect(searchMatches('محمد أحمد عبدالرحمن', foldForSearch('احمد')), isTrue);
      expect(searchMatches('+967 771 234 567', foldForSearch('٧٧١')), isTrue);
    });

    test('an empty or missing field never matches', () {
      expect(searchMatches(null, 'a'), isFalse);
      expect(searchMatches('', 'a'), isFalse);
    });
  });
}
