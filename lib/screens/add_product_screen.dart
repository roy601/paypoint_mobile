import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../models/product.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product;

  const AddProductScreen({Key? key, this.product}) : super(key: key);

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();

  String? _selectedCategory;
  bool _isActive = true;
  bool _isLoading = false;

  // Default categories
  final List<String> _defaultCategories = [
    'Electronics',
    'Clothing',
    'Food & Beverages',
    'Home & Garden',
    'Sports',
    'Books',
    'Toys',
    'Health & Beauty',
    'Automotive',
    'Other',
  ];

  List<String> _customCategories = [];
  List<String> get _allCategories => [..._defaultCategories, ..._customCategories];

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();

    if (isEditing) {
      _nameController.text = widget.product!.name;
      _barcodeController.text = widget.product!.barcode ?? '';
      _priceController.text = widget.product!.price.toString();
      _costController.text = widget.product!.cost.toString();
      _stockController.text = widget.product!.stock.toString();
      _selectedCategory = widget.product!.category;
      _isActive = widget.product!.isActive;
    }
  }

  Future<void> _loadCustomCategories() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final products = productProvider.products;

    // Get unique categories from existing products
    final categories = products
        .where((p) => p.category != null && p.category!.isNotEmpty)
        .map((p) => p.category!)
        .toSet()
        .where((cat) => !_defaultCategories.contains(cat))
        .toList();

    setState(() {
      _customCategories = categories;
    });
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Furniture',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        if (!_allCategories.contains(result)) {
          _customCategories.add(result);
        }
        _selectedCategory = result;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final product = Product(
        id: isEditing ? widget.product!.id : const Uuid().v4(),
        name: _nameController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        price: double.parse(_priceController.text),
        cost: double.parse(_costController.text),
        stock: int.parse(_stockController.text),
        category: _selectedCategory,
        imageUrl: null,
        isActive: _isActive,
        createdAt: isEditing ? widget.product!.createdAt : DateTime.now(),
      );

      if (isEditing) {
        await productProvider.updateProduct(product);
      } else {
        await productProvider.addProduct(product);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Product updated successfully' : 'Product added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Product Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                hintText: 'e.g., Samsung Galaxy S24',
                prefixIcon: Icon(Icons.shopping_bag),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter product name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Barcode
            TextFormField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Barcode (Optional)',
                hintText: 'Scan or enter barcode',
                prefixIcon: const Icon(Icons.qr_code_scanner),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () {
                    // TODO: Open barcode scanner
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Barcode scanner coming soon!')),
                    );
                  },
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Category Dropdown with Add Option
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              hint: const Text('Select or add category'),
              items: [
                ..._allCategories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }),
                const DropdownMenuItem(
                  value: '__add_new__',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Add New Category',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == '__add_new__') {
                  _showAddCategoryDialog();
                } else {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Price and Cost
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    decoration: const InputDecoration(
                      labelText: 'Cost Price',
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.money_off),
                      prefixText: '৳ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Sale Price',
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.attach_money),
                      prefixText: '৳ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stock
            TextFormField(
              controller: _stockController,
              decoration: const InputDecoration(
                labelText: 'Initial Stock',
                hintText: '0',
                prefixIcon: Icon(Icons.inventory),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter stock quantity';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Active Status
            SwitchListTile(
              title: const Text('Active'),
              subtitle: Text(_isActive ? 'Product is available for sale' : 'Product is hidden'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
              secondary: Icon(
                _isActive ? Icons.check_circle : Icons.cancel,
                color: _isActive ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                isEditing ? 'Update Product' : 'Add Product',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}