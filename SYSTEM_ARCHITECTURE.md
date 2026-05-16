# OrthoQ System Architecture Documentation

## 1. System Overview

OrthoQ is a mobile application built using Flutter and Firebase, designed to digitize and streamline the appointment booking process for the Orthopaedic Outpatient Clinic at Hospital Kajang. The system supports four user roles: Patient, Doctor, Staff, and Admin.

## 2. System Architecture Pattern

### 2.1 Layered Architecture

The application follows a **3-tier layered architecture**:

1. **Presentation Layer (UI)**
   - Flutter widgets and screens
   - User interface components
   - Navigation management

2. **Business Logic Layer (Services)**
   - Service classes for business operations
   - Data validation
   - Business rule enforcement

3. **Data Access Layer (Models & Firebase)**
   - Data models
   - Firebase integration
   - Data persistence

### 2.2 State Management

- **Pattern**: Provider Pattern
- **Purpose**: Manages application state and user authentication state
- **Implementation**: `AuthProvider` handles user authentication and profile data

## 3. Database Design

### 3.1 Entity Relationship Diagram (Conceptual)

```
┌──────────┐         ┌──────────────┐         ┌─────────┐
│   User   │◄────────┤ Appointment  ├─────────►│ Doctor  │
└──────────┘         └──────────────┘         └─────────┘
     │                       │
     │                       │
     ▼                       ▼
┌──────────────┐      ┌──────────────┐
│ Notification │      │  Storage     │
│              │      │  (Referrals) │
└──────────────┘      └──────────────┘
```

### 3.2 Firestore Collections

#### Collection: `users`
**Purpose**: Store user account information for all user types

| Field | Type | Description |
|-------|------|-------------|
| id | String | User UID from Firebase Auth |
| fullName | String | User's full name |
| email | String | User's email address |
| phoneNumber | String | User's phone number |
| role | String | User role: 'patient', 'doctor', 'staff', 'admin' |
| createdAt | Timestamp | Account creation timestamp |
| updatedAt | Timestamp | Last update timestamp |
| specialization | String? | Doctor's specialization (doctor only) |
| doctorId | String? | Reference to doctors collection (doctor only) |
| staffId | String? | Staff ID (staff/admin only) |

**Indexes Required**: None (queries use user UID directly)

#### Collection: `appointments`
**Purpose**: Store all appointment records

| Field | Type | Description |
|-------|------|-------------|
| id | String | Unique appointment ID |
| patientId | String | Reference to users collection |
| patientName | String | Patient's name (denormalized) |
| doctorId | String | Reference to doctors collection |
| doctorName | String | Doctor's name (denormalized) |
| appointmentType | String | 'new_patient' or 'follow_up' |
| appointmentDate | Timestamp | Appointment date |
| appointmentTime | String | Appointment time (e.g., "10:00 AM") |
| status | String | 'booked', 'rescheduled', 'cancelled', 'completed' |
| createdAt | Timestamp | Creation timestamp |
| updatedAt | Timestamp | Last update timestamp |
| hasRescheduleRequest | Boolean | Patient reschedule request flag |
| requestedDate | Timestamp? | Requested new date |
| requestedTime | String? | Requested new time |
| rescheduleReason | String? | Reason for rescheduling |
| referralLetterUrl | String? | Firebase Storage URL |
| referralVerified | Boolean | Referral verification status |
| hasDoctorScheduleChange | Boolean | Doctor schedule change request flag |
| doctorRequestedDate | Timestamp? | Doctor's requested new date |
| doctorRequestedTime | String? | Doctor's requested new time |
| doctorChangeReason | String? | Doctor's reason for change |
| scheduleChangeApproved | Boolean | Approval status for schedule change |

**Indexes Required**:
- `patientId` + `appointmentDate` (ascending)
- `doctorId` + `appointmentDate` (ascending)
- `status` + `appointmentDate` (ascending)

#### Collection: `doctors`
**Purpose**: Store doctor profiles and information

| Field | Type | Description |
|-------|------|-------------|
| id | String | Unique doctor ID |
| userId | String | Reference to users collection |
| name | String | Doctor's name |
| specialization | String | Doctor's specialization |
| email | String | Doctor's email |
| phoneNumber | String | Doctor's phone number |
| isActive | Boolean | Active status |
| createdAt | Timestamp | Creation timestamp |
| updatedAt | Timestamp | Last update timestamp |

**Indexes Required**: None (queries filter by isActive)

#### Collection: `notifications`
**Purpose**: Store in-app notifications

| Field | Type | Description |
|-------|------|-------------|
| id | String | Unique notification ID |
| userId | String | Reference to users collection |
| title | String | Notification title |
| message | String | Notification message |
| type | String | Notification type |
| isRead | Boolean | Read status |
| createdAt | Timestamp | Creation timestamp |
| appointmentId | String? | Reference to appointments collection |

**Indexes Required**:
- `userId` + `createdAt` (descending)
- `userId` + `isRead` (for unread count)

### 3.3 Storage Structure (Firebase Storage)

```
referrals/
  └── {userId}/
      └── {appointmentId}/
          └── referral_{timestamp}.{pdf|jpg|png}
```

