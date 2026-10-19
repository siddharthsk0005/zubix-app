/// Backend base URL, set at build time.
///
/// Defaults to localhost. Android emulators need `http://10.0.2.2:4000`.
/// Example: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:4000',
);
