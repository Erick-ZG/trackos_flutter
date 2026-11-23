import 'package:flutter/material.dart';

import '../services/app_service.dart';
import 'admin_dashboard_screen.dart';
import 'cart_screen.dart';
import 'courier_dashboard_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'profile_screen.dart';
import 'worker_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _ordersRevision = 0;

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _openCart() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CartScreen(
          onOrderPlaced: () => setState(() {
            _currentIndex = 1;
            _ordersRevision++;
          }),
        ),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final service = AppService();
    final cartCount = service.cartItemCount;
    final user = service.currentUser;
    final role = user?.role ?? 'customer';
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 768;
    final isDesktop = width >= 1120;

    final String topSubtitle;
    final String topLabel;
    if (role == 'worker') {
      topLabel = 'Trabajador de sede';
      topSubtitle = user?.branchName ?? 'Sede asignada';
    } else if (role == 'courier') {
      topLabel = 'Repartidor';
      topSubtitle = user?.name ?? 'En línea';
    } else if (role == 'admin') {
      topLabel = 'Panel';
      topSubtitle = 'Administrador';
    } else {
      topLabel = 'Enviar a';
      topSubtitle = (user?.address.trim().isNotEmpty ?? false)
          ? user!.address
          : 'Trujillo, Perú';
    }

    late final List<Widget> pages;
    late final List<NavigationDestination> bottomDestinations;
    late final List<NavigationRailDestination> railDestinations;

    if (role == 'worker') {
      pages = const [WorkerDashboardScreen(), ProfileScreen()];
      bottomDestinations = const [
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Pedidos Sede',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ];
      railDestinations = const [
        NavigationRailDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: Text('Pedidos Sede'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Mi Perfil'),
        ),
      ];
    } else if (role == 'courier') {
      pages = const [CourierDashboardScreen(), ProfileScreen()];
      bottomDestinations = const [
        NavigationDestination(
          icon: Icon(Icons.delivery_dining_outlined),
          selectedIcon: Icon(Icons.delivery_dining),
          label: 'Entregas',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ];
      railDestinations = const [
        NavigationRailDestination(
          icon: Icon(Icons.delivery_dining_outlined),
          selectedIcon: Icon(Icons.delivery_dining),
          label: Text('Entregas'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Mi Perfil'),
        ),
      ];
    } else if (role == 'admin') {
      pages = [
        const AdminDashboardScreen(),
        ProductsScreen(onCartChanged: _refresh, onOpenCart: _openCart),
        const ProfileScreen(),
      ];
      bottomDestinations = const [
        NavigationDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics),
          label: 'Admin',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: 'Catálogo',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ];
      railDestinations = const [
        NavigationRailDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics),
          label: Text('Panel Admin'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: Text('Catálogo'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Mi Perfil'),
        ),
      ];
    } else {
      pages = [
        ProductsScreen(onCartChanged: _refresh, onOpenCart: _openCart),
        OrdersScreen(key: ValueKey(_ordersRevision)),
        const ProfileScreen(),
      ];
      bottomDestinations = const [
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: 'Explorar',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Mis Pedidos',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ];
      railDestinations = const [
        NavigationRailDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: Text('Explorar'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: Text('Mis Pedidos'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Mi Perfil'),
        ),
      ];
    }

    final safeIndex = _currentIndex.clamp(0, pages.length - 1);
    final body = IndexedStack(index: safeIndex, children: pages);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isWide ? 66 : 60,
        titleSpacing: isWide ? 24 : 12,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delivery_dining, color: Colors.white, size: 22),
                  SizedBox(width: 6),
                  Text(
                    'Trackos',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 24,
              width: 1,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    topLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.1,
                    ),
                  ),
                  Text(
                    topSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isWide)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                onPressed: () =>
                    setState(() => _currentIndex = pages.length - 1),
                icon: const Icon(Icons.person_outline, size: 18),
                label: Text(
                  user?.name.split(' ').first ?? 'Mi Perfil',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (role == 'customer')
            Padding(
              padding: EdgeInsets.only(right: isWide ? 20 : 8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: 'Carrito',
                    onPressed: _openCart,
                    icon: const Icon(Icons.shopping_cart_outlined),
                  ),
                  if (cartCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 19,
                          minHeight: 19,
                        ),
                        child: Text(
                          cartCount > 99 ? '99+' : '$cartCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  extended: isDesktop,
                  selectedIndex: safeIndex,
                  backgroundColor: Colors.white,
                  indicatorColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  onDestinationSelected: (i) =>
                      setState(() => _currentIndex = i),
                  destinations: railDestinations,
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: safeIndex,
              backgroundColor: Colors.white,
              elevation: 3,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              destinations: bottomDestinations,
            ),
    );
  }
}
