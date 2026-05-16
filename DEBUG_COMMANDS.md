# Debug Commands for Registration Testing

## Run App with Debug Logs

### For Physical Device:
```powershell
cd C:\ORTHOQQ\orthoq_app
flutter run
```

### For Physical Device (Verbose - More Detailed Logs):
```powershell
cd C:\ORTHOQQ\orthoq_app
flutter run -v
```

### View Logs Only (After App is Running):
```powershell
flutter logs
```

### Run and Follow Logs Continuously:
```powershell
cd C:\ORTHOQQ\orthoq_app
flutter run --verbose
```

## What to Look For

When you click the register button, you should see in the console:

```
ERROR CODE: [error-code-here]
ERROR MESSAGE: [error-message-here]
ERROR DETAILS: [full-error-details]
```

Common error codes:
- `email-already-in-use` - Email is already registered
- `weak-password` - Password is too weak
- `invalid-email` - Email format is invalid
- `network-request-failed` - Network connectivity issue
- `permission-denied` - Firestore security rules blocking
- `missing-or-insufficient-permissions` - Firestore rules issue

## Filter Logs (Optional)

To see only error-related logs:
```powershell
flutter run | Select-String -Pattern "ERROR"
```
















