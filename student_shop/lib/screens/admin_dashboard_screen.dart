
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const adminGold = Color(0xFFF3B943);
const adminDark = Color(0xFF090B0D);
const adminPanel = Color(0xFF171B1E);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final supabase = Supabase.instance.client;

  int selectedTab = 0;
  bool loading = true;
  String? error;

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final results = await Future.wait([
        supabase.from('products').select().order('name'),
        supabase
            .from('orders')
            .select('''
              id,
              user_id,
              created_at,
              total_amount,
              payment_method,
              payment_status,
              order_status,
              delivery_address,
              order_items(
                quantity,
                unit_price,
                products(name, brand)
              )
            ''')
            .order('created_at', ascending: false),
      ]);

      if (!mounted) return;

      setState(() {
        products = List<Map<String, dynamic>>.from(results[0]);
        orders = List<Map<String, dynamic>>.from(results[1]);
        loading = false;
      });
    } catch (e) {
      debugPrint('Admin load error: $e');

      if (!mounted) return;

      setState(() {
        loading = false;
        error = 'Unable to load admin data. Check Supabase permissions.';
      });
    }
  }

  String peso(dynamic value) {
    final amount = (num.tryParse(value.toString()) ?? 0).toDouble();
    return '₱${amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    )}';
  }

  String shortDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Date unavailable';
    return '${date.day}/${date.month}/${date.year}';
  }

  int get activeProducts => products.where((p) => p['active'] == true).length;

  int get pendingOrders => orders.where((o) {
    final s = (o['order_status'] ?? '').toString().toLowerCase();
    return s == 'pending' || s == 'processing';
  }).length;

  double get paidSales => orders.fold<double>(0, (sum, order) {
    final paymentStatus =
        (order['payment_status'] ?? '').toString().toLowerCase();
    final orderStatus =
        (order['order_status'] ?? '').toString().toLowerCase();

    if (paymentStatus == 'paid' && orderStatus != 'cancelled') {
      return sum +
          ((num.tryParse(
                    (order['total_amount'] ?? 0).toString(),
                  ) ??
                  0)
              .toDouble());
    }
    return sum;
  });

  Future<void> editProduct([Map<String, dynamic>? product]) async {
    final nameController =
        TextEditingController(text: product?['name']?.toString() ?? '');
    final brandController =
        TextEditingController(text: product?['brand']?.toString() ?? '');
    final priceController = TextEditingController(
      text: product?['price']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: product?['description']?.toString() ?? '',
    );
    final imageController = TextEditingController(
      text: product?['image_url']?.toString() ?? '',
    );

    final formKey = GlobalKey<FormState>();

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: adminPanel,
        title: Text(
          product == null ? 'Add Product' : 'Edit Product',
          style: const TextStyle(color: adminGold),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(nameController, 'Product name'),
                  _field(brandController, 'Brand'),
                  _field(
                    priceController,
                    'Price',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final price = int.tryParse(value?.trim() ?? '');
                      if (price == null || price < 0) {
                        return 'Enter a valid whole-number price';
                      }
                      return null;
                    },
                  ),
                  _field(descriptionController, 'Description'),
                  _field(imageController, 'Image URL'),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate() &&
                  nameController.text.trim().isNotEmpty &&
                  brandController.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save != true || !mounted) return;

    final data = <String, dynamic>{
      'name': nameController.text.trim(),
      'brand': brandController.text.trim(),
      'price': int.parse(priceController.text.trim()),
      'description': descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      'image_url': imageController.text.trim().isEmpty
          ? null
          : imageController.text.trim(),
      'active': product?['active'] ?? true,
    };

    try {
      if (product == null) {
        await supabase.from('products').insert(data);
      } else {
        await supabase
            .from('products')
            .update(data)
            .eq('id', product['id']);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product saved successfully.')),
      );
      await loadData();
    } catch (e) {
      debugPrint('Save product error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save product. Check database permissions.'),
        ),
      );
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator ??
            (value) => value == null || value.trim().isEmpty
                ? '$label is required'
                : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> toggleProduct(Map<String, dynamic> product) async {
    final active = product['active'] == true;

    try {
      await supabase
          .from('products')
          .update({'active': !active})
          .eq('id', product['id']);

      await loadData();
    } catch (e) {
      debugPrint('Update product status error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update product status.')),
      );
    }
  }

  Future<void> updateOrderStatus(
    Map<String, dynamic> order,
    String status,
  ) async {
    final current = (order['order_status'] ?? '').toString().toLowerCase();

    if (current == 'cancelled' || current == 'delivered') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancelled or delivered orders are locked here.'),
        ),
      );
      return;
    }

    try {
      await supabase
          .from('orders')
          .update({'order_status': status})
          .eq('id', order['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order status updated.')),
      );
      await loadData();
    } catch (e) {
      debugPrint('Update order error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update order status. Check permissions.'),
        ),
      );
    }
  }

  Widget statCard(String title, String value, IconData icon) {
    return Card(
      color: adminPanel,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: adminGold, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget dashboardTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'STORE OVERVIEW',
          style: TextStyle(
            color: adminGold,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.25,
          children: [
            statCard('Total Orders', '${orders.length}', Icons.receipt_long),
            statCard('Active Products', '$activeProducts', Icons.sports),
            statCard('Pending / Processing', '$pendingOrders', Icons.pending_actions),
            statCard('Paid Sales', peso(paidSales), Icons.payments),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'RECENT ORDERS',
          style: TextStyle(
            color: adminGold,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          const Text('No orders yet.', style: TextStyle(color: Colors.white70))
        else
          ...orders.take(5).map((order) {
            final id = order['id']?.toString() ?? '';
            final shortId = id.length > 8 ? id.substring(0, 8) : id;
            return Card(
              color: adminPanel,
              child: ListTile(
                leading: const Icon(Icons.receipt, color: adminGold),
                title: Text('Order #${shortId.toUpperCase()}'),
                subtitle: Text(
                  '${shortDate(order['created_at'])} • '
                  '${order['order_status'] ?? 'pending'}',
                ),
                trailing: Text(
                  peso(order['total_amount']),
                  style: const TextStyle(
                    color: adminGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget productsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => editProduct(),
              icon: const Icon(Icons.add),
              label: const Text('ADD NEW PRODUCT'),
            ),
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const Center(child: Text('No products found.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final active = product['active'] == true;
                    return Card(
                      color: adminPanel,
                      child: ListTile(
                        leading: const Icon(
                          Icons.sports,
                          color: adminGold,
                          size: 32,
                        ),
                        title: Text(product['name']?.toString() ?? 'Unnamed'),
                        subtitle: Text(
                          '${product['brand'] ?? 'Unknown'} • '
                          '${peso(product['price'])}\n'
                          '${active ? 'Active' : 'Inactive'}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') editProduct(product);
                            if (value == 'toggle') toggleProduct(product);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit product'),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(active ? 'Deactivate' : 'Activate'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget ordersTab() {
    if (orders.isEmpty) {
      return const Center(child: Text('No orders found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final id = order['id']?.toString() ?? '';
        final shortId = id.length > 8 ? id.substring(0, 8) : id;
        final status = (order['order_status'] ?? 'pending')
            .toString()
            .toLowerCase();
        final rawItems = order['order_items'];
        final items = rawItems is List ? rawItems : <dynamic>[];

        return Card(
          color: adminPanel,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ORDER #${shortId.toUpperCase()}',
                  style: const TextStyle(
                    color: adminGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Customer UID: ${order['user_id'] ?? 'N/A'}'),
                Text('Date: ${shortDate(order['created_at'])}'),
                Text('Total: ${peso(order['total_amount'])}'),
                Text('Payment: ${order['payment_method'] ?? 'N/A'}'),
                Text('Payment status: ${order['payment_status'] ?? 'N/A'}'),
                const SizedBox(height: 10),
                const Text(
                  'ITEMS',
                  style: TextStyle(
                    color: adminGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...items.map((rawItem) {
                  final item = Map<String, dynamic>.from(rawItem as Map);
                  final rawProduct = item['products'];
                  final product = rawProduct is Map
                      ? Map<String, dynamic>.from(rawProduct)
                      : <String, dynamic>{};
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '${product['name'] ?? 'Product'} × '
                      '${item['quantity'] ?? 0} '
                      '(${peso(item['unit_price'] ?? 0)} each)',
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Text(
                  'DELIVERY ADDRESS',
                  style: TextStyle(
                    color: adminGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(order['delivery_address']?.toString() ?? 'N/A'),
                const SizedBox(height: 12),
                if (status == 'cancelled')
                  const Text(
                    'Cancelled',
                    style: TextStyle(color: Colors.redAccent),
                  )
                else if (status == 'delivered')
                  const Text(
                    'Delivered',
                    style: TextStyle(color: Colors.greenAccent),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: const [
                      'pending',
                      'processing',
                      'shipped',
                      'delivered',
                      'cancelled',
                    ].contains(status)
                        ? status
                        : 'pending',
                    decoration: const InputDecoration(
                      labelText: 'Update order status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: 'processing',
                        child: Text('Processing'),
                      ),
                      DropdownMenuItem(
                        value: 'shipped',
                        child: Text('Shipped'),
                      ),
                      DropdownMenuItem(
                        value: 'delivered',
                        child: Text('Delivered'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('Cancelled'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null && value != status) {
                        updateOrderStatus(order, value);
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminDark,
      appBar: AppBar(
        title: const Text(
          'CUE HAVEN ADMIN',
          style: TextStyle(
            color: adminGold,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () async {
              await supabase.auth.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: adminGold),
            )
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: loadData,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : IndexedStack(
                  index: selectedTab,
                  children: [
                    dashboardTab(),
                    productsTab(),
                    ordersTab(),
                  ],
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
        ],
      ),
    );
  }
}
