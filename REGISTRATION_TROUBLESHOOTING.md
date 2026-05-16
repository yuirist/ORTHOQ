# Registration Troubleshooting Guide

## Debug Steps

### 1. Run the App with Debug Logs

```powershell
cd C:\ORTHOQQ\orthoq_app
flutter run
```

### 2. Watch the Console Output

When you click Register, you should see:

```
🔵 Starting registration process...
🔵 Email: [your-email]
🔵 Creating Firebase Auth user...
✅ Firebase Auth user created successfully
🔵 User UID: [uid]
🔵 Creating Firestore document...
```

If you see an error, look for:
- `ERROR CODE: [code]`
- `ERROR MESSAGE: [message]`

### 3. Common Error Codes and Solutions

#### Firebase Auth Errors:

**`email-already-in-use`**
- Solution: Use a different email or login instead

**`weak-password`**
- Solution: Use a stronger password (at least 6 characters, but Firebase may require more)

**`invalid-email`**
- Solution: Check email format

**`operation-not-allowed`**
- Solution: Enable Email/Password authentication in Firebase Console
  - Go to: Authentication → Sign-in method → Enable Email/Password

**`network-request-failed`**
- Solution: Check internet connection

#### Firestore Errors:

**`permission-denied` or `PERMISSION_DENIED`**
- **Most Common Issue!**
- Solution: Check Firestore security rules
  - Go to: Firestore Database → Rules
  - Make sure rules allow authenticated users to create their own document
  - Verify document ID matches user UID

**`unavailable`**
- Solution: Firestore service is down, try again later

### 4. Check Firestore Rules

Your rules should allow:
```javascript
allow create: if isAuthenticated() 
              && request.auth.uid == patientId
```

**Quick Fix**: If rules are too strict, temporarily use:
```javascript
match /patients/{patientId} {
  allow create: if request.auth != null && request.auth.uid == patientId;
  allow read, update: if request.auth != null && request.auth.uid == patientId;
}
```

### 5. Verify Firebase Setup

1. **Check Firebase Initialization**:
   - Look for: `✅ Firebase initialized successfully` in logs
   - If missing, run `flutterfire configure`

2. **Check Authentication Method**:
   - Firebase Console → Authentication → Sign-in method
   - Ensure "Email/Password" is **Enabled**

3. **Check Firestore Database**:
   - Firebase Console → Firestore Database
   - Ensure database is created
   - Check rules are published

### 6. Test Registration Flow

1. Fill in registration form
2. Click Register
3. Watch console for:
   - ✅ Success messages (blue circles)
   - ❌ Error messages (ERROR CODE)

### 7. If Still Failing

Check the exact error in console:
- Copy the full error message
- Check which step failed (Auth creation or Firestore write)
- Verify Firestore rules match your document structure
















