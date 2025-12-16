import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../models/product.dart';

class PDFService {
  static final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
  static final dateFormat = DateFormat('dd MMM yyyy');
  static final timeFormat = DateFormat('hh:mm a');

  // Generate Day Cashbook PDF
  static Future<Uint8List> generateDayCashbookPDF({
    required List<Sale> sales,
    required DateTime date,
    required String shopName,
    required double openingBalance,
  }) async {
    final pdf = pw.Document();

    final cashSales = sales.where((s) => s.paymentMethod == 'Cash').toList();
    final totalCashIn = cashSales.fold<double>(0, (sum, sale) => sum + sale.total);
    final closingBalance = openingBalance + totalCashIn;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    shopName,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Day Cashbook',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    dateFormat.format(date),
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Opening Balance
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Opening Balance:',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    currencyFormat.format(openingBalance),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Transactions Table
            pw.Text(
              'Cash Transactions',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),

            pw.Table.fromTextArray(
              headers: ['Time', 'Description', 'In', 'Out', 'Balance'],
              data: [
                ...cashSales.map((sale) {
                  openingBalance += sale.total;
                  return [
                    timeFormat.format(sale.date),
                    sale.customerName ?? 'Cash Sale',
                    currencyFormat.format(sale.total),
                    '-',
                    currencyFormat.format(openingBalance),
                  ];
                }),
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellHeight: 30,
              border: pw.TableBorder.all(color: PdfColors.grey400),
            ),
            pw.SizedBox(height: 16),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(8),
                color: PdfColors.grey100,
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Cash In:', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(
                        currencyFormat.format(totalCashIn),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Closing Balance:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        currencyFormat.format(closingBalance),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Generate Ledger PDF
  static Future<Uint8List> generateLedgerPDF({
    required List<Sale> sales,
    required DateTime startDate,
    required DateTime endDate,
    required String shopName,
  }) async {
    final pdf = pw.Document();

    final totalRevenue = sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final totalSales = sales.length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    shopName,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Account Ledger',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Summary Cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Container(
                  width: 150,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blue),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text('Total Sales', style: const pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '$totalSales',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  width: 150,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.green),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text('Total Revenue', style: const pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        currencyFormat.format(totalRevenue),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Transactions Table
            pw.Text(
              'Transaction Details',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),

            pw.Table.fromTextArray(
              headers: ['Date', 'Customer', 'Payment', 'Amount'],
              data: sales.map((sale) {
                return [
                  dateFormat.format(sale.date),
                  sale.customerName ?? '-',
                  sale.paymentMethod,
                  currencyFormat.format(sale.total),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellHeight: 30,
              border: pw.TableBorder.all(color: PdfColors.grey400),
            ),

            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Generate Sales Report PDF
  static Future<Uint8List> generateSalesReportPDF({
    required List<Sale> sales,
    required DateTime startDate,
    required DateTime endDate,
    required String shopName,
    required Map<String, dynamic> stats,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    shopName,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Sales Report',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Key Metrics
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildMetricBox('Total Sales', '${stats['totalSales']}'),
                _buildMetricBox('Revenue', currencyFormat.format(stats['revenue'])),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildMetricBox('Avg Order', currencyFormat.format(stats['avgOrder'])),
                _buildMetricBox('Items Sold', '${stats['itemsSold']}'),
              ],
            ),
            pw.SizedBox(height: 24),

            // Top Products
            pw.Text(
              'Top Selling Products',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),

            if (stats['topProducts'] != null)
              pw.Table.fromTextArray(
                headers: ['Rank', 'Product', 'Quantity', 'Revenue'],
                data: (stats['topProducts'] as List).asMap().entries.map((entry) {
                  final index = entry.key;
                  final product = entry.value;
                  return [
                    '${index + 1}',
                    product['name'],
                    '${product['quantity']}',
                    currencyFormat.format(product['revenue']),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellHeight: 30,
                border: pw.TableBorder.all(color: PdfColors.grey400),
              ),

            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildMetricBox(String title, String value) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Print or Share PDF
  static Future<void> printOrSharePDF(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  // Print PDF directly
  static Future<void> printPDF(Uint8List pdfBytes) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }
}