# resqpk_app

Flutter mobile app (patient + driver) for **ResQPK** — a smart emergency-response system (FYP).

## Stack
- Flutter 3.35 / Dart 3.9
- Riverpod (state), go_router (navigation), Dio (HTTP)
- flutter_map + MapTiler (maps), Socket.io (real-time)
- Node/Express + Supabase backend

## Setup
1. `flutter pub get`
2. Set the dev API URL in `lib/core/constants/api_constants.dart`
   (use your PC's LAN IP when running on a physical device / LDPlayer)
3. `flutter run`

Release builds target the production Render backend automatically.
