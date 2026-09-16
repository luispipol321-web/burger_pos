import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BurgerPosApp());
}

class BurgerPosApp extends StatelessWidget {
  const BurgerPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Burger POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const PosHomeScreen(),
    );
  }
}

class Product {
  final String id;
  String name;
  double price;
  double costPrice;
  String? imagePath;
  int stock;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    this.imagePath,
    this.stock = 50,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'costPrice': costPrice,
      'imagePath': imagePath,
      'stock': stock,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] as num).toDouble(),
      costPrice: (map['costPrice'] ?? 0.0 as num).toDouble(),
      imagePath: map['imagePath'],
      stock: map['stock'] ?? 50,
    );
  }
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class KitchenOrder {
  final String id;
  final String details;
  final String timestamp;

  KitchenOrder({required this.id, required this.details, required this.timestamp});
}

class PosHomeScreen extends StatefulWidget {
  const PosHomeScreen({super.key});

  @override
  State<PosHomeScreen> createState() => _PosHomeScreenState();
}

class _PosHomeScreenState extends State<PosHomeScreen> {
  List<Product> _products = [];
  List<Map<String, dynamic>> _rawMaterials = [];

  final List<Map<String, dynamic>> _defaultRawMaterials = [
    {'name': 'Pan de Hamburguesa', 'cost': 5.0, 'stock': 100, 'unit': 'pzas'},
    {'name': 'Carne de Res (Medallón)', 'cost': 18.0, 'stock': 80, 'unit': 'pzas'},
    {'name': 'Queso Amarillo', 'cost': 3.0, 'stock': 120, 'unit': 'pzas'},
    {'name': 'Papas para freír (kg)', 'cost': 30.0, 'stock': 25, 'unit': 'kg'},
  ];
  final List<CartItem> _cart = [];
  final List<KitchenOrder> _kitchenOrders = [];
  List<Map<String, dynamic>> _salesHistory = [];

  Map<String, Map<String, dynamic>> _loyaltyData = {};

  double _totalSalesToday = 0.0;
  int _totalOrdersToday = 0;
  bool _isLoading = true;

