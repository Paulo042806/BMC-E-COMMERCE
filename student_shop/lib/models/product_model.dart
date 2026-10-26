
class ProductModel {
  final String id;
  final String name;
  final String brand;
  final String? description;
  final int price;
  final String? imageUrl;

  ProductModel({
    required this.id,
    required this.name,
    required this.brand,
    this.description,
    required this.price,
    this.imageUrl,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unnamed Product',
      brand: map['brand']?.toString() ?? 'Unknown',
      description: map['description']?.toString(),
      price: (map['price'] as num?)?.toInt() ?? 0,
      imageUrl: map['image_url']?.toString(),
    );
  }
}
