# How to Fix "API Key Not Valid" Error

## Quick Fix Steps:

### Step 1: Get Firebase Configuration Values

**Option A: Download google-services.json from Firebase Console**
1. Go to https://console.firebase.google.com/
2. Select project: **orthoq-8d843**
3. Click ⚙️ (Settings) → Project settings
4. Scroll to "Your apps" section
5. Find your Android app (or create one)
6. Click "Download google-services.json"
7. Save it to: `android/app/google-services.json`
8. Run: `powershell -ExecutionPolicy Bypass -File extract_firebase_config.ps1`

**Option B: Get values directly from Firebase Console**
1. Go to Firebase Console → Project Settings
2. Under "Your apps", find your Android app
3. Copy these values:
   - **API Key** (under "SDK setup and configuration")
   - **App ID** (mobilesdk_app_id)
   - **Messaging Sender ID** (project_number)

### Step 2: Update firebase_options.dart

Once you have the values, I can update the file. Or you can manually update:

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'YOUR_ACTUAL_API_KEY_HERE',  // Replace this
  appId: 'YOUR_ACTUAL_APP_ID_HERE',     // Replace this
  messagingSenderId: 'YOUR_SENDER_ID', // Replace this
  projectId: 'orthoq-8d843',            // Already correct
  storageBucket: 'orthoq-8d843.appspot.com', // Already correct
);
```

### Step 3: Verify main.dart

Your `main.dart` is already correctly using:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

✅ This is correct!

## Need Help?

If you can provide:
- The API Key from Firebase Console
- The App ID (mobilesdk_app_id)
- The Messaging Sender ID (project_number)

I can update `firebase_options.dart` for you automatically.
















