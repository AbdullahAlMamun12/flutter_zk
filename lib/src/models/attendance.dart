// lib/src/models/attendance.dart

class Attendance {
  final int uid;
  final String userId;
  final DateTime timestamp;
  final int status;
  final int punch;

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
