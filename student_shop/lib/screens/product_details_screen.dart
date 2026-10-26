
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';

class ProductDetailsScreen extends StatefulWidget {
  final ProductModel product;
  final VoidCallback onAddToCart;

  const ProductDetailsScreen({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState
    extends State<ProductDetailsScreen> {
  static const gold = Color(0xFFF3B943);
  static const dark = Color(0xFF090B0D);
  static const panel = Color(0xFF171B1E);

  final supabase = Supabase.instance.client;

  bool loadingReviews = true;
  double averageRating = 0;
  int reviewCount = 0;
  List<Map<String, dynamic>> reviews = [];

  String peso(int amount) {
    final value = amount.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '₱$value';
  }

  @override
  void initState() {
    super.initState();
    loadReviews();
  }

  Future<void> loadReviews() async {
    try {
      final result = await supabase
          .from('product_reviews')
          .select('rating, review_text, created_at')
          .eq('product_id', widget.product.id)
          .order('created_at', ascending: false);

      final rows = List<Map<String, dynamic>>.from(result);
      final ratings = rows
          .map((row) => (row['rating'] as num?)?.toDouble() ?? 0)
          .toList();

      if (!mounted) return;

      setState(() {
        reviews = rows;
        reviewCount = rows.length;
        averageRating = ratings.isEmpty
            ? 0
            : ratings.reduce((a, b) => a + b) / ratings.length;
        loadingReviews = false;
      });
    } catch (e) {
      debugPrint('Review loading error: $e');
      if (!mounted) return;
      setState(() => loadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: dark,
      appBar: AppBar(
        backgroundColor: dark,
        title: const Text(
          'Product Details',
          style: TextStyle(color: gold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(18),
            ),
            child: product.imageUrl != null &&
                    product.imageUrl!.isNotEmpty
                ? Image.network(
                    product.imageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(
                      Icons.sports_baseball,
                      color: gold,
                      size: 100,
                    ),
                  )
                : const Icon(
                    Icons.sports_baseball,
                    color: gold,
                    size: 100,
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            product.brand.toUpperCase(),
            style: const TextStyle(
              color: gold,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            peso(product.price),
            style: const TextStyle(
              color: gold,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Description',
            style: TextStyle(
              color: gold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (product.description?.trim().isNotEmpty ?? false)
                ? product.description!
                : 'No description available for this product.',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.black,
              ),
              onPressed: widget.onAddToCart,
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text(
                'ADD TO CART',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Customer Reviews',
            style: TextStyle(
              color: gold,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (loadingReviews)
            const Center(
              child: CircularProgressIndicator(color: gold),
            )
          else ...[
            Row(
              children: [
                const Icon(Icons.star, color: gold, size: 28),
                const SizedBox(width: 8),
                Text(
                  reviewCount == 0
                      ? 'No ratings yet'
                      : '${averageRating.toStringAsFixed(1)} / 5  ($reviewCount reviews)',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (reviews.isEmpty)
              const Text(
                'Be the first to review this product after a completed purchase.',
                style: TextStyle(color: Colors.white60),
              ),
            ...reviews.map((review) {
              final rating =
                  (review['rating'] as num?)?.toInt() ?? 0;
              final text = review['review_text']?.toString() ?? '';

              return Card(
                color: panel,
                child: ListTile(
                  leading: const Icon(Icons.star, color: gold),
                  title: Text('$rating out of 5 stars'),
                  subtitle: Text(
                    text.isEmpty ? 'No written comment.' : text,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
