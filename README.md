# OrthoQ - Orthopaedic Outpatient Clinic Appointment System

## Overview

OrthoQ is a comprehensive mobile-based appointment booking system designed specifically for the Orthopaedic Outpatient Clinic at Hospital Kajang. The system replaces the manual appointment process and improves appointment management efficiency, accuracy, and communication.

## Technology Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase
  - **Authentication**: Firebase Authentication
  - **Database**: Cloud Firestore
  - **Storage**: Firebase Storage (for referral letters)
  - **Notifications**: Firebase Cloud Messaging

## System Architecture

### 1. Architecture Overview

OrthoQ follows a **layered architecture** pattern:

```
┌─────────────────────────────────────┐
│         Presentation Layer          │
│  (Screens, Widgets, UI Components)  │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│         State Management             │
│      (Provider Pattern)              │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│         Service Layer                │
│  (Business Logic, API Calls)         │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│         Data Layer                   │
│  (Models, Firebase Integration)      │
└─────────────────────────────────────┘
```

### 2. Database Structure (Firestore)

#### Collections:

1. **users**
   - Stores user account information for all user types
   - Document ID: User UID (from Firebase Auth)
   - Fields: id, fullName, email, phoneNumber, role, createdAt, updatedAt, specialization (for doctors), doctorId, staffId

2. **appointments**
   - Stores all appointment records
   - Document ID: Auto-generated
   - Fields: id, patientId, patientName, doctorId, doctorName, appointmentType, appointmentDate, appointmentTime, status, createdAt, updatedAt, hasRescheduleRequest, requestedDate, requestedTime, rescheduleReason, referralLetterUrl, referralVerified, hasDoctorScheduleChange, doctorRequestedDate, doctorRequestedTime, doctorChangeReason, scheduleChangeApproved

3. **doctors**
   - Stores doctor profiles
   - Document ID: Auto-generated
   - Fields: id, userId, name, specialization, email, phoneNumber, isActive, createdAt, updatedAt

4. **notifications**
   - Stores in-app notifications
   - Document ID: Auto-generated
   - Fields: id, userId, title, message, type, isRead, createdAt, appointmentId

#### Relationships:

- **users** ↔ **appointments**: One-to-many (userId → patientId/doctorId)
- **doctors** ↔ **users**: One-to-one (doctor.userId → user.id)
- **users** ↔ **notifications**: One-to-many (userId)

### 3. User Roles and Permissions

1. **Patient**
   - Register and login
   - Book appointments (new patient/follow-up)
   - View appointment history
   - Reschedule appointments
   - Cancel appointments
   - Upload referral letters
   - Manage profile

2. **Doctor**
   - Login
   - View daily and upcoming appointments
   - View patient details
   - Request schedule changes
   - View updated schedules

3. **Staff**
   - Login
   - View all appointments
   - Approve/reject reschedule requests
   - Handle doctor schedule change requests
   - Update appointment status
   - Verify referral letters
   - Send notifications

4. **Admin**
   - All staff permissions
   - Manage user accounts
   - Create/update/remove doctor profiles
   - Configure system settings
   - Generate reports

## Module Structure

```
lib/
├── models/              # Data models
│   ├── user_model.dart
│   ├── appointment_model.dart
│   ├── doctor_model.dart
│   └── notification_model.dart
├── services/            # Business logic and API calls
│   ├── auth_service.dart
│   ├── appointment_service.dart
│   ├── doctor_service.dart
│   ├── storage_service.dart
│   └── notification_service.dart
├── providers/           # State management
│   └── auth_provider.dart
├── screens/             # UI screens
│   ├── auth/
│   │   ├── welcome_screen.dart
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── patient/
│   │   ├── patient_home_screen.dart
│   │   ├── book_appointment_screen.dart
│   │   ├── my_appointments_screen.dart
│   │   ├── reschedule_appointment_screen.dart
│   │   └── patient_profile_screen.dart
│   ├── doctor/
│   │   ├── doctor_home_screen.dart
│   │   ├── doctor_appointments_screen.dart
│   │   └── request_schedule_change_screen.dart
│   └── staff/
│       ├── staff_home_screen.dart
│       └── manage_appointments_screen.dart
└── main.dart           # App entry point
```

