/// Base URL of the AI service (apps/ai_service). Start it locally with:
///   uvicorn app.main:app --host 0.0.0.0 --port 8000
///
/// --host 0.0.0.0 matters: binding to 127.0.0.1 only accepts connections
/// from the same machine, which breaks the Android emulator and physical
/// device cases below.
///
/// Pick the right value for how you're running the Flutter app:
///  - Windows desktop / Chrome / Edge: use 'http://127.0.0.1:8000'.
///  - Android emulator: use 'http://10.0.2.2:8000' - the emulator's alias
///    for the host machine's localhost.
///  - A physical phone on the same Wi-Fi: use the dev machine's LAN IP,
///    e.g. 'http://192.168.1.23:8000' (run `ipconfig` to find it), and make
///    sure Windows Firewall allows inbound connections on port 8000.
///
/// Physical phone testing uses the computer's current Wi-Fi address below.
/// Keep both devices on the same network and the AI services running.
/// If the computer's IP changes, override it when rebuilding, for example:
///   flutter run --dart-define=AI_SERVICE_BASE_URL=http://192.168.1.23:8000
const String aiServiceBaseUrl = String.fromEnvironment(
  'AI_SERVICE_BASE_URL',
  defaultValue: 'http://10.101.72.146:8000',
);
