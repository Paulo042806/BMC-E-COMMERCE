import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'xendit_webview_screen.dart';

const Color _gold = Color(0xFFF3B943);
const Color _dark = Color(0xFF090B0D);
const Color _panel = Color(0xFF171B1E);

/// Shown right after an online order is created. Displays the payment
/// link and amount, lets the customer pay, copy the link, or pay later,
/// and tracks the payment status of the order.
class PaymentLinkScreen extends StatefulWidget {
  final String orderId;
  final String checkoutUrl;
  final int total;
  final String paymentMethod;

  const PaymentLinkScreen({
    super.key,
    required this.orderId,
    required this.checkoutUrl,
    required this.total,
    required this.paymentMethod,
  });

  @override
  State<PaymentLinkScreen> createState() => _PaymentLinkScreenState();
}

class _PaymentLinkScreenState extends State<PaymentLinkScreen> {
  final _supabase = Supabase.instance.client;

  String _status = 'pending';
  bool _checking = false;

  String get _shortId => widget.orderId.length > 8
      ? widget.orderId.substring(0, 8)
      : widget.orderId;

  String get _methodLabel => switch (widget.paymentMethod) {
        'gcash' => 'GCash / E-wallet',
        'card' => 'Credit / Debit Card',
        'online_bank' => 'Online Banking',
        _ => 'Online Payment',
      };

  String _peso(num amount) {
    final formatted = amount.toInt().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        );
    return '₱$formatted';
  }

  Future<void> _openPayment() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => XenditWebViewScreen(invoiceUrl: widget.checkoutUrl),
      ),
    );

    if (!mounted) return;
    await _checkStatus(attempts: 6);
  }

  /// Reads payment_status. The Xendit webhook can take a few seconds,
  /// so [attempts] > 1 retries every 2 seconds until it changes.
  Future<void> _checkStatus({int attempts = 1}) async {
    if (_checking) return;
    setState(() => _checking = true);

    var status = _status;

    for (var i = 0; i < attempts; i++) {
      try {
        final row = await _supabase
            .from('orders')
            .select('payment_status')
            .eq('id', widget.orderId)
            .maybeSingle();

        status =
            (row?['payment_status'] ?? 'pending').toString().toLowerCase();

        if (status == 'paid' || status == 'failed' || status == 'expired') {
          break;
        }
      } catch (_) {}

      if (i < attempts - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });

    if (attempts == 1 && status == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment not confirmed yet. Please try again shortly.'),
        ),
      );
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.checkoutUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment link copied')),
    );
  }

  void _finish() => Navigator.pop(context, 'orders');

  ({Color color, IconData icon, String title, String message}) get _banner {
    switch (_status) {
      case 'paid':
        return (
          color: Colors.greenAccent,
          icon: Icons.check_circle,
          title: 'Payment Received',
          message: 'Thank you! Your order is now in My Orders.',
        );
      case 'failed':
        return (
          color: Colors.redAccent,
          icon: Icons.error_outline,
          title: 'Payment Failed',
          message: 'Your payment did not go through. You can try the link '
              'again or contact us.',
        );
      case 'expired':
        return (
          color: Colors.redAccent,
          icon: Icons.timer_off,
          title: 'Payment Link Expired',
          message: 'This payment link is no longer valid. Your order is '
              'saved as unpaid in My Orders.',
        );
      default:
        return (
          color: Colors.orangeAccent,
          icon: Icons.hourglass_top,
          title: 'Waiting for Payment',
          message: 'Your order is saved. Complete the payment using the '
              'link below.',
        );
    }
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white60)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: highlight ? _gold : Colors.white,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                fontSize: highlight ? 18 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    final done = _status == 'paid';
    final closed = _status == 'failed' || _status == 'expired';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: _dark,
        appBar: AppBar(
          backgroundColor: _dark,
          foregroundColor: _gold,
          title: const Text(
            'Payment',
            style: TextStyle(color: _gold, fontWeight: FontWeight.bold),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: banner.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: banner.color.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(banner.icon, color: banner.color, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          banner.title,
                          style: TextStyle(
                            color: banner.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          banner.message,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: _panel,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PAYMENT DETAILS',
                      style: TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _row('Order', '#$_shortId'),
                    _row('Pay to', 'Cue Haven (via Xendit)'),
                    _row('Method', _methodLabel),
                    _row('Amount to pay', _peso(widget.total), highlight: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Card(
              color: _panel,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PAYMENT LINK',
                      style: TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        widget.checkoutUrl,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _copyLink,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _gold,
                        side: const BorderSide(color: _gold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This link opens the secure Xendit page, which shows '
                      'the exact account or reference number to send your '
                      'payment to. Do not share it with anyone else.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!done && !closed)
              FilledButton.icon(
                onPressed: _checking ? null : _openPayment,
                icon: const Icon(Icons.lock_outline),
                label: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Pay Now ${_peso(widget.total)}'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                ),
              ),
            if (!done && !closed) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _checking ? null : () => _checkStatus(),
                icon: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    _checking ? 'Checking...' : "I've Paid - Check Status",
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (done || closed)
              FilledButton(
                onPressed: _finish,
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('View My Orders'),
                ),
              )
            else
              TextButton(
                onPressed: _finish,
                child: const Text(
                  'Pay Later - View My Orders',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }
}