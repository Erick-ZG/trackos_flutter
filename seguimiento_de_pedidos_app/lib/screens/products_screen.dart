import 'package:flutter/material.dart';
import '../services/app_service.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _selectedCategory = 'Todos';

  List<String> get _categories {
    final cats = AppService()
        .products
        .map((p) => p.category)
        .toSet()
        .toList();
    cats.sort();
    return ['Todos', ...cats];
  }

  List<Product> get _filtered {
    if (_selectedCategory == 'Todos') return AppService().products;
    return AppService()
        .products
        .where((p) => p.category == _selectedCategory)
        .toList();
  }

  Future<void> _addToCart(Product product) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
    await AppService().addToCart(product);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('${product.name} agregado al carrito'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Ver', onPressed: () {}),
      ),
    );
    setState(() {});
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final selected = cat == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.75,
            ),
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final product = _filtered[i];
              return ProductCard(
                product: product,
                onAddToCart: () => _addToCart(product),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ProductDetailScreen(product: product),
                    ),
                  );
                  setState(() {});
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
