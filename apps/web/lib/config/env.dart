/// Backend base URL, set at build time.
///
/// Example: flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:4000
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:4000',
);
