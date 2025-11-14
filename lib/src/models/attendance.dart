// lib/src/models/attendance.dart

/// Represents a single attendance record from the biometric device.
class Attendance {
  /// The unique ID of the attendance record.
  final int uid;

  /// The user ID associated with the attendance record.
  final String userId;

  /// The date and time the attendance was recorded.
  final DateTime timestamp;

  /// The attendance status code.
  ///
  /// Common values include:
  /// - 0: Check-in
  /// - 1: Check-out
  /// - 2: Break-out
  /// - 3: Break-in
  /// - 4: Overtime-in
  /// - 5: Overtime-out
  final int status;

  /// The punch type code, indicating how the attendance was recorded.
  ///
  /// Common values include:
  /// - 0: Fingerprint
  /// - 1: Password
  /// - 2: Card
  final int punch;

  /// Creates a new [Attendance] instance.
  Attendance({
    required this.uid,
    required this.userId,
    required this.timestamp,
    required this.status,
    required this.punch,
  });

  @override
  String toString() {
    return '<Attendance>: $userId : $timestamp ($status, $punch)';
  }
}
