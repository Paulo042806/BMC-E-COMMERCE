
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  static final SupabaseClient _supabase =
      Supabase.instance.client;

  static Future<Map<String, dynamic>> checkout(
    List<Map<String, dynamic>> items, {
    required String fullName,
    required String phone,
    required String address,
    required String notes,
    required String paymentMethod,
  }) async {
    if (items.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please log in before checking out.');
    }

    final response = await _supabase.functions.invoke(
      'create-xendit-checkout',
      body: {
        'items': items,
        'full_name': fullName,
        'phone': phone,
        'delivery_address': address,
        'delivery_notes': notes,
        'payment_method': paymentMethod,
      },
    );

    final responseData = response.data;

    if (responseData is! Map) {
      throw Exception(
        'Invalid response from checkout server.',
      );
    }

    final data = Map<String, dynamic>.from(responseData);

    if (response.status < 200 || response.status >= 300) {
      throw Exception(
        data['error']?.toString() ?? 'Checkout failed.',
      );
    }

    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }

    // COD does not require a Xendit checkout URL.
    if (paymentMethod == 'cod') {
      if (data['order_id'] == null) {
        throw Exception('The order was not confirmed by the server.');
      }

      return data;
    }

    // Online payments require a checkout URL.
    final checkoutUrl = data['checkout_url']?.toString();

    if (checkoutUrl == null ||
        checkoutUrl.isEmpty ||
        !checkoutUrl.startsWith('https://')) {
      throw Exception(
        'A valid Xendit checkout URL was not returned.',
      );
    }

    return data;
  }

  static Future<List<Map<String, dynamic>>> fetchOrders() async {
    final response = await _supabase
        .from('orders')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
