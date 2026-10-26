
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final supabase = Supabase.instance.client;

  static const gold = Color(0xFFF3B943);
  static const background = Color(0xFF101010);
  static const panel = Color(0xFF1D1D1D);

  bool loading = true;
  String? error;
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Please log in to view your orders.';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await supabase
          .from('orders')
          .select('''
            id,
            created_at,
            total_amount,
            payment_method,
            payment_status,
            order_status,
            delivery_address,
            order_items(
              product_id,
              quantity,
              unit_price,
              products(name, brand)
            )
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        orders = List<Map<String, dynamic>>.from(result);
        loading = false;
      });
    } catch (e) {
      debugPrint('Load orders error: $e');

      if (!mounted) return;

      setState(() {
        error = 'Unable to load orders. Please try again.';
        loading = false;
      });
    }
  }

  String peso(dynamic amount) {
    final value = (amount as num?)?.toDouble() ?? 0;
    return '₱${value.toStringAsFixed(2)}';
  }

  String statusLabel(dynamic value) {
    switch ((value ?? 'pending').toString().toLowerCase()) {
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped / On the Way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Order Pending';
    }
  }

  IconData statusIcon(dynamic value) {
    switch ((value ?? 'pending').toString().toLowerCase()) {
      case 'processing':
        return Icons.inventory_2_outlined;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.pending_actions;
    }
  }

  Color statusColor(dynamic value) {
    switch ((value ?? 'pending').toString().toLowerCase()) {
      case 'shipped':
      case 'delivered':
        return Colors.greenAccent;
      case 'cancelled':
        return Colors.redAccent;
      case 'processing':
        return gold;
      default:
        return Colors.orangeAccent;
    }
  }

  String formatDate(dynamic value) {
    if (value == null) return 'Date unavailable';

    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return value.toString();

    return '${date.month}/${date.day}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: gold,
        title: const Text(
          'My Orders',
          style: TextStyle(
            color: gold,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loadOrders,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh orders',
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: gold),
            )
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: loadOrders,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : orders.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            color: gold,
                            size: 60,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No orders yet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Your purchased items will appear here.',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: loadOrders,
                      color: gold,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final rawItems = order['order_items'];
                          final items = rawItems is List
                              ? rawItems
                              : <dynamic>[];

                          final status =
                              order['order_status'] ?? 'pending';
                          final color = statusColor(status);
                          final id = order['id'].toString();

                          return Card(
                            color: panel,
                            margin: const EdgeInsets.only(bottom: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: gold.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.receipt_long,
                                        color: gold,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Order #${id.length > 8 ? id.substring(0, 8) : id}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    formatDate(order['created_at']),
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Divider(height: 28),
                                  const Text(
                                    'ORDER ITEMS',
                                    style: TextStyle(
                                      color: gold,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  if (items.isEmpty)
                                    const Text(
                                      'No item details available.',
                                      style: TextStyle(
                                        color: Colors.white60,
                                      ),
                                    ),

                                  ...items.map((rawItem) {
                                    final item =
                                        Map<String, dynamic>.from(
                                      rawItem as Map,
                                    );

                                    final productRaw = item['products'];
                                    final product = productRaw is Map
                                        ? Map<String, dynamic>.from(
                                            productRaw,
                                          )
                                        : <String, dynamic>{};

                                    final name =
                                        product['name']?.toString() ??
                                            'Cue Stick';
                                    final brand =
                                        product['brand']?.toString() ?? '';

                                    final quantity =
                                        (item['quantity'] as num?)
                                                ?.toInt() ??
                                            0;

                                    final unitPrice =
                                        (item['unit_price'] as num?)
                                                ?.toDouble() ??
                                            0.0;

                                    final itemTotal =
                                        unitPrice * quantity;

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: Colors.black26,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.sports,
                                              color: gold,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                ),
                                                if (brand.isNotEmpty)
                                                  Text(
                                                    brand,
                                                    style: const TextStyle(
                                                      color: Colors.white60,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                Text(
                                                  'Qty: $quantity',
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  '${peso(unitPrice)} each',
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            peso(itemTotal),
                                            style: const TextStyle(
                                              color: gold,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),

                                  const Divider(height: 20),

                                  _detail(
                                    'Total Amount',
                                    peso(order['total_amount']),
                                    highlight: true,
                                  ),
                                  _detail(
                                    'Payment Method',
                                    (order['payment_method'] ?? 'N/A')
                                        .toString()
                                        .toUpperCase(),
                                  ),
                                  _detail(
                                    'Payment Status',
                                    (order['payment_status'] ?? 'pending')
                                        .toString()
                                        .toUpperCase(),
                                  ),

                                  const SizedBox(height: 16),
                                  const Text(
                                    'DELIVERY STATUS',
                                    style: TextStyle(
                                      color: gold,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.10),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          statusIcon(status),
                                          color: color,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            statusLabel(status),
                                            style: TextStyle(
                                              color: color,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 14),
                                  const Text(
                                    'Delivery Address',
                                    style: TextStyle(
                                      color: gold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    (order['delivery_address'] ?? 'N/A')
                                        .toString(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _detail(
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: highlight ? gold : Colors.white,
                fontWeight:
                    highlight ? FontWeight.bold : FontWeight.normal,
                fontSize: highlight ? 16 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
