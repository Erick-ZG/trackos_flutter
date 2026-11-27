abstract final class PhoneUtils {
  static const invalidMessage =
      'Ingresa un celular peruano de 9 dígitos que comience por 9';
  static const requiredMessage = 'Ingresa tu teléfono de contacto';

  static final _allowedCharacters = RegExp(r'^[+\d\s()-]+$');
  static final _separators = RegExp(r'[\s()-]');
  static final _mobilePhone = RegExp(r'^(?:\+?51)?(9\d{8})$');

  static String? normalize(String? value) {
    if (value == null || value.length > 64) return null;

    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (!_allowedCharacters.hasMatch(trimmed)) return null;

    final match = _mobilePhone.firstMatch(trimmed.replaceAll(_separators, ''));
    return match == null ? null : '+51${match.group(1)}';
  }

  static bool isValid(String? value) => normalize(value)?.isNotEmpty == true;

  static String? validate(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? requiredMessage : null;
    }
    return normalize(value) == null ? invalidMessage : null;
  }
}