  final List<Product> _defaultProducts = [
    Product(id: '1', name: 'Hamburguesa XL', price: 140.0, costPrice: 60.0, stock: 40),
    Product(id: '2', name: 'Papas Sencillas', price: 45.0, costPrice: 15.0, stock: 50),
    Product(id: '3', name: 'Clásica', price: 95.0, costPrice: 40.0, stock: 30),
    Product(id: '4', name: 'Doble Queso', price: 125.0, costPrice: 50.0, stock: 25),
    Product(id: '5', name: 'Refresco 600ml', price: 35.0, costPrice: 18.0, stock: 60),
    Product(id: '6', name: 'Malteada', price: 65.0, costPrice: 25.0, stock: 20),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? productsJson = prefs.getString('saved_products');
      final String? loyaltyJson = prefs.getString('loyalty_data_strict_v3');
      final String? historyJson = prefs.getString('sales_history_v2');

      final String? rawJson = prefs.getString('raw_materials_v1');
    if (rawJson != null) {
      _rawMaterials = List<Map<String, dynamic>>.from(jsonDecode(rawJson));
    } else {
      _rawMaterials = List.from(_defaultRawMaterials);
      _saveRawMaterials();
    }
      setState(() {
        _totalSalesToday = prefs.getDouble('total_sales') ?? 0.0;
        _totalOrdersToday = prefs.getInt('total_orders') ?? 0;

        if (productsJson != null) {
          final List<dynamic> decoded = jsonDecode(productsJson);
          _products = decoded.map((item) => Product.fromMap(item)).toList();
        } else {
          _products = List.from(_defaultProducts);
          _saveProducts();
        }

        if (loyaltyJson != null) {
          final Map<String, dynamic> decodedLoyalty = jsonDecode(loyaltyJson);
          _loyaltyData = decodedLoyalty.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
        }

        if (historyJson != null) {
          _salesHistory = List<Map<String, dynamic>>.from(jsonDecode(historyJson));
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _products = List.from(_defaultProducts);
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRawMaterials() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('raw_materials_v1', jsonEncode(_rawMaterials));
    }

    void _addRawMaterial(String name, double cost, int stock, String unit) {
      setState(() {
        _rawMaterials.add({'name': name, 'cost': cost, 'stock': stock, 'unit': unit});
      });
      _saveRawMaterials();
    }

    void _updateRawMaterial(Map<String, dynamic> material, String name, double cost, int stock) {
      setState(() {
        material['name'] = name;
        material['cost'] = cost;
        material['stock'] = stock;
      });
      _saveRawMaterials();
    }

    void _deleteRawMaterial(int index) {
      setState(() {
        _rawMaterials.removeAt(index);
      });
      _saveRawMaterials();
    }

    void _restockRawMaterial(Map<String, dynamic> material, int qty, double newCost) {
      final oldCost = (material['cost'] as num).toDouble();
      setState(() {
        material['stock'] = (material['stock'] as int) + qty;
        material['cost'] = newCost;
      });
      _saveRawMaterials();

      if (newCost > oldCost && oldCost > 0) {
        _showRawPriceIncreaseAlert(material['name'], oldCost, newCost);
      }
    }

    void _showRawPriceIncreaseAlert(String materialName, double oldCost, double newCost) {
      final diff = newCost - oldCost;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ ¡ALERTA DE ALZA DE INSUMO!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text(
            'El insumo clave "$materialName" subió de precio en tu proveedor.\n\n'
            '• Costo anterior: \$${oldCost.toStringAsFixed(2)}\n'
            '• Costo nuevo: \$${newCost.toStringAsFixed(2)} (+ \$${diff.toStringAsFixed(2)})\n\n'
            'Te recomendamos revisar los precios de venta en tu Menú Comercial.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text('ENTENDIDO'),
            ),
          ],
        ),
      );
    }
  Future<void> _saveProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_products.map((p) => p.toMap()).toList());
    await prefs.setString('saved_products', encoded);
  }

  Future<void> _saveLoyaltyData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('loyalty_data_strict_v3', jsonEncode(_loyaltyData));
  }

  Future<void> _saveSalesHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sales_history_v2', jsonEncode(_salesHistory));
  }

  void _openInventoryView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryManagementScreen(
          products: _products,
          onRestock: (Product product, int qty, double newCost) {},
          onAddProduct: _addProduct,
          onUpdateProduct: _updateProduct,
          onDeleteProduct: _deleteProduct,
          rawMaterials: _rawMaterials,
          onAddRawMaterial: _addRawMaterial,
          onUpdateRawMaterial: _updateRawMaterial,
          onDeleteRawMaterial: _deleteRawMaterial,
          onRestockRawMaterial: _restockRawMaterial,
        ),
      ),
    );
  }
  void _restockRawMaterial(Map<String, dynamic> material, int qty, double newCost) {
      final oldCost = (material['cost'] as num).toDouble();
      setState(() {
        material['stock'] = (material['stock'] as int) + qty;
        material['cost'] = newCost;
      });
      _saveRawMaterials();

      if (newCost > oldCost && oldCost > 0) {
        _showRawPriceIncreaseAlert(material['name'], oldCost, newCost);
      }
    }

    void _showRawPriceIncreaseAlert(String materialName, double oldCost, double newCost) {
      final diff = newCost - oldCost;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ ¡ALERTA DE ALZA DE INSUMO!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text(
            'El insumo "$materialName" subió de precio con tu proveedor.\n\n'
            '• Costo anterior: \$${oldCost.toStringAsFixed(2)}\n'
            '• Costo nuevo: \$${newCost.toStringAsFixed(2)} (+ \$${diff.toStringAsFixed(2)})\n\n'
            'Te recomendamos revisar los precios de tus platos en el Menú Comercial.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text('ENTENDIDO'),
            ),
          ],
        ),
      );
    }

    void _deductRawMaterialsForSale(List<CartItem> soldItems) {
      for (var cartItem in soldItems) {
        for (var rawMat in _rawMaterials) {
          if (cartItem.product.name.toLowerCase().contains('hamburguesa') && 
             (rawMat['name'].toString().toLowerCase().contains('carne') || rawMat['name'].toString().toLowerCase().contains('pan'))) {
            int currentStock = (rawMat['stock'] as int);
            int qtyToDeduct = cartItem.quantity;
            rawMat['stock'] = (currentStock - qtyToDeduct).clamp(0, 999999);
          }
        }
      }
      _saveRawMaterials();
    }
  Future<void> _recordSale(double amount, List<CartItem> items, String method) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() { _deductRawMaterialsForSale(items);
      _totalSalesToday += amount;
      _totalOrdersToday += 1;
      _salesHistory.add({
        'date': dateStr,
        'total': amount,
        'method': method,
        'itemsCount': items.fold(0, (sum, i) => sum + i.quantity),
      });
    });
