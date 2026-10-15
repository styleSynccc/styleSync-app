/// Base URL of the AI service (apps/ai_service). Start it locally with:
///   uvicorn app.main:app --host 0.0.0.0 --port 8000
///
/// --host 0.0.0.0 matters: binding to 127.0.0.1 only accepts connections
/// from the same machine, which breaks the Android emulator and physical
/// device cases below.
///
/// The default below is the dev machine's Wi-Fi LAN IP. Unlike the
/// emulator-only 'http://10.0.2.2:8000' alias, a LAN IP works from BOTH
/// the Android emulator (it can reach the host's real LAN IP fine) AND a
/// physical phone on the same Wi-Fi - one value, no switching needed.
///
/// This only works for devices on the SAME Wi-Fi network as this machine.
/// If that network changes (different Wi-Fi, router reboot, etc.), run
/// `ipconfig`, find the current "IPv4 Address" under the Wi-Fi adapter,
/// and update the IP below. Also make sure Windows Firewall allows inbound
/// connections on port 8000.
///
/// To use a different value without editing source code (e.g. a device on
/// a different network entirely, which needs a tunnel, not just a new IP):
///   flutter run --dart-define=AI_SERVICE_BASE_URL=http://some-other-host:8000
const String aiServiceBaseUrl = String.fromEnvironment(
  'AI_SERVICE_BASE_URL',
  defaultValue: 'http://10.52.13.100:8000',
);
