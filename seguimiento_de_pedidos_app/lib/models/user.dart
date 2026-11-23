class User {
  final String id;
  final String name;
  final String email;
  String password;
  String phone;
  String address;
  final String role;
  final String? branchId;
  final String? branchName;
  final String? branchAddress;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.phone = '',
    this.address = '',
    this.role = 'customer',
    this.branchId,
    this.branchName,
    this.branchAddress,
  });

  bool get isWorker => role == 'worker';
  bool get isCourier => role == 'courier';
  bool get isAdmin => role == 'admin';
  bool get isCustomer => role == 'customer';

  String get roleLabel => switch (role) {
    'worker' => 'Trabajador de sede',
    'courier' => 'Repartidor',
    'admin' => 'Administrador',
    _ => 'Cliente',
  };
}
