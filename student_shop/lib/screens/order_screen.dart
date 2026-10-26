
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const Color gold = Color(0xFFF3B943);
  static const Color background = Color(0xFF101010);
  static const Color panel = Color(0xFF171B1E);

  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  String? error;
  String? cancellingOrderId;

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Please log in to view your orders.');
      }

      final response = await _supabase
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
        orders = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (e) {
      debugPrint('Load orders error: $e');

      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  String peso(dynamic amount) {
    final value = (num.tryParse(amount.toString()) ?? 0).toDouble();

    return '₱${value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    )}';
  }

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Order Pending';
      case 'processing':
        return 'Preparing Order';
      case 'shipped':
        return 'On the Way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'shipped':
        return Colors.blue;
      case 'processing':
        return Colors.orange;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return gold;
    }
  }

  String formatDate(dynamic value) {
    if (value == null) return 'Date unavailable';

    final date = DateTime.tryParse(value.toString())?.toLocal();

    if (date == null) return 'Date unavailable';

    return '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> cancelOrder(Map<String, dynamic> order) async {
    final status =
        (order['order_status'] ?? 'pending').toString().toLowerCase();

    if (status != 'pending' && status != 'processing') {
      return;
    }

    final orderId = order['id'].toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: const Text(
          'Cancel Order?',
          style: TextStyle(
            color: gold,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to cancel this order? '
          'This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      cancellingOrderId = orderId;
    });

    try {
      final result = await _supabase.rpc(
        'cancel_my_order',
        params: {'p_order_id': orderId},
      );

      if (!mounted) return;

      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully.'),
            backgroundColor: Colors.green,
          ),
        );

        await loadOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This order can no longer be cancelled.',
            ),
          ),
        );

        await loadOrders();
      }
    } catch (e) {
      debugPrint('Cancel order error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to cancel order. Please try again.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          cancellingOrderId = null;
        });
      }
    }
  }

  Widget buildOrder(Map<String, dynamic> order) {
    final status =
        (order['order_status'] ?? 'pending').toString();
    final normalizedStatus = status.toLowerCase();

    final paymentStatus =
        (order['payment_status'] ?? 'pending').toString();

    final rawItems = order['order_items'];
    final items = rawItems is List ? rawItems : <dynamic>[];

    final orderId = order['id']?.toString() ?? '';

    final shortId = orderId.length > 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();

    final canCancel =
        normalizedStatus == 'pending' ||
        normalizedStatus == 'processing';

    final isCancelling = cancellingOrderId == orderId;
    final color = statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF343A36)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    'ORDER #$shortId',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  Icons.circle,
                  size: 10,
                  color: color,
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Ordered: ${formatDate(order['created_at'])}',
              style: const TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusLabel(status),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    normalizedStatus == 'shipped'
                        ? 'Your order is on its way.'
                        : normalizedStatus == 'delivered'
                            ? 'Your order has been delivered.'
                            : normalizedStatus == 'processing'
                                ? 'Your order is being prepared.'
                                : normalizedStatus == 'cancelled'
                                    ? 'This order was cancelled.'
                                    : 'We are waiting for your order to be processed.',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'ORDER ITEMS',
              style: TextStyle(
                color: gold,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            if (items.isEmpty)
              const Text(
                'No item details available.',
                style: TextStyle(color: Colors.white70),
              )
            else
              ...items.map((rawItem) {
                final item = Map<String, dynamic>.from(
                  rawItem as Map,
                );

                final rawProduct = item['products'];

                final product = rawProduct is Map
                    ? Map<String, dynamic>.from(rawProduct)
                    : <String, dynamic>{};

                final name =
                    product['name']?.toString() ?? 'Cue Stick';

                final brand =
                    product['brand']?.toString() ?? '';

                final quantity =
                    (item['quantity'] as num?)?.toInt() ?? 0;

                final unitPrice =
                    (num.tryParse(
                      (item['unit_price'] ?? 0).toString(),
                    ) ?? 0).toDouble();

                final itemTotal = unitPrice * quantity;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.sports,
                          color: gold,
                          size: 26,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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
                              'Qty: $quantity × ${peso(unitPrice)}',
                              style: const TextStyle(
                                color: Colors.white70,
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

            const Divider(height: 24),

            _detail(
              'Payment Method',
              (order['payment_method'] ?? 'N/A')
                  .toString()
                  .toUpperCase(),
            ),

            const SizedBox(height: 5),

            _detail(
              'Payment Status',
              paymentStatus.toUpperCase(),
            ),

            const SizedBox(height: 12),

            const Text(
              'DELIVERY ADDRESS',
              style: TextStyle(
                color: gold,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              (order['delivery_address'] ?? 'Not available').toString(),
              style: const TextStyle(color: Colors.white70),
            ),

            const Divider(height: 24),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'TOTAL',
                    style: TextStyle(
                      color: gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  peso(order['total_amount'] ?? 0),
                  style: const TextStyle(
                    color: gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),

            if (canCancel) ...[
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isCancelling
                      ? null
                      : () => cancelOrder(order),
                  icon: isCancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.redAccent,
                          ),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: Text(
                    isCancelling
                        ? 'Cancelling...'
                        : 'Cancel Order',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(
                      color: Colors.redAccent,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
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
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : loadOrders,
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
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: loadOrders,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            size: 64,
                            color: gold,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No orders yet.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your purchases will appear here.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Shop Now'),
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
                        itemBuilder: (context, index) =>
                            buildOrder(orders[index]),
                      ),
                    ),
    );
  }
}
