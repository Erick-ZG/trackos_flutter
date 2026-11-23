import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/app_service.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
  final VoidCallback? onCartChanged;
  final VoidCallback? onOpenCart;

  const ProductsScreen({
    super.key,
    this.onCartChanged,
    this.onOpenCart,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _featuredCtrl = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _featuredCtrl.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final cats = AppService().products.map((p) => p.category).toSet().toList();
    cats.sort();
    return ['Todos', ...cats];
  }

  List<Product> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    return AppService().products.where((p) {
      final matchesCat =
          _selectedCategory == 'Todos' || p.category == _selectedCategory;
      final matchesQuery =
          q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q);
      return matchesCat && matchesQuery;
    }).toList();
  }

  Future<void> _addToCart(Product product) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppService().addToCart(product);
      if (!mounted) return;
      widget.onCartChanged?.call();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${product.name} agregado al carrito'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: widget.onOpenCart != null
              ? SnackBarAction(label: 'Ver carrito', onPressed: widget.onOpenCart!)
              : null,
        ),
      );
      setState(() {});
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _openDetail(Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
    widget.onCartChanged?.call();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filtered;
    final allProducts = AppService().products;
    final featured = allProducts.take(6).toList();
    final showFeatured =
        _selectedCategory == 'Todos' &&
        _searchQuery.trim().isEmpty &&
        featured.isNotEmpty;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: '¿Qué quieres pedir hoy en Trujillo?',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                                icon: const Icon(Icons.close),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final cat = _categories[i];
                          final selected = cat == _selectedCategory;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: selected,
                            selectedColor: colorScheme.primary,
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF334155),
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: selected
                                  ? colorScheme.primary
                                  : const Color(0xFFE2E8F0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            showCheckmark: false,
                            onSelected: (_) =>
                                setState(() => _selectedCategory = cat),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showFeatured)
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Los más pedidos esta semana',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (MediaQuery.sizeOf(context).width >= 768) ...[
                            IconButton.filledTonal(
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                _featuredCtrl.animateTo(
                                  (_featuredCtrl.offset - 280).clamp(
                                    0.0,
                                    _featuredCtrl.position.maxScrollExtent,
                                  ),
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOut,
                                );
                              },
                              icon: const Icon(Icons.chevron_left),
                            ),
                            const SizedBox(width: 4),
                            IconButton.filledTonal(
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                _featuredCtrl.animateTo(
                                  (_featuredCtrl.offset + 280).clamp(
                                    0.0,
                                    _featuredCtrl.position.maxScrollExtent,
                                  ),
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOut,
                                );
                              },
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 272,
                        child: ListView.separated(
                          controller: _featuredCtrl,
                          scrollDirection: Axis.horizontal,
                          itemCount: featured.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (_, i) {
                            final product = featured[i];
                            return SizedBox(
                              width: 220,
                              child: ProductCard(
                                product: product,
                                onAddToCart: () => _addToCart(product),
                                onTap: () => _openDetail(product),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedCategory == 'Todos'
                          ? 'Descubre todas las opciones'
                          : _selectedCategory,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${filtered.length} productos',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No encontramos productos con ese filtro',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding =
                    (constraints.crossAxisExtent - 1288).clamp(0.0, 9999.0) / 2;
                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 255,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 274,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final product = filtered[i];
                        return ProductCard(
                          product: product,
                          onAddToCart: () => _addToCart(product),
                          onTap: () => _openDetail(product),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