## User Flows

### Patient Flow

1. **Registration/Login**
   - User opens app → Welcome screen
   - Selects "Patient Login" or "Register"
   - Enters credentials/registers
   - Redirected to Patient Home

2. **Booking Appointment**
   - Navigate to "Book Appointment"
   - Select appointment type (new patient/follow-up)
   - Choose doctor from list
   - Select date and time
   - Upload referral letter (if new patient)
   - Submit booking
   - Receive confirmation notification

3. **Managing Appointments**
   - View upcoming appointments on home screen
   - View all appointments in "My Appointments"
   - Request reschedule if needed
   - Cancel appointment if needed

### Doctor Flow

1. **Login**
   - Select "Doctor Login"
   - Enter credentials
   - Redirected to Doctor Dashboard

2. **View Appointments**
   - View today's appointments on dashboard
   - View all upcoming appointments
   - See patient details for each appointment

3. **Request Schedule Change**
   - Select appointment
   - Request schedule change with reason
   - Wait for staff approval
   - View updated schedule after approval

### Staff Flow

1. **Login**
   - Select "Staff/Admin Login"
   - Enter credentials
   - Redirected to Staff Dashboard

2. **Manage Appointments**
   - View all appointments
   - See pending reschedule requests
   - Approve/reject reschedule requests
   - Handle doctor schedule change requests
   - Update appointment status
   - Verify referral letters

## Setup Instructions

### Prerequisites

- Flutter SDK (3.35.6 or later)
- Dart SDK (3.9.2 or later)
- Firebase account
- FlutterFire CLI

### Installation Steps

1. **Clone the repository** (if applicable) or navigate to project directory
   ```bash
   cd orthoq_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Firebase**
   - Follow the detailed instructions in `FIREBASE_SETUP.md`
   - Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
   - Run `flutterfire configure` to initialize Firebase
   - Enable required Firebase services (Auth, Firestore, Storage, Messaging)

4. **Update main.dart**
   - After running `flutterfire configure`, uncomment the import line for `firebase_options.dart`
   - Update `Firebase.initializeApp()` to use `DefaultFirebaseOptions.currentPlatform`

5. **Run the app**
   ```bash
   flutter run
   ```

## Security Considerations

1. **Authentication**: All users must authenticate via Firebase Authentication
2. **Authorization**: Role-based access control implemented in Firestore security rules
3. **Data Encryption**: Firebase handles data encryption at rest and in transit
4. **Input Validation**: Client-side validation on all forms
5. **Security Rules**: Implement Firestore security rules as specified in `FIREBASE_SETUP.md`

## Features Implemented

✅ User authentication (register/login for all roles)
✅ Patient appointment booking (new patient/follow-up)
✅ Doctor selection and availability
✅ Referral letter upload (PDF/image)
✅ Appointment rescheduling (patient-initiated)
✅ Appointment cancellation
✅ Doctor schedule change requests
✅ Staff approval workflow
✅ Appointment status management
✅ Notification system (in-app)
✅ Profile management
✅ Role-based navigation

## Future Enhancements

- Email notifications integration
- Push notifications (FCM)
- Appointment reminders
- Doctor availability calendar
- Admin dashboard with reports
- System configuration UI
- User account management UI
- Appointment search and filtering
- Export reports functionality

## Project Status

This is a final-year project implementation. The core features are implemented and functional. The system is ready for testing and can be extended with additional features as needed.

## License

This project is created for academic purposes as part of a final-year project.

## Contact

For questions or issues, please refer to the project documentation or contact the development team.
