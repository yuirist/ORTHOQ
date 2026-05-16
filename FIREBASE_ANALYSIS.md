# Firebase Integration Analysis - OrthoQ App

## Executive Summary

This document provides a comprehensive analysis of all Firebase interactions in the OrthoQ application, including initialization points, data connections, authentication flows, and registration routing.

---

## 1. Firebase Services Initialization

### 1.1 Firebase Core Initialization

**File:** `lib/main.dart`  
**Lines:** 13-43

```dart
// Initialize Firebase
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

**Details:**
- Initialized in `main()` function before `runApp()`
- Uses platform-specific options from `firebase_options.dart`
- Includes error handling for initialization failures
- Passes `firebaseInitialized` flag to `AuthProvider`

### 1.2 Firebase Services Used

| Service | Initialization Location | Instance Access |
|---------|------------------------|-----------------|
| **Firebase Auth** | `lib/services/auth_service.dart` (line 7-12) | `FirebaseAuth.instance` |
| **Firestore** | Multiple service files | `FirebaseFirestore.instance` |
| **Firebase Storage** | `lib/services/storage_service.dart` (line 6) | `FirebaseStorage.instance` |

---

## 2. Firebase Authentication Operations

### 2.1 Sign In

**File:** `lib/services/auth_service.dart`  
**Lines:** 28-43

```dart
Future<UserCredential?> signInWithEmailAndPassword({
  required String email,
  required String password,
}) async {
  UserCredential userCredential = await _auth.signInWithEmailAndPassword(
    email: email.trim(),
    password: password,
  );
  return userCredential;
}
```

**Also used in:**
- `lib/screens/auth/login_screen.dart` (line 60) - Direct FirebaseAuth call
- `lib/providers/auth_provider.dart` (line 56) - Via AuthService

### 2.2 User Registration

**File:** `lib/services/auth_service.dart`  
**Lines:** 46-87

```dart
Future<UserCredential?> registerWithEmailAndPassword({
  required String email,
  required String password,
  required String fullName,
  required String phoneNumber,
  required String role,
  String? specialization,
  String? doctorId,
  String? staffId,
}) async {
  // Step 1: Create user in Firebase Auth
  UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
    email: email.trim(),
    password: password,
  );

  // Step 2: Create user document in Firestore
  await _firestore
      .collection('users')
      .doc(userCredential.user!.uid)
      .set(userModel.toMap());
}
```

**Called from:**
- `lib/screens/auth/register_screen.dart` (line 101)

### 2.3 Sign Out

**File:** `lib/services/auth_service.dart`  
**Lines:** 122-128

```dart
Future<void> signOut() async {
  await _auth.signOut();
}
```

**Also used in:**
- `lib/providers/auth_provider.dart` (line 107)
- `lib/screens/doctor/doctor_home_screen.dart` (line 51)
- `lib/screens/staff/staff_dashboard_page.dart` (line 62)
- `lib/screens/patient/patient_profile_screen.dart` (line 115)

### 2.4 Password Reset

**File:** `lib/services/auth_service.dart`  
**Lines:** 131-139

```dart
Future<void> sendPasswordResetEmail(String email) async {
  await _auth.sendPasswordResetEmail(email: email.trim());
}
```

### 2.5 Auth State Stream

**File:** `lib/services/auth_service.dart`  
**Lines:** 24-25

```dart
Stream<User?> get authStateChanges => _auth.authStateChanges();
```

**Used in:**
- `lib/providers/auth_provider.dart` (line 27) - Listens to auth state changes

---

## 3. Firestore Write Operations

### 3.1 User Registration Writes

#### Primary: `users` Collection

**File:** `lib/services/auth_service.dart`  
**Lines:** 76-79

```dart
await _firestore
    .collection('users')
    .doc(userCredential.user!.uid)
    .set(userModel.toMap());
