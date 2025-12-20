import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../models/expense.dart';
import '../models/product.dart';
import '../screens/ledger_screen.dart';  // For LedgerType enum

class PDFService {
  static final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
  static final dateFormat = DateFormat('dd MMM yyyy');
  static final timeFormat = DateFormat('hh:mm a');

  // Generate Day Cashbook PDF
  static Future<Uint8List> generateDayCashbookPDF({
    required List<Sale> sales,
    required List<Expense> expenses,  // ADD THIS
    required double purchases,        // ADD THIS
    required DateTime date,
    required String shopName,
    required String shopAddress,      // ADD THIS
    required double openingBalance,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);

    // Calculate totals
    final totalSales = sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final totalExpenses = expenses.fold<double>(0, (sum, exp) => sum + exp.amount);
    final totalCreditIn = totalSales;
    final totalDebitOut = totalExpenses + purchases;
    final closingBalance = openingBalance + totalCreditIn - totalDebitOut;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      shopName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (shopAddress.isNotEmpty)
                      pw.Text(
                        shopAddress,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      dateFormat.format(date),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 1),
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Text(
                        'CASH BOOK',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Main Table
              pw.Table(
                border: pw.TableBorder.all(width: 1),
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Particulars',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Dr.',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Cr.',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),

                  // Opening Balance
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('BFC (Brought Forward Cash)'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(''),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          currencyFormat.format(openingBalance),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),

                  // Purchases Row
                  if (purchases > 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Purchases'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(''),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            currencyFormat.format(purchases),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),

                  // Expenses Rows
                  ...expenses.map((expense) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('${expense.description} - ${expense.category}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(''),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            currencyFormat.format(expense.amount),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }).toList(),

                  // Total Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(''),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          currencyFormat.format(totalDebitOut),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          currencyFormat.format(openingBalance + purchases + totalExpenses),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Cash in Hand Summary
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 2),
                  ),
                  child: pw.Text(
                    'Cash in Hand    ${currencyFormat.format(closingBalance)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(now)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    'Powered by PayPoint',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateLedgerPDF({
    required LedgerType ledgerType,
    required List<Sale> sales,
    required List<Expense> expenses,
    required double purchases,
    required DateTime startDate,
    required DateTime endDate,
    required String shopName,
    required String shopAddress,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);

    // Calculate totals
    final totalSales = sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final totalExpenses = expenses.fold<double>(0, (sum, exp) => sum + exp.amount);
    final totalCost = totalExpenses + purchases;
    final profit = totalSales - totalCost;

    String ledgerTitle = '';
    switch (ledgerType) {
      case LedgerType.general:
        ledgerTitle = 'GENERAL LEDGER';
        break;
      case LedgerType.purchase:
        ledgerTitle = 'PURCHASE LEDGER';
        break;
      case LedgerType.sales:
        ledgerTitle = 'SALES LEDGER';
        break;
      case LedgerType.expense:
        ledgerTitle = 'EXPENSE VOUCHER';
        break;
      case LedgerType.income:
        ledgerTitle = 'INCOME VOUCHER';
        break;
      case LedgerType.profitLoss:
        ledgerTitle = 'PROFIT & LOSS STATEMENT';
        break;
      case LedgerType.balanceSheet:
        ledgerTitle = 'BALANCE SHEET';
        break;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      shopName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (shopAddress.isNotEmpty)
                      pw.Text(
                        shopAddress,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      '${dateFormat.format(startDate)} to ${dateFormat.format(endDate)}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 1),
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Text(
                        ledgerTitle,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Content based on ledger type
              if (ledgerType == LedgerType.general)
                _buildGeneralLedgerPDF(sales, expenses, currencyFormat, dateFormat),
              if (ledgerType == LedgerType.sales || ledgerType == LedgerType.income)
                _buildSalesLedgerPDF(sales, currencyFormat, dateFormat),
              if (ledgerType == LedgerType.expense)
                _buildExpenseLedgerPDF(expenses, currencyFormat, dateFormat),
              if (ledgerType == LedgerType.profitLoss)
                _buildProfitLossPDF(totalSales, totalExpenses, purchases, profit, currencyFormat),
              if (ledgerType == LedgerType.balanceSheet)
                _buildBalanceSheetPDF(totalSales, totalExpenses, currencyFormat),
              if (ledgerType == LedgerType.purchase)
                pw.Center(
                  child: pw.Text(
                    'Purchase ledger coming soon',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ),

              pw.Spacer(),

              // Footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(now)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    'Powered by PayPoint',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildGeneralLedgerPDF(
      List<Sale> sales,
      List<Expense> expenses,
      NumberFormat currencyFormat,
      DateFormat dateFormat,
      ) {
    // Combine all transactions
    final transactions = <Map<String, dynamic>>[];

    for (var sale in sales) {
      transactions.add({
        'type': 'Sale',
        'description': sale.customerName ?? 'Sale',
        'date': sale.date,
        'debit': 0.0,
        'credit': sale.total,
      });
    }

    for (var expense in expenses) {
      transactions.add({
        'type': 'Expense',
        'description': expense.description,
        'date': expense.date,
        'debit': expense.amount,
        'credit': 0.0,
      });
    }

    // Sort by date
    transactions.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    final totalDebit = transactions.fold<double>(0, (sum, t) => sum + (t['debit'] as double));
    final totalCredit = transactions.fold<double>(0, (sum, t) => sum + (t['credit'] as double));

    return pw.Column(
      children: [
        pw.Table(
          border: pw.TableBorder.all(width: 1),
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Particulars', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Dr.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Cr.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                ),
              ],
            ),
            // Transactions
            ...transactions.map((t) {
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(dateFormat.format(t['date'] as DateTime), style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('${t['description']} (${t['type']})', style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      t['debit'] > 0 ? currencyFormat.format(t['debit']) : '',
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      t['credit'] > 0 ? currencyFormat.format(t['credit']) : '',
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              );
            }).toList(),
            // Total
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    currencyFormat.format(totalDebit),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    currencyFormat.format(totalCredit),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSalesLedgerPDF(
      List<Sale> sales,
      NumberFormat currencyFormat,
      DateFormat dateFormat,
      ) {
    final totalSales = sales.fold<double>(0, (sum, sale) => sum + sale.total);

    return pw.Column(
      children: [
        pw.Table(
          border: pw.TableBorder.all(width: 1),
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Customer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Payment Method', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                ),
              ],
            ),
            // Sales
            ...sales.map((sale) {
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(dateFormat.format(sale.date), style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(sale.customerName ?? 'Walk-in', style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(sale.paymentMethod, style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      currencyFormat.format(sale.total),
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              );
            }).toList(),
            // Total
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Total Sales', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    currencyFormat.format(totalSales),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildExpenseLedgerPDF(
      List<Expense> expenses,
      NumberFormat currencyFormat,
      DateFormat dateFormat,
      ) {
    final totalExpenses = expenses.fold<double>(0, (sum, exp) => sum + exp.amount);

    return pw.Column(
      children: [
        pw.Table(
          border: pw.TableBorder.all(width: 1),
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                ),
              ],
            ),
            // Expenses
            ...expenses.map((expense) {
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(dateFormat.format(expense.date), style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(expense.description, style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(expense.category, style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      currencyFormat.format(expense.amount),
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              );
            }).toList(),
            // Total
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Total Expenses', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    currencyFormat.format(totalExpenses),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildProfitLossPDF(
      double totalRevenue,
      double totalExpenses,
      double purchases,
      double profit,
      NumberFormat currencyFormat,
      ) {
    final totalCost = totalExpenses + purchases;

    return pw.Table(
      border: pw.TableBorder.all(width: 1),
      children: [
        // Revenue Section
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Revenue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Sales'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(currencyFormat.format(totalRevenue), textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Total Revenue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                currencyFormat.format(totalRevenue),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        // Expenses Section
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Expenses', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Operating Expenses'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(currencyFormat.format(totalExpenses), textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Purchases'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(currencyFormat.format(purchases), textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Total Expenses', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                currencyFormat.format(totalCost),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        // Net Profit/Loss
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: profit >= 0 ? PdfColors.green100 : PdfColors.red100,
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                profit >= 0 ? 'Net Profit' : 'Net Loss',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                currencyFormat.format(profit.abs()),
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildBalanceSheetPDF(
      double totalRevenue,
      double totalExpenses,
      NumberFormat currencyFormat,
      ) {
    final cash = 0.0; // Will be calculated from opening balance
    final totalAssets = cash + totalRevenue;
    final totalLiabilities = totalExpenses;
    final equity = totalAssets - totalLiabilities;

    return pw.Table(
      border: pw.TableBorder.all(width: 1),
      children: [
        // Assets Section
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Assets', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Cash'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(currencyFormat.format(cash), textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Accounts Receivable'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(currencyFormat.format(totalRevenue), textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Total Assets', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                currencyFormat.format(totalAssets),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        // Liabilities Section
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Liabilities', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Accounts Payable'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(currencyFormat.format(totalLiabilities), textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Total Liabilities', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                currencyFormat.format(totalLiabilities),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        // Equity Section
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Equity', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Owner\'s Equity'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(currencyFormat.format(equity), textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Total Equity', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                currencyFormat.format(equity),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
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