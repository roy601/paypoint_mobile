import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/product_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/auth_provider.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import 'barcode_scanner_screen.dart';
import 'package:uuid/uuid.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({Key? key}) : super(key: key);

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final _searchController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _discountController = TextEditingController(text: '0');

  List<Product> _filteredProducts = [];
  List<CartItem> _cartItems = [];
  bool _isSearching = false;
  String _paymentMethod = 'Cash';
  double _taxRate = 0.0;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final productProvider = Provider.of<ProductProvider>(context, listen: false);

      productProvider.setOrganizationId(authProvider.organizationId);
      productProvider.loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  List<String> _getCategories() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final categories = productProvider.products
        .where((p) => p.category != null && p.category!.isNotEmpty)
        .map((p) => p.category!)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  void _searchProducts(String query) {
    if (query.isEmpty && _selectedCategory == null) {
      setState(() {
        _isSearching = false;
        _filteredProducts = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final allProducts = productProvider.products;

    final results = allProducts.where((product) {
      if (!product.isActive) return false;

      final matchesCategory = _selectedCategory == null || product.category == _selectedCategory;

      if (query.isEmpty) return matchesCategory;

      final nameLower = product.name.toLowerCase();
      final categoryLower = (product.category ?? '').toLowerCase();
      final queryLower = query.toLowerCase();

      final matchesSearch = nameLower.contains(queryLower) ||
          categoryLower.contains(queryLower) ||
          (product.barcode?.contains(query) ?? false);

      return matchesCategory && matchesSearch;
    }).toList();

    setState(() {
      _filteredProducts = results;
    });
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (result != null) {
      _searchByBarcode(result);
    }
  }

  void _searchByBarcode(String barcode) {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final allProducts = productProvider.products;

    try {
      final product = allProducts.firstWhere(
            (p) => p.barcode == barcode && p.isActive,
      );

      _addToCart(product);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('${product.name} added')),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _searchController.clear();
      setState(() {
        _isSearching = false;
        _filteredProducts = [];
      });

      _showScanAnotherDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product not found: $barcode'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showScanAnotherDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Scan Another?'),
        content: const Text('Do you want to scan another product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      _scanBarcode();
    }
  }

  void _addToCart(Product product) {
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Out of stock'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      final existingIndex = _cartItems.indexWhere((item) => item.product.id == product.id);

      if (existingIndex >= 0) {
        if (_cartItems[existingIndex].quantity < product.stock) {
          _cartItems[existingIndex].quantity++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Insufficient stock'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _cartItems.add(CartItem(product: product, quantity: 1));
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _updateQuantity(int index, int quantity) {
    if (quantity <= 0) {
      _removeFromCart(index);
      return;
    }

    if (quantity > _cartItems[index].product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only ${_cartItems[index].product.stock} in stock'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _cartItems[index].quantity = quantity;
    });
  }

  double _calculateSubtotal() {
    return _cartItems.fold(0, (sum, item) => sum + (item.product.price * item.quantity));
  }

  double _calculateDiscount() {
    return double.tryParse(_discountController.text) ?? 0;
  }

  double _calculateTax(double subtotal, double discount) {
    return (subtotal - discount) * (_taxRate / 100);
  }

  double _calculateTotal() {
    final subtotal = _calculateSubtotal();
    final discount = _calculateDiscount();
    final tax = _calculateTax(subtotal, discount);
    return subtotal - discount + tax;
  }

  void _showCartBottomSheet() {
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final subtotal = _calculateSubtotal();
    final discount = _calculateDiscount();
    final tax = _calculateTax(subtotal, discount);
    final total = _calculateTotal();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_cart, color: Colors.blue),
                          const SizedBox(width: 12),
                          const Text(
                            'Cart',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_cartItems.length} items',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Customer name
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _customerNameController,
                        decoration: InputDecoration(
                          labelText: 'Customer Name (Optional)',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    // Cart items
                    Expanded(
                      child: _cartItems.isEmpty
                          ? const Center(child: Text('Cart is empty'))
                          : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _cartItems.length,
                        itemBuilder: (context, index) {
                          final item = _cartItems[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          currencyFormat.format(item.product.price),
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: () {
                                          setState(() {
                                            _updateQuantity(index, item.quantity - 1);
                                          });
                                          setModalState(() {});
                                        },
                                        color: Colors.red,
                                      ),
                                      Text(
                                        '${item.quantity}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: () {
                                          setState(() {
                                            _updateQuantity(index, item.quantity + 1);
                                          });
                                          setModalState(() {});
                                        },
                                        color: Colors.green,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () {
                                          setState(() {
                                            _removeFromCart(index);
                                          });
                                          setModalState(() {});
                                        },
                                        color: Colors.red,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(child: Text('Discount:')),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _discountController,
                                  decoration: const InputDecoration(
                                    prefixText: '৳ ',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(8),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) {
                                    setState(() {});
                                    setModalState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(child: Text('Payment:')),
                              DropdownButton<String>(
                                value: _paymentMethod,
                                items: ['Cash', 'Card', 'Mobile']
                                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _paymentMethod = value!;
                                  });
                                  setModalState(() {});
                                },
                              ),
                            ],
                          ),
                          const Divider(),
                          _buildSummaryRow('Subtotal', currencyFormat.format(subtotal)),
                          _buildSummaryRow('Discount', '-${currencyFormat.format(discount)}'),
                          _buildSummaryRow('Tax', currencyFormat.format(tax)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'TOTAL',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(total),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _cartItems.isEmpty
                                  ? null
                                  : () {
                                Navigator.pop(context);
                                _processSale();
                              },
                              icon: const Icon(Icons.check_circle),
                              label: const Text(
                                'Complete Sale',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _processSale() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty'), backgroundColor: Colors.red),
      );
      return;
    }

    final total = _calculateTotal();
    final amountPaid = await _showPaymentDialog(total);

    if (amountPaid == null) return;

    final change = amountPaid - total;

    try {
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final saleId = const Uuid().v4();
      final subtotal = _calculateSubtotal();
      final discount = _calculateDiscount();
      final tax = _calculateTax(subtotal, discount);

      final saleItems = _cartItems.map((cartItem) {
        return SaleItem(
          id: const Uuid().v4(),
          saleId: saleId,
          productId: cartItem.product.id,
          productName: cartItem.product.name,
          price: cartItem.product.price,
          quantity: cartItem.quantity,
          discount: 0,
          subtotal: cartItem.product.price * cartItem.quantity,
        );
      }).toList();

      final sale = Sale(
        id: saleId,
        date: DateTime.now(),
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total,
        paymentMethod: _paymentMethod,
        amountPaid: amountPaid,
        change: change,
        customerName: _customerNameController.text.trim().isEmpty
            ? null
            : _customerNameController.text.trim(),
        items: saleItems,
      );

      await salesProvider.addSale(sale);

      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      for (var cartItem in _cartItems) {
        final updatedProduct = Product(
          id: cartItem.product.id,
          name: cartItem.product.name,
          barcode: cartItem.product.barcode,
          price: cartItem.product.price,
          cost: cartItem.product.cost,
          stock: cartItem.product.stock - cartItem.quantity,
          category: cartItem.product.category,
          imageUrl: cartItem.product.imageUrl,
          isActive: cartItem.product.isActive,
          createdAt: cartItem.product.createdAt,
        );
        await productProvider.updateProduct(updatedProduct);
      }

      if (mounted) {
        await _showReceiptDialog(sale, change);

        setState(() {
          _cartItems.clear();
          _customerNameController.clear();
          _discountController.text = '0';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<double?> _showPaymentDialog(double total) async {
    final controller = TextEditingController(text: total.toStringAsFixed(2));

    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total: ${NumberFormat.currency(symbol: '৳', decimalDigits: 2).format(total)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Amount Paid',
                prefixText: '৳ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount >= total) {
                Navigator.pop(context, amount);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Insufficient amount'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReceiptDialog(Sale sale, double change) async {
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 8),
            Text('Payment Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReceiptRow('Total', currencyFormat.format(sale.total)),
            _buildReceiptRow('Paid', currencyFormat.format(sale.amountPaid)),
            const Divider(),
            _buildReceiptRow('Change', currencyFormat.format(change), isHighlight: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.print),
            label: const Text('Print'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isHighlight ? 18 : 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 20 : 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final categories = _getCategories();

    final displayProducts = _isSearching
        ? _filteredProducts
        : productProvider.products.where((p) => p.isActive).toList();

    final cartItemCount = _cartItems.fold<int>(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Point of Sale', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search and Scan
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchProducts('');
                            },
                          )
                              : null,
                        ),
                        onChanged: _searchProducts,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: _scanBarcode,
                      backgroundColor: Colors.blue,
                      child: const Icon(Icons.qr_code_scanner),
                    ),
                  ],
                ),

                // Category chips
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildCategoryChip('All', null),
                        ...categories.map((cat) => _buildCategoryChip(cat, cat)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Products Grid
          Expanded(
            child: displayProducts.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    _isSearching ? 'No products found' : 'No products',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
                : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: displayProducts.length,
              itemBuilder: (context, index) {
                final product = displayProducts[index];
                final isOutOfStock = product.stock <= 0;
                final isLowStock = product.stock < 10;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: isOutOfStock ? null : () => _addToCart(product),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isOutOfStock ? Colors.grey.shade100 : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.inventory_2,
                                  size: 40,
                                  color: isOutOfStock ? Colors.grey : Colors.blue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (product.category != null)
                            Text(
                              product.category!,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                currencyFormat.format(product.price),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isOutOfStock ? Colors.grey : Colors.green,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOutOfStock
                                      ? Colors.red.shade50
                                      : isLowStock
                                      ? Colors.orange.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isOutOfStock ? 'Out' : '${product.stock}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isOutOfStock
                                        ? Colors.red
                                        : isLowStock
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // Floating Cart Button
      floatingActionButton: _cartItems.isEmpty
          ? null
          : FloatingActionButton.extended(
        onPressed: _showCartBottomSheet,
        backgroundColor: Colors.blue,
        icon: Stack(
          children: [
            const Icon(Icons.shopping_cart),
            if (cartItemCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$cartItemCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        label: Text('View Cart (${currencyFormat.format(_calculateTotal())})'),
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? value) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? value : null;
            _searchProducts(_searchController.text);
          });
        },
        backgroundColor: Colors.white,
        selectedColor: Colors.blue.shade100,
        checkmarkColor: Colors.blue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, required this.quantity});
}