```

**Data Structure:**
- Document ID: User UID (from Firebase Auth)
- Fields: `id`, `fullName`, `email`, `phoneNumber`, `role`, `createdAt`, `specialization` (optional), `doctorId` (optional), `staffId` (optional)

#### Secondary: `patients` Collection (Backward Compatibility)

**File:** `lib/screens/auth/register_screen.dart`  
**Lines:** 119-134

```dart
// For patients, also save to 'patients' collection for backward compatibility
if (widget.userType == 'patient') {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await FirebaseFirestore.instance
        .collection('patients')
        .doc(user.uid)
        .set({
      'fullName': _fullNameController.text.trim(),
      'phoneNumber': normalizedPhone,
      'email': _emailController.text.trim(),
      'registrationDate': FieldValue.serverTimestamp(),
      'uid': user.uid,
    });
  }
}
```

**Note:** Only executed for Patient registrations

### 3.2 Appointment Writes

**File:** `lib/services/appointment_service.dart`  
**Lines:** 8-16

```dart
Future<String> createAppointment(AppointmentModel appointment) async {
  DocumentReference docRef = await _firestore
      .collection('appointments')
      .add(appointment.toMap());
  return docRef.id;
}
```

**Update Operations:**
- Line 122: `requestReschedule()` - Updates appointment with reschedule request
- Line 144: `requestScheduleChange()` - Updates appointment with doctor schedule change
- Line 196: `approveReschedule()` - Updates appointment status and date/time
- Line 257: `approveDoctorScheduleChange()` - Updates appointment with approved schedule change
- Line 269: `updateAppointmentStatus()` - Updates appointment status
- Line 281: `cancelAppointment()` - Updates appointment status to 'cancelled'
- Line 296: `verifyReferralLetter()` - Updates referral verification status

### 3.3 Doctor Profile Writes

**File:** `lib/services/doctor_service.dart`  
**Lines:** 8-15

```dart
Future<String> createDoctor(DoctorModel doctor) async {
  DocumentReference docRef =
      await _firestore.collection('doctors').add(doctor.toMap());
  return docRef.id;
}
```

**Update Operations:**
- Line 99: `updateDoctor()` - Updates doctor profile
- Line 108: `deleteDoctor()` - Soft delete (sets `isActive: false`)

### 3.4 Notification Writes

**File:** `lib/services/notification_service.dart`  
**Lines:** 8-16

```dart
Future<String> createNotification(NotificationModel notification) async {
  DocumentReference docRef = await _firestore
      .collection('notifications')
      .add(notification.toMap());
  return docRef.id;
}
```

**Update Operations:**
- Line 45: `markAsRead()` - Updates notification read status
- Line 64: `markAllAsRead()` - Batch update for multiple notifications

### 3.5 Profile Update Writes

**File:** `lib/services/auth_service.dart`  
**Lines:** 103-119

```dart
Future<void> updateUserProfile({
  required String userId,
  String? fullName,
  String? phoneNumber,
}) async {
  await _firestore.collection('users').doc(userId).update(updateData);
}
```

---

## 4. Firestore Read/Stream Operations

### 4.1 User Data Reads

**File:** `lib/services/auth_service.dart`  
**Lines:** 90-100

```dart
Future<UserModel?> getUserData(String userId) async {
  DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
  if (doc.exists) {
    return UserModel.fromMap(doc.data() as Map<String, dynamic>, userId);
  }
  return null;
}
```

**Also used in:**
- `lib/screens/auth/login_screen.dart` (line 68) - Gets user role for navigation

### 4.2 Appointment Streams

**File:** `lib/services/appointment_service.dart`

| Method | Lines | Collection | Query |
|--------|-------|------------|-------|
| `getPatientAppointments()` | 20-30 | `appointments` | `where('patientId', isEqualTo: patientId).orderBy('appointmentDate')` |
| `getUpcomingPatientAppointments()` | 33-50 | `appointments` | `where('patientId', isEqualTo: patientId).where('status', isEqualTo: 'confirmed').where('appointmentDate', isGreaterThanOrEqualTo: startOfToday)` |
| `getDoctorAppointments()` | 53-63 | `appointments` | `where('doctorId', isEqualTo: doctorId).orderBy('appointmentDate')` |
| `getDoctorAppointmentsByDate()` | 66-83 | `appointments` | `where('doctorId', isEqualTo: doctorId).where('appointmentDate', isGreaterThanOrEqualTo: startOfDay).where('appointmentDate', isLessThan: endOfDay)` |
| `getAllAppointments()` | 86-95 | `appointments` | `orderBy('appointmentDate')` |
| `getAppointmentById()` | 98-110 | `appointments` | `.doc(appointmentId).get()` |

### 4.3 Doctor Streams

**File:** `lib/services/doctor_service.dart`

| Method | Lines | Collection | Query |
|--------|-------|------------|-------|
| `getActiveDoctors()` | 19-30 | `doctors` | `where('isActive', isEqualTo: true).orderBy('name')` |
| `getAllDoctors()` | 33-42 | `doctors` | `orderBy('name')` |
| `getDoctorById()` | 45-57 | `doctors` | `.doc(doctorId).get()` |
| `getDoctorByUserId()` | 60-76 | `doctors` | `where('userId', isEqualTo: userId).limit(1)` |
| `getDoctorsBySpecialization()` | 118-129 | `doctors` | `where('isActive', isEqualTo: true).where('specialization', isEqualTo: specialization)` |

### 4.4 Notification Streams

**File:** `lib/services/notification_service.dart`

| Method | Lines | Collection | Query |
|--------|-------|------------|-------|
| `getUserNotifications()` | 20-30 | `notifications` | `where('userId', isEqualTo: userId).orderBy('createdAt', descending: true)` |
| `getUnreadNotificationCount()` | 33-40 | `notifications` | `where('userId', isEqualTo: userId).where('isRead', isEqualTo: false)` |

---

## 5. Firebase Storage Operations

### 5.1 File Upload

**File:** `lib/services/storage_service.dart`  
**Lines:** 9-38

```dart
Future<String> uploadReferralLetter({
  required String userId,
  required String appointmentId,
  required PlatformFile file,
}) async {
  String path = 'referrals/$userId/$appointmentId/$fileName';
  Reference ref = _storage.ref().child(path);
  
  UploadTask uploadTask = ref.putData(file.bytes!, ...);
  TaskSnapshot snapshot = await uploadTask;
  String downloadUrl = await snapshot.ref.getDownloadURL();
  return downloadUrl;
}
```

**Storage Path Structure:**
- `referrals/{userId}/{appointmentId}/{fileName}`

### 5.2 File Deletion

**File:** `lib/services/storage_service.dart`  
**Lines:** 58-65

```dart
Future<void> deleteReferralLetter(String fileUrl) async {
  Reference ref = _storage.refFromURL(fileUrl);
  await ref.delete();
}
```

---

## 6. Registration Data Flow

### 6.1 Patient Registration Flow

```
RegisterScreen (register_screen.dart)
    ↓
