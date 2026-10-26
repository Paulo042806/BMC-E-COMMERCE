import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/payment_service.dart';
import 'xendit_webview_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  /// Display-only summary lines: {name, quantity, price}.
  final List<Map<String, dynamic>> summary;
  final int total;

  const CheckoutScreen({
    super.key,
    required this.items,
    this.summary = const [],
    this.total = 0,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  String _payment = 'gcash';
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  String _peso(num amount) {
    final formatted = amount.toInt().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        );
    return '₱$formatted';
  }

  /// Asks Xendit (through the verify-payment function) whether the
  /// invoice is paid, retrying a few times.
  Future<String> _waitForPayment(String orderId) async {
    final supabase = Supabase.instance.client;

    for (var i = 0; i < 6; i++) {
      try {
        final response = await supabase.functions.invoke(
          'verify-payment',
          body: {'order_id': orderId},
        );

        final data = response.data;
        if (data is Map) {
          final status =
              (data['payment_status'] ?? 'pending').toString().toLowerCase();

          if (status == 'paid' || status == 'failed' || status == 'expired') {
            return status;
          }
        }
      } catch (_) {}

      await Future.delayed(const Duration(seconds: 2));
    }

    return 'pending';
  }

  Future<void> _showResult({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(icon, color: color, size: 48),
        title: Text(title),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('View My Orders'),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final result = await PaymentService.checkout(
        widget.items,
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        notes: '',
        paymentMethod: _payment,
      );

      if (!mounted) return;

      final checkoutUrl = result['checkout_url']?.toString();
      final orderId = result['order_id']?.toString() ?? '';

      // ---------- Cash on delivery ----------
      if (_payment == 'cod') {
        await _showResult(
          icon: Icons.check_circle,
          color: Colors.green,
          title: 'Order Placed!',
          message: 'Your COD order has been saved.\n'
              'Order ID: $orderId\n\n'
              'Please prepare ${_peso(widget.total)} when your order arrives.',
        );

        if (mounted) Navigator.pop(context, 'orders');
        return;
      }

      // ---------- Online payment ----------
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception(
          result['error']?.toString() ?? 'Checkout URL not returned.',
        );
      }

      // Open the Xendit payment link directly.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => XenditWebViewScreen(invoiceUrl: checkoutUrl),
        ),
      );

      if (!mounted) return;

      final status = await _waitForPayment(orderId);

      if (!mounted) return;

      if (status == 'paid') {
        await _showResult(
          icon: Icons.check_circle,
          color: Colors.green,
          title: 'Payment Received',
          message: 'Thank you! We received ${_peso(widget.total)}.\n'
              'Your order is now in My Orders.',
        );
      } else if (status == 'failed' || status == 'expired') {
        await _showResult(
          icon: Icons.error_outline,
          color: Colors.redAccent,
          title: 'Payment Not Completed',
          message: 'Your payment was $status. Your order is saved in '
              'My Orders as unpaid.',
        );
      } else {
        await _showResult(
          icon: Icons.hourglass_top,
          color: Colors.orange,
          title: 'Waiting for Payment',
          message: 'We have not received your payment yet. Your order is '
              'saved in My Orders and will update once the payment is '
              'confirmed.',
        );
      }

      if (mounted) Navigator.pop(context, 'orders');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: lines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'This field is required.';
          }
          return null;
        },
      ),
    );
  }

  Widget _paymentOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Card(
      child: RadioListTile<String>(
        value: value,
        groupValue: _payment,
        onChanged: (value) {
          if (value != null) setState(() => _payment = value);
        },
        secondary: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _summaryCard() {
    if (widget.summary.isEmpty && widget.total == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...widget.summary.map((line) {
              final qty = (line['quantity'] as num?)?.toInt() ?? 0;
              final price = (line['price'] as num?) ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text('${line['name']}  x$qty')),
                    Text(_peso(price * qty)),
                  ],
                ),
              );
            }),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total to Pay',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _peso(widget.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Explains where the money goes for the selected payment method.
  Widget _paymentDetails() {
    if (_payment == 'cod') {
      return Card(
        margin: const EdgeInsets.only(top: 4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payment Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _detailRow('Pay to', 'Delivery rider'),
              _detailRow('Amount', _peso(widget.total)),
              _detailRow('When', 'Upon delivery (cash)'),
            ],
          ),
        ),
      );
    }

    final channel = switch (_payment) {
      'gcash' => 'GCash / e-wallet (as shown on the payment page)',
      'card' => 'Credit or debit card',
      'online_bank' => 'Online banking / bank transfer',
      _ => 'Online payment',
    };

    return Card(
      margin: const EdgeInsets.only(top: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _detailRow('Pay to', 'Cue Haven (via Xendit secure checkout)'),
            _detailRow('Amount', _peso(widget.total)),
            _detailRow('Channel', channel),
            const SizedBox(height: 8),
            const Text(
              '1. Tap Place Order & Pay.\n'
              '2. The Xendit page opens with the exact account / '
              'reference number to send your payment to.\n'
              '3. Complete the payment, then tap Done paying.\n'
              '4. Once confirmed, your order appears in My Orders as PAID.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summaryCard(),
            const Text(
              'Delivery Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _field(_name, 'Full Name'),
            _field(
              _phone,
              'Contact Number',
              keyboardType: TextInputType.phone,
            ),
            _field(_address, 'Complete Delivery Address', lines: 3),
            const SizedBox(height: 8),
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            _paymentOption(
              'gcash',
              'GCash / E-wallet',
              'Pay online through the available Xendit options',
              Icons.phone_android,
            ),
            _paymentOption(
              'card',
              'Credit / Debit Card',
              'Subject to available Xendit payment channels',
              Icons.credit_card,
            ),
            _paymentOption(
              'online_bank',
              'Online Banking',
              'Subject to available Xendit payment channels',
              Icons.account_balance,
            ),
            _paymentOption(
              'cod',
              'Cash on Delivery',
              'Pay when your order arrives',
              Icons.payments,
            ),
            _paymentDetails(),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _placeOrder,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text(
                        _payment == 'cod'
                            ? 'Place Order'
                            : 'Place Order & Pay ${_peso(widget.total)}',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}