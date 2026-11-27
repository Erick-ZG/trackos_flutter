import '../utils/phone_utils.dart';

enum ContactUnavailableReason { notAssigned, phoneMissing, orderClosed }

class ContactPerson {
  final String name;
  final String role;
  final String phone;

  const ContactPerson({
    required this.name,
    required this.role,
    required this.phone,
  });

  String get roleLabel => role == 'courier' ? 'Repartidor' : 'Cliente';
}

class OrderContact {
  final String orderId;
  final ContactPerson? contact;
  final ContactUnavailableReason? reason;

  const OrderContact({required this.orderId, this.contact, this.reason});

  factory OrderContact.fromJson(Map<String, dynamic> json) {
    final data = json['contact'];
    final phone = data is Map
        ? PhoneUtils.normalize(data['phone'] as String?)
        : null;
    if (json['available'] == true &&
        data is Map &&
        phone != null &&
        phone.isNotEmpty) {
      return OrderContact(
        orderId: json['orderId'] as String,
        contact: ContactPerson(
          name: data['name'] as String,
          role: data['role'] as String,
          phone: phone,
        ),
      );
    }

    return OrderContact(
      orderId: json['orderId'] as String,
      reason: switch (json['reason']) {
        'not_assigned' => ContactUnavailableReason.notAssigned,
        'order_closed' => ContactUnavailableReason.orderClosed,
        _ => ContactUnavailableReason.phoneMissing,
      },
    );
  }

  String get unavailableMessage => switch (reason) {
    ContactUnavailableReason.notAssigned =>
      'El teléfono estará disponible cuando se asigne un repartidor.',
    ContactUnavailableReason.orderClosed =>
      'Pedido finalizado. El contacto telefónico ya no está disponible.',
    _ => 'Teléfono no registrado. Puedes comunicarte por el chat del pedido.',
  };
}
