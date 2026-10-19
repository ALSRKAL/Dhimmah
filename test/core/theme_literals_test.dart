import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No screen paints with a colour literal.
///
/// The rule is that every colour comes from `AppPalette` (reached through
/// `Theme.of(context)` or `context.palette`), because that is the only way the
/// dark theme is right by construction rather than by inspection. Two real
/// defects came from breaking it: a spinner and a direction glyph hardcoded to
/// `Colors.white`, which is correct in the light theme and measurably wrong in
/// the dark one, where the fills behind them are pastels.
///
/// A sweep is the right shape for this rule because the failure mode is
/// *addition* — a new screen reaching for a swatch — and no widget test can
/// cover a screen that does not exist yet.
void main() {
  /// Where literals are legitimate, each with the reason it is exempt.
  const Map<String, String> allowedFiles = <String, String>{
    // Defines the tokens every other file consumes. A colour has to be written
    // down somewhere.
    'lib/core/theme/': 'defines the palette',
    // The PDF has no Theme and no dark mode; it draws into its own colour space
    // and uses PdfColors for its own defaults.
    'lib/core/pdf/': 'the PDF document has no widget tree',
    // The accent-disc formula lerps a swatch toward white or black to derive a
    // legible initials colour. Those two are the endpoints of a contrast
    // algorithm, not a surface, and the result is checked in
    // `palette_contrast_test.dart` for every swatch in both themes.
    'lib/core/widgets/person_avatar.dart': 'white/black are lerp endpoints',
    // The pedantic entry: `Colors.transparent` carries no hue at all, so there
    // is nothing for the theme to decide. It appears as the "off" side of a
    // ternary whose "on" side is a palette token.
    'lib/features/people/person_form_screen.dart': 'only Colors.transparent',
  };

  /// `Colors.<word>`, but not `PdfColors.<word>` — a word boundary stops the
  /// match from starting inside the longer identifier.
  final RegExp swatch = RegExp(r'\bColors\.([A-Za-z]+)');
  final RegExp rawColor = RegExp(r'\bColor\(\s*0x|\bColor\.fromARGB');

  /// Files under `lib/` as paths relative to the package root.
  List<String> libFiles() {
    final Directory lib = Directory('lib');
    if (!lib.existsSync()) {
      fail('run this from the package root — lib/ was not found');
    }
    return lib
        .listSync(recursive: true)
        .whereType<File>()
        .map((File f) => f.path)
        .where((String p) => p.endsWith('.dart'))
        // Generated code mirrors whatever the generator was told to write and
        // is not hand-edited.
        .where((String p) => !p.endsWith('.g.dart') && !p.endsWith('.freezed.dart'))
        .toList()
      ..sort();
  }

  bool exempt(String path) =>
      allowedFiles.keys.any((String prefix) => path.startsWith(prefix));

  test('lib/ has a real corpus to sweep', () {
    // A sweep over an empty or unreadable tree passes silently and proves
    // nothing, so the corpus itself is asserted.
    final List<String> files = libFiles();
    expect(files.length, greaterThan(50), reason: 'the sweep found almost no files');
    expect(files, contains('lib/core/theme/app_palette.dart'));
  });

  test('no screen reaches for a Material colour swatch', () {
    final List<String> offenders = <String>[];
    for (final String path in libFiles()) {
      if (exempt(path)) continue;
      for (final (int i, String line) in _lines(path)) {
        final RegExpMatch? m = swatch.firstMatch(line);
        if (m == null) continue;
        offenders.add('$path:${i + 1}  Colors.${m.group(1)}'
            '  -> use context.palette / Theme.of(context).colorScheme');
      }
    }
    expect(offenders, isEmpty, reason: 'hardcoded colours:\n${offenders.join('\n')}');
  });

  test('no screen writes a raw ARGB literal', () {
    final List<String> offenders = <String>[];
    for (final String path in libFiles()) {
      if (exempt(path)) continue;
      for (final (int i, String line) in _lines(path)) {
        if (!rawColor.hasMatch(line)) continue;
        offenders.add(
            '$path:${i + 1}  -> add a named token to AppPalette instead');
      }
    }
    expect(offenders, isEmpty, reason: 'raw colour literals:\n${offenders.join('\n')}');
  });

  test('the exemptions still apply to something', () {
    // An exemption that outlives the code it covered is how a rule quietly
    // stops covering anything: the file is renamed, the entry stays, and the
    // next file to match the stale prefix is exempt for free.
    for (final String prefix in allowedFiles.keys) {
      if (prefix.endsWith('.dart')) {
        expect(File(prefix).existsSync(), isTrue,
            reason: '$prefix is exempt but does not exist');
      } else {
        expect(libFiles().any((String p) => p.startsWith(prefix)), isTrue,
            reason: '$prefix is exempt but holds no Dart files');
      }
    }
  });

  test('the two exempt files hold only what they are exempt for', () {
    // Narrowing the two file-level exemptions, so they cannot become a
    // loophole: whichever file it is, only `Colors.transparent` may appear.
    for (final String path in <String>[
      'lib/core/widgets/person_avatar.dart',
      'lib/features/people/person_form_screen.dart',
    ]) {
      for (final (int i, String line) in _lines(path)) {
        final RegExpMatch? m = swatch.firstMatch(line);
        if (m == null) continue;
        expect(
          <String>['transparent', 'white', 'black'],
          contains(m.group(1)),
          reason: '$path:${i + 1} uses Colors.${m.group(1)}, which is not an '
              'exempt lerp endpoint or Colors.transparent',
        );
      }
    }
  });
}

/// The file's lines, with their zero-based index, ignoring comment-only lines so
/// that a doc comment discussing a colour is not an offence.
Iterable<(int, String)> _lines(String path) sync* {
  final List<String> lines = File(path).readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    final String trimmed = lines[i].trimLeft();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
    yield (i, lines[i]);
  }
}
