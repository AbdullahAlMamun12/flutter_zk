// lib/src/models/user.dart

/// Represents a user on the biometric device.
class User {
  /// The unique internal ID of the user.
  final int uid;

  /// The name of the user.
  final String name;

  /// The privilege level of the user.
  ///
  /// Common values include:
  /// - 0: User
  /// - 2: Enroller
  /// - 6: Manager
  /// - 14: Admin
  final int privilege;

  /// The user's password for device access.
  final String password;

  /// The ID of the group the user belongs to.
  final String groupId;

  /// The custom user ID string.
  final String userId;

  /// The user's card number for RFID access.
  final int card;

  /// Creates a new [User] instance.
  User({
    required this.uid,
    required this.name,
    this.privilege = 0,
    this.password = '',
    this.groupId = '',
    required this.userId,
    this.card = 0,
  });

  @override
  String toString() {
    return '<User>: [uid:$uid, name:$name, userId:$userId]';
  }
}
