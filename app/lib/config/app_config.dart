/// Static app configuration.
///
/// The Supabase anon key is a *public* key (protected by Row Level Security);
/// it is meant to ship in the client, so keeping it here is fine.
class AppConfig {
  static const String supabaseUrl = 'https://qgbtrgkiqgccmlqjxxfu.supabase.co';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFnYnRyZ2tpcWdjY21scWp4eGZ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMzNzA3NzIsImV4cCI6MjA5ODk0Njc3Mn0.MJoxPJ0C30TWfpVcVugMoyfCwTeaXK_naJrJTVwNYkI';

  /// Spring Boot backend. `localhost` works for Flutter web (Chrome) and Windows
  /// desktop. For an Android emulator use http://10.0.2.2:8866 instead.
  static const String apiBaseUrl = 'http://localhost:8866';
}
