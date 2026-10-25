# StyleSync Flutter tests

The folders follow the eight test cases in the reference picture. Settings maps
to the app's Profile screen, and Digital Wardrobe maps to My Closet on Home.

| Folder | Coverage |
| --- | --- |
| `TC001_Login` | Required fields, email validation, trimmed credentials, profile routing, authentication errors and retry, loading, Google button, password reset |
| `TC002_Registration` | Required fields, password rules, all gender options, profile persistence, registration errors, loading, Google button |
| `TC003_Home_Page` | User greeting, empty closet, profile and bottom navigation, opening Outfit Creator |
| `TC004_Setting_Page` | Profile details and defaults, saved outfits navigation, password reset, logout, edit validation and persistence, Theme notice |
| `TC005_Virtual_TryOn` | Loading, missing choices, supported categories, garment selection, generated image, duplicate-request prevention, refresh, service and malformed-result errors |
| `TC006_Outfit_Creator` | Selection and clearing, one item per category, saving outfits, cancelling and blank names, deleting saved outfits, signed-out protection |
| `TC007_AI_InspoMirror` | Screen content, upload and generation notices, back navigation |
| `TC008_Digital_Wardrobe` | Clothing categories, loading, adding sample clothes, duplicate prevention, photo source options, category order, image gallery, deletion confirmation, user isolation, signed-out protection, image source model |

`smoke_test.dart` checks navigation across real Login, Home, and Profile screens
through logout, plus navigation to Registration and back.

## Run

From the repository root:

```powershell
cd apps/mobile_app
flutter pub get
flutter test
```

Run one group or one file:

```powershell
flutter test test/TC001_Login
flutter test test/TC005_Virtual_TryOn/virtual_tryon_test.dart
flutter test test/smoke_test.dart
```

Generate a coverage report:

```powershell
flutter test --coverage
```

Flutter writes coverage data to `coverage/lcov.info`.

## Test dependencies and scope

The suite uses `flutter_test`, `firebase_auth_mocks`, and `fake_cloud_firestore`.
Every test starts with isolated, in-memory data and resets GetX state afterward.
Optional Firebase constructor inputs in the screens and controllers let tests
exercise real application logic without initializing Firebase or contacting a
backend. Production constructors still default to the existing Firebase services.

Virtual Try-On uses an injected fake AI service with local PNG data. The native
Google sign-in picker is replaced with a recorded action. Native camera/gallery
selection, image uploads to Storage, real Firebase credentials and security rules,
notifications, and real AI generation require device or integration tests.

AI Inspo-Mirror upload/generation and Theme currently display “Coming Soon”
messages; the tests check those existing messages.
