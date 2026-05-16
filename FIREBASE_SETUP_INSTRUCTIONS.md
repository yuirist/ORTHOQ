# Firebase Setup Instructions

## Problem: API Key Not Valid Error

Your `firebase_options.dart` file contains placeholder values. You need to update it with real values from Firebase.

## Solution 1: Download google-services.json from Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **orthoq-8d843**
3. Click the gear icon ⚙️ next to "Project Overview"
4. Select "Project settings"
5. Scroll down to "Your apps" section
6. Find your Android app (or create one if it doesn't exist)
7. Click "Download google-services.json"
8. Place the file in: `android/app/google-services.json`

## Solution 2: Run FlutterFire CLI (Recommended)

```bash
cd orthoq_app
dart pub global activate flutterfire_cli
flutterfire configure --project=orthoq-8d843
```

This will automatically:
- Download `google-services.json`
- Update `firebase_options.dart` with correct values

## Solution 3: Manual Update

If you have `google-services.json`, extract these values:

### From google-services.json:
- `api_key.current_key` → `apiKey` in firebase_options.dart
- `mobilesdk_app_id` → `appId` in firebase_options.dart
- `project_info.project_id` → `projectId` (already correct: orthoq-8d843)
- `project_info.storage_bucket` → `storageBucket` (already correct: orthoq-8d843.appspot.com)
- `project_info.firebase_url` → Not needed for Flutter
- `client[0].client_info.android_client_info.package_name` → Should match your app package

### Example google-services.json structure:
```json
{
  "project_info": {
    "project_number": "123456789",
    "project_id": "orthoq-8d843",
    "storage_bucket": "orthoq-8d843.appspot.com"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:123456789:android:abcdef",
        "android_client_info": {
          "package_name": "com.example.orthoq_app"
        }
      },
      "api_key": [
        {
          "current_key": "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
        }
      ]
    }
  ]
}
```

## After Getting google-services.json

Once you have the file, I can help you extract the values and update `firebase_options.dart`.
















