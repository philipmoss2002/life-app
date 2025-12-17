/// Centralized document category constants
/// This ensures consistency across the app and prevents validation errors
class DocumentCategories {
  static const List<String> all = [
    homeInsurance,
    carInsurance,
    mortgage,
    holiday,
    other,
  ];

  static const List<String> allWithFilter = [
    'All',
    homeInsurance,
    carInsurance,
    mortgage,
    holiday,
    other,
  ];

  // Individual category constants
  static const String homeInsurance = 'Home Insurance';
  static const String carInsurance = 'Car Insurance';
  static const String mortgage = 'Mortgage';
  static const String holiday = 'Holiday';
  static const String other = 'Other';

  /// Check if a category is valid
  static bool isValid(String category) {
    return all.contains(category);
  }

  /// Get the default category
  static String get defaultCategory => homeInsurance;
}
