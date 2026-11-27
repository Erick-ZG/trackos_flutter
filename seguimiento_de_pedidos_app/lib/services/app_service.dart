import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/order_contact.dart';
import '../models/product.dart';
import '../models/tracking.dart';
import '../models/user.dart';
import '../utils/phone_utils.dart';

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

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  final StreamController<Map<String, dynamic>> _realtimeCtrl =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get realtimeEvents => _realtimeCtrl.stream;

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

  String resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$_baseUrl$path';
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
        .timeout(const Duration(seconds: 15));
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

  void connectRealtime() {
    if (_token == null) return;
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    final httpUri = Uri.parse(_baseUrl);
    final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    final wsUri = httpUri.replace(
      scheme: wsScheme,
      path: '/ws',
      queryParameters: {'token': _token!},
    );
    try {
      _wsChannel = WebSocketChannel.connect(wsUri);
      _wsSub = _wsChannel!.stream.listen(
        (event) {
          try {
            final decoded = jsonDecode(event.toString());
            if (decoded is Map<String, dynamic>) {
              _realtimeCtrl.add(decoded);
            }
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  void subscribeOrder(String orderId) {
    try {
      _wsChannel?.sink.add(
        jsonEncode({'type': 'subscribe', 'orderId': orderId}),
      );
    } catch (_) {}
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
      connectRealtime();
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
    final normalizedPhone = PhoneUtils.normalize(phone);
    if (normalizedPhone == null) throw Exception(PhoneUtils.invalidMessage);
    final data = await _request(
      'POST',
      '/api/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'phone': normalizedPhone,
        'address': address,
      },
    );
    _acceptSession(data);
    try {
      await refreshStore();
      connectRealtime();
    } catch (_) {
      _token = null;
      currentUser = null;
      rethrow;
    }
    return true;
  }

  void _acceptSession(Map<String, dynamic> data) {
    _token = data['token'] as String;
    _acceptUser(data);
  }

  User _acceptUser(Map<String, dynamic> data) {
    final user = User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    currentUser = user;
    return user;
  }

  Future<User> refreshCurrentUser() async {
    final data = await _request('GET', '/api/auth/me', authenticated: true);
    return _acceptUser(Map<String, dynamic>.from(data as Map));
  }

  Future<User> updatePhone(String phone) async {
    final normalizedPhone = PhoneUtils.normalize(phone);
    if (normalizedPhone == null || normalizedPhone.isEmpty) {
      throw Exception(PhoneUtils.invalidMessage);
    }

    final data = await _request(
      'PATCH',
      '/api/auth/me/phone',
      body: {'phone': normalizedPhone},
      authenticated: true,
    );
    return _acceptUser(Map<String, dynamic>.from(data as Map));
  }

  Future<OrderContact> loadOrderContact(String orderId) async {
    final data = await _request(
      'GET',
      '/api/orders/${Uri.encodeComponent(orderId)}/contact',
      authenticated: true,
    );
    return OrderContact.fromJson(Map<String, dynamic>.from(data as Map));
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

  Future<Order> placeOrder({
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    if (!PhoneUtils.isValid(currentUser?.phone)) {
      throw Exception(
        'Completa un teléfono válido en Perfil antes de confirmar tu pedido',
      );
    }
    final body = <String, dynamic>{};
    if (deliveryAddress != null && deliveryAddress.trim().isNotEmpty) {
      body['deliveryAddress'] = deliveryAddress.trim();
    }
    if (deliveryLat != null && deliveryLng != null) {
      body['deliveryLat'] = deliveryLat;
      body['deliveryLng'] = deliveryLng;
    }

    final data = await _request(
      'POST',
      '/api/orders',
      body: body,
      authenticated: true,
    ) as Map<String, dynamic>;
    final order = _order(Map<String, dynamic>.from(data));
    cart.clear();
    orders.insert(0, order);
    try {
      await refreshStore();
    } catch (_) {}
    return order;
  }

  TrackingData _acceptTracking(Map<String, dynamic> json) {
    final tracking = TrackingData.fromJson(json);
    for (final order in orders.where((o) => o.id == tracking.orderId)) {
      order.status = Order.parseStatus(tracking.status);
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

  // Worker APIs
  Future<List<Order>> loadWorkerOrders() async {
    final data = await _request(
      'GET',
      '/api/worker/orders',
      authenticated: true,
    ) as List;
    return data.map((e) => _order(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> prepareOrder(String orderId) async {
    await _request(
      'POST',
      '/api/worker/orders/$orderId/prepare',
      authenticated: true,
    );
  }

  Future<void> markOrderReady(String orderId) async {
    await _request(
      'POST',
      '/api/worker/orders/$orderId/ready',
      authenticated: true,
    );
  }

  // Courier APIs
  Future<({List<Order> available, List<Order> mine})>
  loadCourierOrders() async {
    final data = await _request(
      'GET',
      '/api/courier/orders',
      authenticated: true,
    ) as Map<String, dynamic>;
    final available = (data['available'] as List? ?? [])
        .map((e) => _order(Map<String, dynamic>.from(e)))
        .toList();
    final mine = (data['mine'] as List? ?? [])
        .map((e) => _order(Map<String, dynamic>.from(e)))
        .toList();
    return (available: available, mine: mine);
  }

  Future<void> acceptOrder(String orderId, {double? lat, double? lng}) async {
    if (!PhoneUtils.isValid(currentUser?.phone)) {
      throw Exception(
        'Completa un teléfono válido en Perfil antes de aceptar un pedido',
      );
    }
    await _request(
      'POST',
      '/api/courier/orders/$orderId/accept',
      body: {if (lat != null) 'lat': lat, if (lng != null) 'lng': lng},
      authenticated: true,
    );
  }

  Future<void> arrivedAtStore(String orderId) async {
    await _request(
      'POST',
      '/api/courier/orders/$orderId/arrived-store',
      authenticated: true,
    );
  }

  Future<void> pickupOrder(String orderId) async {
    await _request(
      'POST',
      '/api/courier/orders/$orderId/pickup',
      authenticated: true,
    );
  }

  Future<void> sendCourierLocation(
    String orderId,
    double lat,
    double lng,
  ) async {
    await _request(
      'POST',
      '/api/courier/orders/$orderId/location',
      body: {'lat': lat, 'lng': lng},
      authenticated: true,
    );
  }

  Future<void> arrivedAtDestination(String orderId) async {
    await _request(
      'POST',
      '/api/courier/orders/$orderId/arrived-destination',
      authenticated: true,
    );
  }

  Future<void> deliverOrderWithProof(
    String orderId,
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    await _request(
      'POST',
      '/api/courier/orders/$orderId/deliver',
      body: {
        'proofImageBase64': base64Encode(imageBytes),
        'mimeType': mimeType,
      },
      authenticated: true,
    );
  }

  // Order Chat APIs
  Future<List<OrderMessage>> loadOrderMessages(String orderId) async {
    final data = await _request(
      'GET',
      '/api/orders/$orderId/messages',
      authenticated: true,
    ) as List;
    return data
        .map((e) => OrderMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<OrderMessage> sendOrderMessage(String orderId, String message) async {
    final data = await _request(
      'POST',
      '/api/orders/$orderId/messages',
      body: {'message': message},
      authenticated: true,
    ) as Map<String, dynamic>;
    return OrderMessage.fromJson(data);
  }

  // Admin & Branch APIs
  Future<List<Map<String, dynamic>>> loadBranches() async {
    final data =
        await _request('GET', '/api/branches', authenticated: true) as List;
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> loadAdminMetrics() async {
    return Map<String, dynamic>.from(
      await _request('GET', '/api/admin/metrics', authenticated: true) as Map,
    );
  }

  Future<List<Map<String, dynamic>>> loadAdminUsers() async {
    final data =
        await _request('GET', '/api/admin/users', authenticated: true) as List;
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> createAdminUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? branchId,
  }) async {
    await _request(
      'POST',
      '/api/admin/users',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        if (branchId != null) 'branchId': branchId,
      },
      authenticated: true,
    );
  }

  Future<void> updateUserRole(
    String userId,
    String role, {
    String? branchId,
  }) async {
    await _request(
      'PATCH',
      '/api/admin/users/$userId/role',
      body: {'role': role, if (branchId != null) 'branchId': branchId},
      authenticated: true,
    );
  }

  Future<void> updateProductStock(
    String productId,
    int stock, {
    String? branchId,
  }) async {
    await _request(
      'PATCH',
      '/api/admin/products/$productId/stock',
      body: {'stock': stock, if (branchId != null) 'branchId': branchId},
      authenticated: true,
    );
  }

  List<Order> getMyOrders() => orders;

  Future<void> logout() async {
    try {
      await _request('POST', '/api/auth/logout', authenticated: true);
    } finally {
      _wsSub?.cancel();
      _wsChannel?.sink.close();
      _token = null;
      currentUser = null;
      products = [];
      cart = [];
      orders = [];
    }
  }

  Product _product(Map<String, dynamic> j) {
    final icon = _icon('${j['icon_name'] ?? ''}');
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
    final rawStatus = '${j['status'] ?? 'pending'}';
    return Order(
      id: '${j['id']}',
      items: items,
      status: Order.parseStatus(rawStatus),
      rawStatus: rawStatus,
      createdAt:
          DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
      totalAmount: _number(j['total']),
      deliveryFee: _number(j['delivery_fee'] ?? 5.0),
      branchId: j['branch_id']?.toString(),
      branchName: j['branch_name']?.toString(),
      pickupAddress: '${j['pickup_address'] ?? ''}',
      pickupLat: (j['pickup_lat'] as num?)?.toDouble(),
      pickupLng: (j['pickup_lng'] as num?)?.toDouble(),
      deliveryAddress: '${j['delivery_address'] ?? ''}',
      deliveryLat: (j['delivery_lat'] as num?)?.toDouble(),
      deliveryLng: (j['delivery_lng'] as num?)?.toDouble(),
      customerName: j['customer_name']?.toString(),
      courierUserId: j['courier_user_id']?.toString(),
      courierName: j['courier_name']?.toString(),
      courierLat: (j['courier_lat'] as num?)?.toDouble(),
      courierLng: (j['courier_lng'] as num?)?.toDouble(),
      acceptedAt: j['accepted_at'] != null
          ? DateTime.tryParse('${j['accepted_at']}')?.toLocal()
          : null,
      deliveredAt: j['delivered_at'] != null
          ? DateTime.tryParse('${j['delivered_at']}')?.toLocal()
          : null,
      deliveryDurationSeconds: (j['delivery_duration_seconds'] as num?)
          ?.toInt(),
      deliveryProofImage: j['delivery_proof_image']?.toString(),
    );
  }

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

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
