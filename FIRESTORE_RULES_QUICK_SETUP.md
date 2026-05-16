# Quick Setup: Firestore Security Rules

## Copy-Paste Ready Rules

Copy the entire contents of `firestore.rules` and paste into Firebase Console:

1. Go to: https://console.firebase.google.com/project/orthoq-8d843/firestore/rules
2. Replace the existing rules with the content from `firestore.rules`
3. Click **Publish**

## What These Rules Do

### For Patients Collection:
- ✅ **Create**: Authenticated users can only create their own profile (document ID = their UID)
- ✅ **Read**: Users can only read their own data
- ✅ **Update**: Users can only update their own data (cannot change uid or registrationDate)
- ✅ **Delete**: Blocked for regular users (admin-only)
- ❌ **Unauthenticated**: Completely blocked from all operations

### Security Guarantees:
1. No user can access another user's patient data
2. No unauthenticated access to patient information
3. Users cannot modify their UID or registration date
4. All operations require authentication

## Verification

After applying rules, test:
- ✅ Register a new patient → Should succeed
- ✅ Login and view own profile → Should succeed  
- ❌ Try to read another user's data → Should fail with permission error
- ❌ Try to access without login → Should fail with permission error
















