# NU BD Exchange

A Flutter shopping app for the Advanced Mobile Programming laboratory project.

## Authentication enhancements

1. **Enhancement 1 — Splash and persistent authentication:** A custom splash screen checks the saved session with DummyJSON, refreshes expired access credentials when possible, and opens the shop or sign-in screen. Connection failures show a retry action and retain the saved session.
2. **Enhancement 2 — Sign-in:** A custom form uses `UserService` to validate credentials, show loading and error states, and save a successful login before opening the shop.
3. **Enhancement 3 — Profile and user carts:** The `User` model supplies the saved profile displayed in Home's Profile tab. Cart loading and product actions use the signed-in user's ID. Signing out clears authentication data and the navigation history while preserving appearance settings.

Implementation sections are marked with `//Enhancement 1`, `//Enhancement 2`, and `//Enhancement 3` comments.

## Run

With the Flutter SDK installed and a device, emulator, or browser available:

```sh
flutter pub get
flutter run
```

Use the public DummyJSON demo account:

- Username: `emilys`
- Password: `emilyspass`

These sample credentials come from the [official DummyJSON authentication documentation](https://dummyjson.com/docs/auth). The API defaults to `https://dummyjson.com`; an optional `HOST` value in `assets/.env` overrides it.

## Persistence and network behavior

- Authentication data is stored with SharedPreferences and survives app restarts. Passwords are not saved. Restoring a session requires an internet connection; the splash screen offers Retry when validation cannot connect.
- DummyJSON simulates cart changes and does not persist those changes on its server. Added products and quantity edits are kept in app memory for each user and reset on a full app restart. Cart loading still requires a network connection.

## Verify

```sh
dart analyze
flutter test
flutter build apk --debug
```

The Android build requires the Android SDK. Tests cover authentication, navigation, profile data, and user-specific cart behavior.

## Laboratory 3 feature history — Morales

- Added **Add to Cart** to products opened from the shop and displayed the quantity already in the cart. Products opened from the cart show their details without an Add to Cart button.
- Added cart quantity controls, individual discount percentages, and calculated discount and final totals.
- Changed Chat into a half-screen popup above the shop.
