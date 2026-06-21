/// Form-field validators (return null when valid, or an error string).
class Validators {
  Validators._();

  static final RegExp _pkPhone = RegExp(r'^03\d{9}$');

  static String? validateName(String? val) {
    if (val == null || val.trim().isEmpty) return 'Name is required';
    if (val.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? validatePhone(String? val) {
    if (val == null || val.trim().isEmpty) return 'Phone number is required';
    if (!_pkPhone.hasMatch(val.trim())) return 'Enter a valid number (03XXXXXXXXX)';
    return null;
  }

  static String? validatePassword(String? val) {
    if (val == null || val.isEmpty) return 'Password is required';
    if (val.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? validateRequired(String? val, String fieldName) {
    if (val == null || val.trim().isEmpty) return '$fieldName is required';
    return null;
  }
}