Future<void> _selectReportDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2025),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        
        final salesOnDate = _salesHistory.where((sale) => sale['date'] == dateStr).toList();
        double totalOnDate = salesOnDate.fold(0.0, (sum, sale) => sum + (sale['total'] as num).toDouble());
        int ordersOnDate = salesOnDate.length;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('📊 Reporte del día $dateStr', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• Total Vendido: \$${totalOnDate.toStringAsFixed(2)}'),
                Text('• Órdenes Realizadas: $ordersOnDate'),
                const SizedBox(height: 10),
                const Text('Desglose de transacciones:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                SizedBox(
                  height: 150,
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: salesOnDate.length,
                    itemBuilder: (context, index) {
                      final sale = salesOnDate[index];
                      return ListTile(
                        dense: true,
                        title: Text('Venta: \$${(sale['total'] as num).toStringAsFixed(2)}'),
                        subtitle: Text('Método: ${sale['method']} • Artículos: ${sale['itemsCount']}'),
                      );
                    },
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                child: const Text('CERRAR'),
              ),
            ],
          ),
        );
      }
    }
    void _showClientsLoyaltyView() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('👥 Clientes y Lealtad', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: _loyaltyData.isEmpty
                ? const Center(child: Text('Aún no hay clientes registrados en el sistema.'))
                : ListView.builder(
                    itemCount: _loyaltyData.length,
                    itemBuilder: (context, index) {
                final clientKey = _loyaltyData.keys.elementAt(index);
                final clientInfo = _loyaltyData[clientKey] as Map<String, dynamic>?;
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(clientInfo?['name'] ?? clientKey, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Última compra: ${clientInfo?['lastPurchase'] ?? 'N/A'}\nVisitas / Puntos: ${clientInfo?['visits'] ?? 1}'),
                  isThreeLine: true,
                );
              },
                  ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text('CERRAR'),
            ),
          ],
        ),
      );
    }
    
    for (var item in items) {
      final index = _products.indexWhere((p) => p.id == item.product.id);
      if (index >= 0 && _products[index].stock >= item.quantity) {
        _products[index].stock -= item.quantity;
      }
    }

    final orderDetails = items.map((i) => '${i.quantity}x ${i.product.name}').join(', ');
    _kitchenOrders.add(KitchenOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString().substring(8),
      details: orderDetails,
      timestamp: '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
    ));

    await prefs.setDouble('total_sales', _totalSalesToday);
    await prefs.setInt('total_orders', _totalOrdersToday);
    _saveProducts();
    _saveSalesHistory();
  }

  void _addProduct(String name, double price, double costPrice, String? imagePath, int stock) {
    final newProduct = Product(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      price: price,
      costPrice: costPrice,
      imagePath: imagePath,
      stock: stock,
    );
    setState(() {
      _products.add(newProduct);
    });
    _saveProducts();
  }

  void _updateProduct(Product product, String name, double price, double costPrice, String? imagePath, int stock) {
    setState(() {
      product.name = name;
      product.price = price;
      product.costPrice = costPrice;
      if (imagePath != null) product.imagePath = imagePath;
      product.stock = stock;
    });
    _saveProducts();
  }

  void _deleteProduct(int index) {
    setState(() {
      _products.removeAt(index);
    });
    _saveProducts();
  }

  void _addToCart(Product product) {
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto agotado en inventario'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() {
      final index = _cart.indexWhere((item) => item.product.id == product.id);
      if (index >= 0) {
        if (_cart[index].quantity < product.stock) {
          _cart[index].quantity++;
        }
      } else {
        _cart.add(CartItem(product: product));
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      if (_cart[index].quantity > 1) {
        _cart[index].quantity--;
      } else {
        _cart.removeAt(index);
      }
    });
  }

  double get _total => _cart.fold(0, (sum, item) => sum + (item.product.price * item.quantity));


  void _showPriceIncreaseAlert(Product product, double oldCost, double newCost) {
    final diff = newCost - oldCost;
    final suggestedPrice = product.price + (diff * 1.3);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ ¡ALERTA DE COSTO DE COMPRA!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(
          'El insumo "${product.name}" subió de precio de compra.\n\n'
          '• Costo anterior: \$${oldCost.toStringAsFixed(2)}\n'
          '• Costo nuevo: \$${newCost.toStringAsFixed(2)} (+ \$${diff.toStringAsFixed(2)})\n\n'
          'Sugerencia: Subir el precio de venta de \$${product.price.toStringAsFixed(2)} a \$${suggestedPrice.toStringAsFixed(2)}.\n\n'
          '¿El dueño autoriza ajustar el precio público de este producto?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mantener Precio Actual'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                product.price = suggestedPrice;
              });
              _saveProducts();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Precio de ${product.name} actualizado a \$${suggestedPrice.toStringAsFixed(2)}'), backgroundColor: Colors.green),
              );
            },
            child: const Text('AUTORIZAR Y AUMENTAR'),
          ),
        ],
      ),
    );
  }

  void _showRewardAlertAndProcess(String clientName, String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🎉 ¡8ª VISITA DE $clientName!', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Text(
          '¡El cliente $clientName ($phone) acumuló 8 días de visitas!\n\n'
          'Ganó de regalo:\n• 1 Hamburguesa XL\n• 1 Papas Sencillas\n\n'
          '¿Deseas descontar del inventario y mandar a preparar a Cocina ahora?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              for (var p in _products) {
                if (p.name.contains('Hamburguesa XL') && p.stock > 0) p.stock--;
                if (p.name.contains('Papas Sencillas') && p.stock > 0) p.stock--;
              }

              final now = DateTime.now();
              _kitchenOrders.add(KitchenOrder(
                id: 'PREMIO-${phone.length >= 4 ? phone.substring(phone.length - 4) : phone}',
                details: '🎁 REGALO LEALTAD (8 Visitas - $clientName): 1x Hamburguesa XL + 1x Papas Sencillas',
                timestamp: '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
              ));

              _loyaltyData[phone]!['visits'] = 0;
              _saveLoyaltyData();
              _saveProducts();

              Navigator.pop(context);
              setState(() {});

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Premio de lealtad enviado a Cocina'), backgroundColor: Colors.green),
              );
            },
            child: const Text('ENVIAR A COCINA'),
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog() {
    final cashController = TextEditingController();
    final phoneController = TextEditingController();
    final nameController = TextEditingController();
    String paymentMethod = 'Efectivo';
    double change = 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cobrar Orden', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total: \$${_total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono Cliente (Lealtad)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone, color: Colors.orange),
                      ),
                      onChanged: (val) {
                        final trimmed = val.trim();
                        if (_loyaltyData.containsKey(trimmed)) {
                          setDialogState(() {
                            nameController.text = _loyaltyData[trimmed]!['name'] ?? '';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Cliente',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person, color: Colors.orange),
                      ),
                    ),
                    const SizedBox(height: 15),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Efectivo', label: Text('Efectivo'), icon: Icon(Icons.money)),
                        ButtonSegment(value: 'Tarjeta', label: Text('Tarjeta'), icon: Icon(Icons.credit_card)),
                        ButtonSegment(value: 'Transferencia', label: Text('Transf.'), icon: Icon(Icons.account_balance)),
                      ],
                      selected: {paymentMethod},
                      onSelectionChanged: (Set<String> newSelection) {
                        setDialogState(() {
                          paymentMethod = newSelection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    if (paymentMethod == 'Efectivo') ...[
                      TextField(
                        controller: cashController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Paga con (\$)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          final paid = double.tryParse(value) ?? 0.0;
                          setDialogState(() {
                            change = paid >= _total ? paid - _total : 0.0;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cambio: \$${change.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: change >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () {
                    final paid = double.tryParse(cashController.text) ?? 0.0;
                    if (paymentMethod == 'Efectivo' && paid < _total) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El monto ingresado es menor al total'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    bool reachedEight = false;
                    final clientPhone = phoneController.text.trim();
                    final clientName = nameController.text.trim().isEmpty ? 'Cliente' : nameController.text.trim();

                    if (clientPhone.length >= 7) {
                      final now = DateTime.now();
                      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

                      if (!_loyaltyData.containsKey(clientPhone)) {
                        _loyaltyData[clientPhone] = {
                          'name': clientName,
                          'visits': 1,
                          'lastVisitDate': todayStr,
                        };
                      } else {
                        _loyaltyData[clientPhone]!['name'] = clientName;
                        final lastVisit = _loyaltyData[clientPhone]!['lastVisitDate'];
                        
                        if (lastVisit != todayStr) {
                          int visits = (_loyaltyData[clientPhone]!['visits'] ?? 0) + 1;
                          _loyaltyData[clientPhone]!['visits'] = visits;
                          _loyaltyData[clientPhone]!['lastVisitDate'] = todayStr;

                          if (visits >= 8) {
                            reachedEight = true;
                          }
                        }
                      }
                      _saveLoyaltyData();
                    }

                    _recordSale(_total, List.from(_cart), paymentMethod);
                    Navigator.pop(context);
                    setState(() {
                      _cart.clear();
                    });

                    if (reachedEight) {
                      _showRewardAlertAndProcess(clientName, clientPhone);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡Venta completada y enviada a Cocina!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('CONFIRMAR COBRO'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCorteCajaDialog() {
    double totalEfectivo = 0.0;
    double totalTarjeta = 0.0;
    double totalTransferencia = 0.0;

    for (var sale in _salesHistory) {
      final method = sale['method'];
      final total = (sale['total'] as num).toDouble();
      if (method == 'Efectivo') totalEfectivo += total;
      if (method == 'Tarjeta') totalTarjeta += total;
      if (method == 'Transferencia') totalTransferencia += total;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Reporte y Corte de Caja'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Órdenes completadas hoy: $_totalOrdersToday', style: const TextStyle(fontSize: 15)),
              Text('Ventas Totales Hoy: \$${_totalSalesToday.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
              const Divider(),
              Text('💵 Efectivo: \$${totalEfectivo.toStringAsFixed(2)}'),
              Text('💳 Tarjeta: \$${totalTarjeta.toStringAsFixed(2)}'),
              Text('🏦 Transferencia: \$${totalTransferencia.toStringAsFixed(2)}'),
              const Divider(),
              const Text('Historial por Fecha y Hora:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              SizedBox(
                height: 150,
                child: _salesHistory.isEmpty
                    ? const Center(child: Text('Sin ventas registradas'))
                    : ListView.builder(
                        itemCount: _salesHistory.length,
                        itemBuilder: (context, i) {
                          final item = _salesHistory[_salesHistory.length - 1 - i];
                          return ListTile(
                            dense: true,
                            title: Text('${item['date']} - \$${item['total']}'),
                            subtitle: Text('Método: ${item['method']} | Piezas: ${item['itemsCount']}'),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _exportPdfReport(totalEfectivo, totalTarjeta, totalTransferencia),
            child: const Text('Exportar PDF', style: TextStyle(color: Colors.orange)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('total_sales', 0.0);
              await prefs.setInt('total_orders', 0);
              await prefs.remove('sales_history_v2');
              setState(() {
                _totalSalesToday = 0.0;
                _totalOrdersToday = 0;
                _salesHistory.clear();
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Reiniciar Caja'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdfReport(double ef, double tar, double tra) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('🍔 BURGER POS - REPORTE DE CORTE DE CAJA', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Órdenes Totales: $_totalOrdersToday'),
              pw.Text('Venta Global: \$${_totalSalesToday.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Text('Desglose por Método de Pago:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('• Efectivo: \$${ef.toStringAsFixed(2)}'),
              pw.Text('• Tarjeta: \$${tar.toStringAsFixed(2)}'),
              pw.Text('• Transferencia: \$${tra.toStringAsFixed(2)}'),
              pw.SizedBox(height: 15),
              pw.Divider(),
              pw.Text('Historial Detallado de Ventas:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              ..._salesHistory.map((s) => pw.Text('${s['date']} | ${s['method']} | \$${s['total']} (${s['itemsCount']} pzas)')),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Corte_Caja_BurgerPOS.pdf',
    );
  }

  void _showKitchenDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('👨‍🍳 Comandos en Cocina'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _kitchenOrders.isEmpty
              ? const Center(child: Text('Sin órdenes pendientes'))
              : ListView.builder(
                  itemCount: _kitchenOrders.length,
                  itemBuilder: (context, index) {
                    final order = _kitchenOrders[index];
                    return Card(
                      color: Colors.orange.shade50,
                      child: ListTile(
                        title: Text('Orden #${order.id} (${order.timestamp})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(order.details),
                        trailing: IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () {
                            setState(() {
                              _kitchenOrders.removeAt(index);
                            });
                            Navigator.pop(context);
                            _showKitchenDialog();
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍔 Burger POS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory),
            tooltip: 'Gestión de Inventario',
            onPressed: _openInventoryView,
          ),
          IconButton(
            icon: const Icon(Icons.soup_kitchen),
            tooltip: 'Ver Cocina',
            onPressed: _showKitchenDialog,
          ),
          IconButton(
            icon: const Icon(Icons.assessment),
            tooltip: 'Reportes y Corte',
            onPressed: _showCorteCajaDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Vaciar Carrito',
            onPressed: _cart.isEmpty
                ? null
                : () {
                    setState(() {
                      _cart.clear();
                    });
                  },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 1000) {
                  return Row(
                    children: [
                      Expanded(flex: 4, child: _buildProductGrid(crossAxisCount: 4)),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 2, child: _buildCartPanel()),
                    ],
                  );
                } else if (constraints.maxWidth > 600) {
                  return Row(
                    children: [
                      Expanded(flex: 3, child: _buildProductGrid(crossAxisCount: 3)),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 2, child: _buildCartPanel()),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Expanded(child: _buildProductGrid(crossAxisCount: 2)),
                      const Divider(height: 1),
                      SizedBox(height: 260, child: _buildCartPanel()),
                    ],
                  );
                }
              },
            ),
    );
  }

  Widget _buildProductGrid({required int crossAxisCount}) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final hasImage = product.imagePath != null && File(product.imagePath!).existsSync();
        final bool isAvailable = product.stock > 0;

        return Opacity(
          opacity: isAvailable ? 1.0 : 0.5,
          child: Card(
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            color: isAvailable ? Colors.white : Colors.grey[300],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: isAvailable ? () => _addToCart(product) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: hasImage
                        ? Image.file(
                            File(product.imagePath!),
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: Colors.orange.shade50,
                            child: Icon(Icons.lunch_dining, size: 40, color: Colors.orange[800]),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Column(
                      children: [
                        Text(
                          product.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            decoration: isAvailable ? TextDecoration.none : TextDecoration.lineThrough,
                            color: isAvailable ? Colors.black87 : Colors.red[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (!isAvailable)
                          const Text(
                            'AGOTADO',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartPanel() {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Orden Actual',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Text('No hay productos seleccionados', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return ListTile(
                        dense: true,
                        title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('\$${item.product.price} c/u'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => _removeFromCart(index),
                            ),
                            Text('${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                              onPressed: () => _addToCart(item.product),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('\$${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _cart.isEmpty ? null : _showCheckoutDialog,
              child: const Text('COBRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryManagementScreen extends StatefulWidget {
  final List<Product> products;
  final Function(Product, int, double) onRestock;
  final Function(String, double, double, String?, int) onAddProduct;
  final Function(Product, String, double, double, String?, int) onUpdateProduct;
  final Function(int) onDeleteProduct;

  final List<Map<String, dynamic>> rawMaterials;
  final Function(String, double, int, String) onAddRawMaterial;
  final Function(Map<String, dynamic>, String, double, int) onUpdateRawMaterial;
  final Function(int) onDeleteRawMaterial;
  final Function(Map<String, dynamic>, int, double) onRestockRawMaterial;

  const InventoryManagementScreen({
    super.key,
    required this.products,
    required this.onRestock,
    required this.onAddProduct,
    required this.onUpdateProduct,
    required this.onDeleteProduct,
    required this.rawMaterials,
    required this.onAddRawMaterial,
    required this.onUpdateRawMaterial,
    required this.onDeleteRawMaterial,
    required this.onRestockRawMaterial,
  });

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _showProductForm(BuildContext context, {Product? productToEdit}) {
    final nameController = TextEditingController(text: productToEdit?.name ?? '');
    final priceController = TextEditingController(text: productToEdit?.price.toString() ?? '');
    final costController = TextEditingController(text: productToEdit?.costPrice.toString() ?? '');
    final stockController = TextEditingController(text: productToEdit?.stock.toString() ?? '50');
    String? selectedImagePath = productToEdit?.imagePath;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(productToEdit == null ? 'Agregar Plato al Menú' : 'Editar Plato del Menú'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre del Plato (Ej. Clásica)')),
                    TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio Público Venta (\$e.g. 95.00)')),
                    TextField(controller: costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Costo Estimado Producción')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: () {
                    final name = nameController.text.trim();
                    final price = double.tryParse(priceController.text) ?? 0.0;
                    final cost = double.tryParse(costController.text) ?? 0.0;
                    final stock = int.tryParse(stockController.text) ?? 50;

                    if (name.isNotEmpty && price > 0) {
                      if (productToEdit == null) {
                        widget.onAddProduct(name, price, cost, selectedImagePath, stock);
                      } else {
                        widget.onUpdateProduct(productToEdit, name, price, cost, selectedImagePath, stock);
                      }
                      Navigator.pop(context);
                      setState(() {});
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRawMaterialForm(BuildContext context, {Map<String, dynamic>? materialToEdit}) {
    final nameController = TextEditingController(text: materialToEdit?['name'] ?? '');
    final costController = TextEditingController(text: materialToEdit?['cost']?.toString() ?? '');
    final stockController = TextEditingController(text: materialToEdit?['stock']?.toString() ?? '100');
    final unitController = TextEditingController(text: materialToEdit?['unit'] ?? 'pzas');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(materialToEdit == null ? 'Nuevo Insumo (Materia Prima)' : 'Editar Insumo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre Insumo (Ej. Pan, Carne, Queso)')),
            TextField(controller: costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Costo de Compra Actual (\$ Unidad)')),
            TextField(controller: stockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cantidad en Stock')),
            TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Unidad de Medida (pzas, kg, litros)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () {
              final name = nameController.text.trim();
              final cost = double.tryParse(costController.text) ?? 0.0;
              final stock = int.tryParse(stockController.text) ?? 0;
              final unit = unitController.text.trim().isEmpty ? 'pzas' : unitController.text.trim();

              if (name.isNotEmpty) {
                if (materialToEdit == null) {
                  widget.onAddRawMaterial(name, cost, stock, unit);
                } else {
                  widget.onUpdateRawMaterial(materialToEdit, name, cost, stock);
                }
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Guardar Insumo'),
          ),
        ],
      ),
    );
  }

  void _showRestockRawMaterialDialog(BuildContext context, Map<String, dynamic> material) {
    final qtyController = TextEditingController();
    final costController = TextEditingController(text: material['cost'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Surtir Insumo: ${material['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cantidad a comprar')),
            TextField(controller: costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Costo unitario nuevo (\$suscita alerta si subió)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              final qty = int.tryParse(qtyController.text) ?? 0;
              final newCost = double.tryParse(costController.text) ?? material['cost'];
              if (qty > 0) {
                widget.onRestockRawMaterial(material, qty, newCost);
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Registrar Compra y Surtir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍔 Administración del Negocio'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book), text: 'Menú Comercial'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Almacén de Insumos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _showProductForm(context),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo Plato'),
            ),
            body: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.products.length,
              itemBuilder: (context, index) {
                final p = widget.products[index];
                return Card(
                  child: ListTile(
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Precio Venta Público: \$${p.price.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Editar Precio o Nombre',
                          onPressed: () => _showProductForm(context, productToEdit: p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Eliminar Plato',
                          onPressed: () {
                            widget.onDeleteProduct(index);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _showRawMaterialForm(context),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_box),
              label: const Text('Nuevo Insumo'),
            ),
            body: widget.rawMaterials.isEmpty
                ? const Center(child: Text('No hay insumos registrados.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: widget.rawMaterials.length,
                    itemBuilder: (context, index) {
                      final m = widget.rawMaterials[index];
                      return Card(
                        child: ListTile(
                          title: Text(m['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Costo actual: \$${(m['cost'] as num).toStringAsFixed(2)} | Stock: ${m['stock']} ${m['unit']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.local_shipping, color: Colors.orange),
                                tooltip: 'Surtir Insumo (Revisión de Alza)',
                                onPressed: () => _showRestockRawMaterialDialog(context, m),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Editar Insumo',
                                onPressed: () => _showRawMaterialForm(context, materialToEdit: m),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Eliminar',
                                onPressed: () {
                                  widget.onDeleteRawMaterial(index);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
