# Flutter API integration (deferred)

The presentation build currently does not call this API. The user setup flow
uploads the selected photo directly to Firebase Storage.

When API work resumes, restore a Flutter HTTP client for `/generate-twin`, pass
the signed-in user's Firebase ID token as `Authorization: Bearer <token>`, and
replace the direct upload in `lib/services/user_controller.dart` with the
processed image returned by the API.

For Android development over local HTTP, also restore
`android:usesCleartextTraffic="true"` and configure `API_BASE_URL` for the
emulator or physical device.
