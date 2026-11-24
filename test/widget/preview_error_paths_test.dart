import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart' show PrintingPlatform;

/// The package's preview reports a failed rasterisation through the same
/// `onError` as a failed build. The statement screen shows «تعذّر التصدير» for
/// both, so a build that produced a valid PDF can still fail on the screen.
class _RasterFailingPrinting extends PrintingPlatform {
  @override
  Future<PrintingInfo> info() async => const PrintingInfo(canRaster: true);

  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) async* {
    throw StateError('raster failed');
  }

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
    bool windowsModernDialog,
  ) async => false;

  @override
  Future<List<Printer>> listPrinters() async => const <Printer>[];

  @override
  Future<Printer?> pickPrinter(Rect bounds) async => null;

  @override
  Future<bool> sharePdf(
    Uint8List bytes,
    String filename,
    Rect bounds,
    String? subject,
    String? body,
    List<String>? emails,
  ) async => false;

  @override
  Future<Uint8List> convertHtml(
    String html,
    String? baseUrl,
    PdfPageFormat format,
  ) async => Uint8List(0);
}

Widget _preview(LayoutCallback build) => MaterialApp(
  home: Scaffold(
    body: PdfPreview(
      build: build,
      useActions: false,
      allowPrinting: false,
      allowSharing: false,
      canChangeOrientation: false,
      canChangePageFormat: false,
      onError: (BuildContext context, Object error) =>
          const Text('preview failed'),
    ),
  ),
);

void main() {
  testWidgets('a failed raster reaches the same preview error state', (
    WidgetTester tester,
  ) async {
    final PrintingPlatform original = PrintingPlatform.instance;
    PrintingPlatform.instance = _RasterFailingPrinting();
    addTearDown(() => PrintingPlatform.instance = original);
    final FlutterExceptionHandler? old = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {};
    addTearDown(() => FlutterError.onError = old);

    await tester.pumpWidget(
      _preview((PdfPageFormat format) async => Uint8List.fromList(<int>[1])),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('preview failed'), findsOneWidget);
  });
}
