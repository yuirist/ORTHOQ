# Firebase Setup Guide for OrthoQ

## Prerequisites
1. Firebase account (create at https://console.firebase.google.com/)
2. FlutterFire CLI installed globally
3. Flutter project created (already done)

## Step 1: Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

**Note:** Make sure your PATH includes the `pub cache bin` directory. On Windows, this is typically:
`%LOCALAPPDATA%\Pub\Cache\bin`

If you need to add it, run:
```powershell
$env:PATH += ";$env:LOCALAPPDATA\Pub\Cache\bin"
```

## Step 2: Login to Firebase

```bash
firebase login
```

## Step 3: Create Firebase Project

1. Go to https://console.firebase.google.com/
2. Click "Add project"
3. Name it: `orthoq-app` (or your preferred name)
4. Follow the setup wizard
5. Enable Google Analytics (optional)

## Step 4: Initialize FlutterFire

Navigate to the project directory and run:

```bash
cd orthoq_app
flutterfire configure
```

This will:
- Detect your Firebase projects
- Let you select the project you created
- Configure the project for all platforms (Android, iOS, Web)
- Generate `firebase_options.dart` file

## Step 5: Enable Firebase Services

### 5.1 Enable Authentication
1. Go to Firebase Console > Authentication
2. Click "Get Started"
3. Enable "Email/Password" sign-in method
4. Enable "Email link (passwordless sign-in)" if needed

### 5.2 Enable Cloud Firestore
1. Go to Firebase Console > Firestore Database
2. Click "Create database"
3. Start in **test mode** for development (you'll set up security rules later)
4. Choose a location closest to your users (e.g., `asia-southeast1` for Malaysia)

### 5.3 Enable Cloud Storage
1. Go to Firebase Console > Storage
2. Click "Get Started"
3. Start in **test mode** for development
4. Use the same location as Firestore

### 5.4 Enable Cloud Messaging (for notifications)
1. Go to Firebase Console > Cloud Messaging
2. No additional setup needed for basic push notifications
3. For production, you'll need to configure APNs (iOS) and FCM (Android)

## Step 6: Install Dependencies

After adding dependencies to `pubspec.yaml`, run:

```bash
flutter pub get
```

## Step 7: Security Rules Setup

### Firestore Rules
Go to Firebase Console > Firestore Database > Rules and update:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Appointments collection
    match /appointments/{appointmentId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && (
        resource.data.patientId == request.auth.uid ||
        resource.data.doctorId == request.auth.uid ||
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['staff', 'admin']
      );
      allow delete: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['staff', 'admin'];
    }
    
    // Doctors collection
    match /doctors/{doctorId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Notifications collection
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
  }
}
```

### Storage Rules
Go to Firebase Console > Storage > Rules and update:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /referrals/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Step 8: Test the Setup

Run the app to verify Firebase is connected:

```bash
flutter run
```

Check the console for any Firebase initialization errors.

## Troubleshooting

### FlutterFire CLI not found
- Add pub cache to PATH (see Step 1)
- Restart terminal/PowerShell

### Configuration errors
- Make sure you're in the `orthoq_app` directory
- Verify `firebase_options.dart` was created in `lib/` folder
- Check that all platforms are configured in Firebase Console

### Authentication errors
- Verify Email/Password is enabled in Firebase Console
- Check that Firebase project is correctly selected in `firebase_options.dart`

### Firestore errors
- Ensure database is created and rules are set
- Check that security rules allow your operations
