1. Validate form (phone number validated via ValidationUtils.validateMalaysianPhone)
    ↓
2. Normalize phone number (ValidationUtils.normalizePhoneNumber)
    ↓
3. AuthService.registerWithEmailAndPassword()
    ↓
4. Firebase Auth: createUserWithEmailAndPassword()
    ↓
5. Firestore: collection('users').doc(uid).set(userModel.toMap())
    ↓
6. Firestore: collection('patients').doc(uid).set({...}) [Backward compatibility]
```

**Collections Written:**
- ✅ `users` (all user types)
- ✅ `patients` (patients only)

**Data Validated:**
- ✅ Phone number (validated and normalized)
- ❌ IC number (NOT validated in registration)

### 6.2 Doctor Registration Flow

```
RegisterScreen (register_screen.dart)
    ↓
1. Validate form (phone number validated)
    ↓
2. Normalize phone number
    ↓
3. AuthService.registerWithEmailAndPassword()
    ↓
4. Firebase Auth: createUserWithEmailAndPassword()
    ↓
5. Firestore: collection('users').doc(uid).set(userModel.toMap())
    ↓
6. Specialization field included in userModel
```

**Collections Written:**
- ✅ `users` (with `specialization` field)

**Data Validated:**
- ✅ Phone number (validated and normalized)
- ❌ IC number (NOT validated in registration)

### 6.3 Staff Registration Flow

```
RegisterScreen (register_screen.dart)
    ↓
1. Validate form (phone number validated)
    ↓
2. Normalize phone number
    ↓
3. AuthService.registerWithEmailAndPassword()
    ↓
4. Firebase Auth: createUserWithEmailAndPassword()
    ↓
5. Firestore: collection('users').doc(uid).set(userModel.toMap())
    ↓
