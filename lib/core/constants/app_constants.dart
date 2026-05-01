/// App-wide constants for RouteMate application
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'RouteMate';
  static const String appVersion = '1.0.0';

  // Database
  static const String databaseName = 'route_mate.db';
  static const int databaseVersion = 3;


  // Firebase Collections
  static const String usersCollection = 'users';
  static const String tripsCollection = 'trips';
  static const String stopsCollection = 'stops';
  static const String expensesCollection = 'expenses';
  static const String sharedTripsCollection = 'shared_trips';

  // Transport Types
  static const List<String> transportTypes = [
    'car',
    'bus',
    'train',
    'flight',
    'bike',
    'walking',
  ];

  // Expense Categories
  static const List<String> expenseCategories = [
    'food',
    'accommodation',
    'transport',
    'entertainment',
    'shopping',
    'other',
  ];

  // Default Tags
  static const List<String> defaultTags = [
    'must-visit',
    'restaurant',
    'hotel',
    'attraction',
    'transit',
    'photo-spot',
  ];

  // Sync Settings
  static const int syncIntervalMinutes = 15;
  static const int maxRetryAttempts = 3;

  // Map Settings
  static const double defaultZoom = 12.0;
  static const double defaultLat = 37.7749;
  static const double defaultLng = -122.4194;
}
