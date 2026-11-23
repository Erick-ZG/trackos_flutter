import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../models/tracking.dart';

class AppService implements TrackingRepository {
  static final AppService _instance = AppService._internal();
  factory AppService() => _instance;
  AppService._internal();

  final http.Client _client = http.Client();
  String? _token;
  User? currentUser;
  List<Product> products = [];
  List<CartItem> cart = [];
  List<Order> orders = [];

  String get _baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) {
      return Uri.base
          .replace(port: 3000, path: '', query: null, fragment: null)
          .origin;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  int get cartItemCount => cart.fold(0, (sum, item) => sum + item.quantity);
  double get cartTotal => cart.fold(0.0, (sum, item) => sum + item.subtotal);

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    bool authenticated = false,
  }) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'));
    request.headers['Content-Type'] = 'application/json';
    if (authenticated && _token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    if (body != null) request.body = jsonEncode(body);
    final response = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 12));
    final decoded = response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (decoded is Map ? decoded['error'] : null) ?? 'Error del servidor',
      );
    }
    return decoded;
  }

  Future<bool> login(String email, String password) async {
    final data = await _request(
      'POST',
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    _acceptSession(data);
    try {
      await refreshStore();
    } catch (_) {
      _token = null;
      currentUser = null;
      rethrow;
    }
    return true;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
    String address = '',
  }) async {
    final data = await _request(
      'POST',
      '/api/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'address': address,
      },
    );
    _acceptSession(data);
    try {
      await refreshStore();
    } catch (_) {
      _token = null;
      currentUser = null;
      rethrow;
    }
    return true;
  }

  void _acceptSession(Map<String, dynamic> data) {
    _token = data['token'] as String;
    final u = Map<String, dynamic>.from(data['user'] as Map);
    currentUser = User(
      id: '${u['user_id'] ?? u['id']}',
      name: '${u['name']}',
      email: '${u['email']}',
      password: '',
      phone: '${u['phone'] ?? ''}',
      address: '${u['address'] ?? ''}',
    );
  }

  Future<void> refreshStore() async {
    final results = await Future.wait([
      _request('GET', '/api/products'),
      _request('GET', '/api/cart', authenticated: true),
      _request('GET', '/api/orders', authenticated: true),
    ]);
    products = (results[0] as List)
        .map((e) => _product(Map<String, dynamic>.from(e)))
        .toList();
    cart = (results[1] as List)
        .map((e) => _cartItem(Map<String, dynamic>.from(e)))
        .toList();
    orders = (results[2] as List)
        .map((e) => _order(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addToCart(Product product, {int quantity = 1}) async {
    await _request(
      'POST',
      '/api/cart/add',
      body: {'productId': product.id, 'quantity': quantity},
      authenticated: true,
    );
    await _loadCart();
  }

  Future<void> updateCartItem(String productId, int quantity) async {
    await _request(
      'PUT',
      '/api/cart/item/$productId',
      body: {'quantity': quantity},
      authenticated: true,
    );
    await _loadCart();
  }

  Future<void> removeFromCart(String productId) async {
    await _request('DELETE', '/api/cart/item/$productId', authenticated: true);
    await _loadCart();
  }

  Future<void> clearCart() async {
    await _request('DELETE', '/api/cart', authenticated: true);
    cart.clear();
  }

  Future<void> _loadCart() async {
    final data =
        await _request('GET', '/api/cart', authenticated: true) as List;
    cart = data.map((e) => _cartItem(Map<String, dynamic>.from(e))).toList();
  }

  Future<Order> placeOrder() async {
    final data = await _request(
      'POST',
      '/api/orders',
      authenticated: true,
    ) as Map<String, dynamic>;
    final order = _order(Map<String, dynamic>.from(data));
    cart.clear();
    orders.insert(0, order);
    // Reconcile the local snapshot with the backend before switching to Orders.
    try {
      await refreshStore();
    } catch (_) {
      // The just-created order remains visible locally if a follow-up read fails.
    }
    return order;
  }

  TrackingData _acceptTracking(Map<String, dynamic> json) {
    final tracking = TrackingData.fromJson(json);
    for (final order in orders.where((o) => o.id == tracking.orderId)) {
      order.status = _status(tracking.status);
    }
    return tracking;
  }

  @override
  Future<TrackingData> loadTracking(String orderId) async => _acceptTracking(
    Map<String, dynamic>.from(
      await _request(
        'GET',
        '/api/orders/$orderId/tracking',
        authenticated: true,
      ),
    ),
  );

  @override
  Future<TrackingData> advanceSimulation(String orderId, int version) =>
      _mutateSimulation(orderId, version, 'advance');

  @override
  Future<TrackingData> resetSimulation(String orderId, int version) =>
      _mutateSimulation(orderId, version, 'reset');

  Future<TrackingData> _mutateSimulation(
    String orderId,
    int version,
    String action,
  ) async => _acceptTracking(
    Map<String, dynamic>.from(
      await _request(
        'POST',
        '/api/orders/$orderId/simulation/$action',
        body: {'expectedVersion': version},
        authenticated: true,
      ),
    ),
  );

  List<Order> getMyOrders() => orders;

  Future<void> logout() async {
    try {
      await _request('POST', '/api/auth/logout', authenticated: true);
    } finally {
      _token = null;
      currentUser = null;
      products = [];
      cart = [];
      orders = [];
    }
  }

  Product _product(Map<String, dynamic> j) {
    final icon = _icon('${j['icon_name'] ?? ''}');
    // PostgreSQL BIGINT values are serialized by node-postgres as strings.
    final color = Color(
      j['color_value'] == null ? 0xFF607D8B : _number(j['color_value']).toInt(),
    );
    return Product(
      id: '${j['id']}',
      name: '${j['name']}',
      description: '${j['description'] ?? ''}',
      category: '${j['category']}',
      price: _number(j['price']),
      stock: (j['stock'] as num?)?.toInt() ?? 0,
      icon: icon,
      color: color,
    );
  }

  CartItem _cartItem(Map<String, dynamic> j) =>
      CartItem(product: _product(j), quantity: (j['quantity'] as num).toInt());

  Order _order(Map<String, dynamic> j) {
    final items = (j['items'] as List? ?? []).map((raw) {
      final i = Map<String, dynamic>.from(raw);
      final p = products.where((p) => p.id == '${i['product_id']}').firstOrNull;
      final product =
          p ??
          Product(
            id: '${i['product_id'] ?? ''}',
            name: '${i['product_name']}',
            description: '',
            category: '',
            price: _number(i['product_price']),
            stock: 0,
            icon: Icons.inventory_2_outlined,
            color: Colors.blueGrey,
          );
      return CartItem(
        product: product,
        quantity: (i['quantity'] as num).toInt(),
      );
    }).toList();
    return Order(
      id: '${j['id']}',
      items: items,
      status: _status('${j['status']}'),
      createdAt:
          DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
      totalAmount: _number(j['total']),
    );
  }

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  OrderStatus _status(String value) => switch (value) {
    'delivered' => OrderStatus.delivered,
    'out_for_delivery' => OrderStatus.outForDelivery,
    'in_transit' || 'shipped' => OrderStatus.inTransit,
    _ => OrderStatus.pending,
  };

  IconData _icon(String value) => switch (value) {
    'laptop' => Icons.laptop,
    'phone_android' => Icons.phone_android,
    'headphones' => Icons.headphones,
    'watch' => Icons.watch,
    'checkroom' => Icons.checkroom,
    'straighten' => Icons.straighten,
    'eco' => Icons.eco,
    'local_dining' => Icons.local_dining,
    'lightbulb' => Icons.lightbulb,
    'chair' => Icons.chair,
    'keyboard' => Icons.keyboard,
    'monitor' => Icons.monitor,
    'directions_run' => Icons.directions_run,
    'coffee' => Icons.coffee,
    _ => Icons.shopping_bag,
  };
}