6. Staff ID field included in userModel (optional)
```

**Collections Written:**
- ✅ `users` (with `staffId` field if provided)

**Data Validated:**
- ✅ Phone number (validated and normalized)
- ❌ IC number (NOT validated in registration)

---

## 7. Validation Status Analysis

### 7.1 Phone Number Validation

**Status:** ✅ **IMPLEMENTED**

**Location:** `lib/utils/validation_utils.dart` (lines 19-73)

**Used in Registration:**
- ✅ `lib/screens/auth/register_screen.dart` (line 276) - Form validator
- ✅ `lib/screens/auth/register_screen.dart` (line 99) - Normalized before saving

**Validation Rules:**
- Must start with `01` or `+601`
- 10-11 numeric digits
- Hyphens allowed but stripped for storage

### 7.2 IC Number Validation

**Status:** ⚠️ **NOT USED IN REGISTRATION**

**Location:** `lib/utils/validation_utils.dart` (lines 94-154)

**Currently Used In:**
- ✅ `lib/screens/patient/book_appointment_screen.dart` (line 168, 948)
- ✅ `lib/screens/patient/patient_information_screen.dart` (line 310)
- ❌ **NOT used in registration screens**

**Validation Rules:**
- 12 numeric digits (format: YYMMDD-SS-####)
- Valid date validation (first 6 digits)
- State code validation (7th-8th digits: 01-59)
- Gender extraction available (12th digit)

**Gap Identified:**
- IC validation exists but is **NOT** applied during user registration
- IC validation is only used during appointment booking
- Registration does not collect or validate IC numbers

---

## 8. Files Requiring Validation Updates

### 8.1 Registration Screen

**File:** `lib/screens/auth/register_screen.dart`

**Current State:**
- ✅ Phone validation implemented (line 276)
- ❌ IC validation NOT implemented

**Required Changes:**
1. Add IC number field to registration form
2. Add IC validation using `ValidationUtils.validateMalaysianIC`
3. Normalize IC number before saving using `ValidationUtils.normalizeICNumber`
4. Include IC number in `UserModel` when creating user document

### 8.2 Auth Service

**File:** `lib/services/auth_service.dart`

**Current State:**
- Phone number is normalized before saving (line 68)
- IC number field not present in registration method

**Required Changes:**
1. Add `icNumber` parameter to `registerWithEmailAndPassword()` method
2. Include IC number in `UserModel` creation (line 64-74)
3. Ensure IC number is normalized before saving

### 8.3 User Model

**File:** `lib/models/user_model.dart`

**Required Changes:**
1. Add `icNumber` field to `UserModel` class
2. Update `toMap()` method to include IC number
3. Update `fromMap()` method to read IC number

---

## 9. Summary of Firebase Collections

| Collection | Write Operations | Read/Stream Operations | Document ID |
|------------|------------------|------------------------|-------------|
| **users** | `auth_service.dart:79` (set), `auth_service.dart:115` (update) | `auth_service.dart:92` (get), `login_screen.dart:68` (get) | User UID |
| **patients** | `register_screen.dart:126` (set) | `patient_information_screen.dart:83` (set) | User UID |
| **appointments** | `appointment_service.dart:12` (add), Multiple updates | Multiple streams/queries | Auto-generated |
| **doctors** | `doctor_service.dart:11` (add), `doctor_service.dart:99` (update) | Multiple streams/queries | Auto-generated |
| **notifications** | `notification_service.dart:12` (add), `notification_service.dart:45` (update) | Multiple streams | Auto-generated |

---

## 10. Recommendations

### 10.1 Immediate Actions Required

1. **Add IC Validation to Registration**
   - Update `register_screen.dart` to include IC field
   - Add validation using `ValidationUtils.validateMalaysianIC`
   - Normalize IC before saving

2. **Update Auth Service**
   - Add `icNumber` parameter to registration method
   - Include IC in user document creation

3. **Update User Model**
   - Add `icNumber` field to model
   - Update serialization methods

### 10.2 Data Integrity

- ✅ Phone numbers are validated and normalized before saving
- ⚠️ IC numbers are validated in appointment booking but NOT in registration
- ⚠️ IC numbers should be collected and validated at registration for data consistency

### 10.3 Security Considerations

- All Firestore operations go through service classes
- Auth state is managed through `AuthProvider`
- Firestore security rules are in place (see `firestore.rules`)

---

## 11. File Reference Index

### Core Firebase Files
- `lib/main.dart` - Firebase initialization
- `lib/firebase_options.dart` - Firebase configuration
- `lib/services/auth_service.dart` - Authentication operations
- `lib/services/appointment_service.dart` - Appointment CRUD
- `lib/services/doctor_service.dart` - Doctor profile management
- `lib/services/notification_service.dart` - Notification management
- `lib/services/storage_service.dart` - File upload/download

### Registration Files
- `lib/screens/auth/register_screen.dart` - User registration UI
- `lib/screens/auth/login_screen.dart` - User login UI
- `lib/providers/auth_provider.dart` - Auth state management

### Validation Files
- `lib/utils/validation_utils.dart` - Phone and IC validation utilities

---

**Document Generated:** $(date)  
**Codebase Version:** Current  
**Analysis Scope:** Complete Firebase integration








