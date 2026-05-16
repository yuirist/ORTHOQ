# OrthoQ Quick Start Guide

## Initial Setup (One-time)

### Step 1: Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

**Windows Users**: Make sure the pub cache bin is in your PATH:
```powershell
$env:PATH += ";$env:LOCALAPPDATA\Pub\Cache\bin"
```

### Step 2: Login to Firebase

```bash
firebase login
```

### Step 3: Create Firebase Project

1. Go to https://console.firebase.google.com/
2. Click "Add project"
3. Name: `orthoq-app` (or your preferred name)
4. Complete the setup wizard

### Step 4: Configure FlutterFire

Navigate to the project directory:

```bash
cd orthoq_app
flutterfire configure
```

Select your Firebase project when prompted.

### Step 5: Update main.dart

After `flutterfire configure` completes, you'll have a `firebase_options.dart` file. Update `lib/main.dart`:

1. Uncomment line 11: `import 'firebase_options.dart';`
2. Replace line 22 with:
   ```dart
   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```

### Step 6: Enable Firebase Services

Go to Firebase Console and enable:

1. **Authentication**
   - Go to Authentication → Get Started
   - Enable "Email/Password" sign-in method

2. **Firestore Database**
   - Go to Firestore Database → Create database
   - Start in **test mode** (for development)
   - Choose location: `asia-southeast1` (recommended for Malaysia)

3. **Storage**
   - Go to Storage → Get Started
   - Start in **test mode**
   - Use same location as Firestore

4. **Cloud Messaging** (Optional for now)
   - Go to Cloud Messaging
   - No additional setup needed for basic use

### Step 7: Install Dependencies

```bash
flutter pub get
```

### Step 8: Run the App

```bash
flutter run
```

## Testing the Application

### Create Test Users

1. **Patient Registration**
   - Open app → Patient Login → Register
   - Fill in: Full Name, Phone Number, Email, Password
   - Register

2. **Doctor Account** (Created by Admin)
   - Note: Doctor accounts should be created through admin panel or Firebase Console
   - For testing, you can create a user in Firebase Auth with email/password
   - Then create a document in `users` collection with role: 'doctor'
   - Create corresponding document in `doctors` collection

3. **Staff Account** (Created by Admin)
   - Similar to doctor, create user with role: 'staff' or 'admin'

### Test Scenarios

1. **Patient Booking Flow**
   - Login as patient
   - Book Appointment → Select type → Choose doctor → Select date/time
   - Upload referral letter (for new patient)
   - Submit booking
   - Check appointment in "My Appointments"

2. **Reschedule Flow**
   - As patient, go to "My Appointments"
   - Click "Reschedule" on an appointment
   - Select new date/time
   - Submit request
   - As staff, approve/reject the request

3. **Doctor Schedule Change**
   - Login as doctor
   - View appointments
   - Request schedule change
   - As staff, approve the change

## Important Notes

1. **Security Rules**: For development, Firestore and Storage start in test mode. For production, update security rules as specified in `FIREBASE_SETUP.md`.

2. **Doctor Linking**: In the current implementation, doctor appointments are linked via `userId`. Ensure doctor users have corresponding documents in both `users` and `doctors` collections.

3. **Notifications**: In-app notifications are implemented. Push notifications require additional FCM configuration.

## Troubleshooting

### FlutterFire CLI not found
- Ensure pub cache is in PATH
- Restart terminal/PowerShell
- Try: `dart pub global list` to verify installation

### Firebase initialization errors
- Verify `firebase_options.dart` exists in `lib/` folder
- Check that Firebase project is correctly selected
- Ensure all platforms are configured in Firebase Console

### Authentication errors
- Verify Email/Password is enabled in Firebase Console
- Check email format
- Ensure password is at least 6 characters

### Firestore errors
- Verify database is created
- Check security rules (should be in test mode for development)
- Verify collection names match exactly

## Next Steps

1. Set up security rules for production (see `FIREBASE_SETUP.md`)
2. Configure push notifications (FCM)
3. Test all user flows
4. Deploy to app stores (Android/iOS)
















