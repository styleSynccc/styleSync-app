/// Base URL of the AI service (apps/ai_service). Start it locally with:
///   uvicorn app.main:app --host 0.0.0.0 --port 8000
///
/// --host 0.0.0.0 matters: binding to 127.0.0.1 only accepts connections
/// from the same machine, which breaks the Android emulator and physical
/// device cases below.
///
/// Pick the right value for how you're running the Flutter app:
///  - Windows desktop / Chrome / Edge (the current dev targets): the default
///    below (localhost) is correct as-is.
///  - Android emulator: use 'http://10.0.2.2:8000' - the emulator's alias
///    for the host machine's localhost.
///  - A physical phone on the same Wi-Fi: use the dev machine's LAN IP,
///    e.g. 'http://192.168.1.23:8000' (run `ipconfig` to find it), and make
///    sure Windows Firewall allows inbound connections on port 8000.
///
/// Currently set to the dev machine's Wi-Fi LAN IP rather than localhost:
/// that also still works from Windows desktop/Chrome/Edge on this same
/// machine, so one value covers every target currently in use, including a
/// physical phone. Re-check this IP (`ipconfig`) if it stops working - it's
/// not static across networks/reboots.
const String aiServiceBaseUrl = 'http://192.168.0.9:8000';
