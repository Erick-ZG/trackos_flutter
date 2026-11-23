import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/app_service.dart';
import '../widgets/product_card.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  void _increase() {
    if (_quantity < widget.product.stock) {
      setState(() => _quantity++);
    }
  }

  void _decrease() {
    if (_quantity > 1) setState(() => _quantity--);
  }

  Future<void> _addToCart() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppService().addToCart(widget.product, quantity: _quantity);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${_quantity}x ${widget.product.name} agregado al carrito',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final colorScheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 800;

    final imageBox = ClipRRect(
      borderRadius: isWide ? BorderRadius.circular(20) : BorderRadius.zero,
      child: AspectRatio(
        aspectRatio: isWide ? 4 / 3 : 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProductImage(product: product, fallbackIconSize: 96),
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A676),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Envío gratis en Trujillo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final details = Padding(
      padding: EdgeInsets.all(isWide ? 8 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  product.category,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                product.stock > 0 ? '${product.stock} disponibles' : 'Sin stock',
                style: TextStyle(
                  color: product.stock > 0
                      ? const Color(0xFF059669)
                      : Colors.red,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            product.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${product.price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Descripción',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            product.description,
            style: TextStyle(color: Colors.grey[700], height: 1.55),
          ),
          const SizedBox(height: 24),
          if (product.stock > 0) ...[
            Row(
              children: [
                const Text(
                  'Cantidad',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const Spacer(),
                IconButton.outlined(
                  onPressed: _quantity > 1 ? _decrease : null,
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.outlined(
                  onPressed: _quantity < product.stock ? _increase : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _addToCart,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  'Agregar · \$${(product.price * _quantity).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(product.name, overflow: TextOverflow.ellipsis)),
      body: SingleChildScrollView(
        child: isWide
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1020),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: imageBox),
                            const SizedBox(width: 28),
                            Expanded(flex: 5, child: details),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [imageBox, details],
              ),
      ),
    );
  }
}
