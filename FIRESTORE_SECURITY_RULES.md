# Firestore Security Rules Setup Guide

## Overview

This guide explains how to apply secure Firestore security rules to protect patient data in your OrthoQ application.

## Security Rules for Patients Collection

The rules ensure:
- ✅ Only authenticated users can create their own profile
- ✅ Users can only read/update their own data
- ✅ Unauthenticated users cannot access any patient information
- ✅ Users cannot delete their own profiles (admin-only operation)

## How to Apply the Rules

### Step 1: Open Firebase Console

1. Go to https://console.firebase.google.com/
2. Select your project: **orthoq-8d843**
3. Navigate to **Firestore Database** in the left sidebar
4. Click on the **Rules** tab

### Step 2: Copy and Paste the Rules

1. Open the `firestore.rules` file in this project
2. Copy the entire contents
3. Paste into the Firebase Console Rules editor
4. Click **Publish** to apply the rules

### Step 3: Verify Rules are Active

After publishing, the rules are immediately active. You can test them using the Rules Playground in Firebase Console.

## Rule Breakdown

### Patients Collection Rules

```javascript
match /patients/{patientId} {
  // CREATE: Only authenticated users can create their own profile
  // Document ID must match user's UID
  allow create: if isAuthenticated() 
                && request.auth.uid == patientId
                && request.resource.data.keys().hasAll(['fullName', 'phoneNumber', 'email', 'registrationDate', 'uid'])
                && request.resource.data.uid == request.auth.uid;
  
  // READ: Users can only read their own data
  allow read: if isOwner(patientId);
  
  // UPDATE: Users can only update their own data
  // Cannot change uid or registrationDate
  allow update: if isOwner(patientId)
                && request.resource.data.uid == request.auth.uid
                && !('registrationDate' in request.resource.data.diff(resource.data).affectedKeys());
  
  // DELETE: Users cannot delete (admin-only)
  allow delete: if false;
}
```

### Key Security Features

1. **Authentication Required**: All operations require `request.auth != null`
2. **Ownership Verification**: Document ID must match user's UID
3. **Data Validation**: Required fields are enforced on create
4. **Immutable Fields**: `uid` and `registrationDate` cannot be changed
5. **No Public Access**: Unauthenticated users are completely blocked

## Testing the Rules

### Test Case 1: User Creates Own Profile
- ✅ User with UID "abc123" can create `/patients/abc123`
- ❌ User with UID "abc123" cannot create `/patients/xyz789`

### Test Case 2: User Reads Own Data
- ✅ User with UID "abc123" can read `/patients/abc123`
- ❌ User with UID "abc123" cannot read `/patients/xyz789`

### Test Case 3: Unauthenticated Access
- ❌ Unauthenticated user cannot read any patient data
- ❌ Unauthenticated user cannot create any patient data

## Important Notes

1. **Document ID = User UID**: The registration code must use the user's UID as the document ID:
   ```dart
   .collection('patients')
   .doc(userCredential.user!.uid)  // ✅ Correct
   .set({...})
   ```

2. **Required Fields**: When creating a patient document, these fields must be present:
   - `fullName`
   - `phoneNumber`
   - `email`
   - `registrationDate`
   - `uid`

3. **Immutable Fields**: Once created, `uid` and `registrationDate` cannot be updated.

4. **Admin Access**: Admins can access all patient data through the `users` collection role check.

## Troubleshooting

### Error: "Missing or insufficient permissions"
- Check that the user is authenticated
- Verify the document ID matches the user's UID
- Ensure all required fields are present when creating

### Error: "Permission denied"
- User is trying to access another user's data
- User is not authenticated
- Required fields are missing

## Next Steps

After applying these rules:
1. Test registration with a new user
2. Verify the user can read their own data
3. Verify the user cannot read other users' data
4. Test that unauthenticated users are blocked
