## 4. Security Architecture

### 4.1 Authentication Flow

```
User → Firebase Auth → JWT Token → App State
                          ↓
                    Firestore Access
```

### 4.2 Authorization Rules (Firestore Security Rules)

1. **Users Collection**
   - Users can read/write their own data
   - Admins can read all user data

2. **Appointments Collection**
   - All authenticated users can read appointments
   - Patients can create appointments
   - Patients can update their own appointments
   - Doctors can update appointments they're assigned to
   - Staff and admins can update all appointments

3. **Doctors Collection**
   - All authenticated users can read active doctors
   - Only admins can write

4. **Notifications Collection**
   - Users can only read/write their own notifications

### 4.3 Data Privacy

- Patient data is encrypted in transit (HTTPS)
- Firebase handles encryption at rest
- Personal health information (PHI) stored securely
- Access controlled via security rules and user roles

## 5. Application Flow Diagrams

### 5.1 Patient Appointment Booking Flow

```
Patient → Select Appointment Type → Choose Doctor → Select Date/Time
    ↓
Upload Referral (if new patient) → Confirm Booking → Create Appointment
    ↓
Store in Firestore → Upload Referral to Storage → Send Notification
    ↓
Display Confirmation
```

### 5.2 Appointment Rescheduling Flow

```
Patient → Request Reschedule → Select New Date/Time → Submit Request
    ↓
Update Appointment (hasRescheduleRequest = true) → Staff Notification
    ↓
Staff Reviews → Approve/Reject
    ↓
If Approved: Update Appointment → Send Notification to Patient
If Rejected: Reset Request → Send Notification to Patient
```

### 5.3 Doctor Schedule Change Flow

```
Doctor → Select Appointment → Request Schedule Change → Enter New Date/Time/Reason
    ↓
Update Appointment (hasDoctorScheduleChange = true) → Staff Notification
    ↓
Staff Reviews → Approve
    ↓
Update Appointment → Send Notification to Patient → Update Doctor's Schedule
```

## 6. Component Architecture

### 6.1 Service Layer Components

1. **AuthService**
   - Handles authentication operations
   - User registration and login
   - Profile management
   - Password reset

2. **AppointmentService**
   - CRUD operations for appointments
   - Query appointments by user/doctor/date
   - Handle reschedule requests
   - Handle schedule change requests
   - Update appointment status

3. **DoctorService**
   - CRUD operations for doctor profiles
   - Retrieve active doctors list
   - Doctor availability management

4. **StorageService**
   - Upload referral letters
   - Delete files
   - Generate download URLs

5. **NotificationService**
   - Create notifications
   - Retrieve user notifications
   - Mark notifications as read
   - Send notification templates

### 6.2 State Management Components

1. **AuthProvider**
   - Manages authentication state
   - Current user data
   - User session management
   - Profile updates

## 7. API Integration

### 7.1 Firebase Services Used

1. **Firebase Authentication**
   - Email/Password authentication
   - User session management
   - Password reset

2. **Cloud Firestore**
   - Real-time database
   - Offline support
   - Complex queries
   - Real-time listeners

3. **Firebase Storage**
   - File upload (referral letters)
   - Secure file access
   - Download URLs

4. **Firebase Cloud Messaging** (Future)
   - Push notifications
   - Background notifications
   - Notification handling

## 8. Scalability Considerations

### 8.1 Database Scalability

- Firestore automatically scales
- Indexes optimized for common queries
- Denormalization used where appropriate (e.g., patientName, doctorName in appointments)

### 8.2 Performance Optimizations

- Real-time listeners for efficient data updates
- StreamBuilder for reactive UI updates
- Image compression before upload
- Pagination for large lists (future enhancement)

### 8.3 Security Scalability

- Security rules enforce data access at database level
- Role-based access control
- No client-side security logic

## 9. Error Handling Strategy

1. **Service Layer**: Try-catch blocks with specific error messages
2. **UI Layer**: User-friendly error messages via SnackBar
3. **Firebase Errors**: Mapped to user-friendly messages
4. **Network Errors**: Handled gracefully with retry options (future)

## 10. Testing Strategy (Recommended)

1. **Unit Tests**: Service layer functions
2. **Widget Tests**: UI components
3. **Integration Tests**: User flows
4. **Firebase Emulator**: Local testing environment

## 11. Deployment Considerations

### 11.1 Platform Support

- Android (primary)
- iOS (supported)
- Web (future consideration)

### 11.2 Build Configuration

- Android: Gradle build system
- iOS: Xcode project
- Environment-specific configurations (dev, staging, production)

### 11.3 Firebase Project Structure

- Development environment
- Production environment (separate Firebase project recommended)

## 12. Maintenance and Updates

1. **Version Control**: Git repository
2. **Dependency Management**: pubspec.yaml
3. **Code Organization**: Modular structure
4. **Documentation**: Inline comments and documentation files

## Conclusion

OrthoQ follows industry best practices for mobile app development with Firebase backend. The architecture is scalable, secure, and maintainable. The system is designed to handle the current requirements while allowing for future enhancements and expansion.
















