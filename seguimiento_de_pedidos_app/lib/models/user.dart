class User {
  final String id;
  final String name;
  final String email;
  String password;
  String phone;
  String address;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.phone = '',
    this.address = '',
  });
}
