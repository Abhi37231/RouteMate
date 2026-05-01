# RouteMate Firebase Setup Guide

## IMPORTANT: This is a 100% FREE travel planner app!

This app uses **free and open-source technologies**:
- **OpenStreetMap** - Free map tiles (no paid API!)
- **Firebase Free Tier** - Authentication + Firestore
- **SQLite** - Offline local storage

---

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `routemate-app`
4. Disable Google Analytics (optional)
5. Click "Create Project"

## Step 2: Register Android App

1. In Firebase Console, click Android icon
2. Package name: `com.routemate.app`
3. App nickname: `RouteMate`
4. Click "Register app"

## Step 3: Download Config Files

1. Download `google-services.json`
2. Place in: `android/app/` directory

## Step 4: Enable Authentication

1. In Firebase Console, go to Build > Authentication
2. Click "Get started"
3. Enable **Email/Password** provider:
   - Email/Password: Enable
   - Email link (passwordless): Disable (optional)
4. Enable **Google** sign-in (optional):
   - Enable Google
   - Support email: Add your email
   - Click Save

## Step 5: Create Firestore Database

1. In Firebase Console, go to Build > Firestore Database
2. Click "Create database"
3. Select location (nearest to you)
4. Start in **Test mode** (allows read/write for 30 days)
5. Click Create

## Step 6: Build and Run

```bash
cd d:/App/TripPlaner
flutter pub get
flutter run
```

---

## Maps: OpenStreetMap (No API Key Needed!)

The app uses OpenStreetMap which is **completely free**:
- No Google Maps API key required
- No credit card needed
- No paid services

**Tile Server**: https://tile.openstreetmap.org

---

## Troubleshooting

### Permission Denied Errors
Make sure Firestore rules allow access in Test Mode.

### Authentication Errors
- Enable Email/Password in Firebase Console
- For Google Sign-In, add your SHA-1 fingerprint:

```bash
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore
```

Add SHA-1 in Firebase Console > Project Settings.

### Build Errors
Clean and rebuild:
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

---

## Cost: $0.00

- **OpenStreetMap**: Free forever
- **Firebase Free Tier**: Free (up to limits)
- **No paid APIs** used in this app
