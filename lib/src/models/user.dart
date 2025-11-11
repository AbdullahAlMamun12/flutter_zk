// lib/src/models/user.dart

class User {
  final int uid;
  final String name;
  final int privilege;
  final String password;
  final String groupId;
  final String userId;
  final int card;

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
