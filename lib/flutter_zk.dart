/// A Dart library for connecting to and managing ZKTeco biometric devices.
///
/// This library provides a high-level API for interacting with ZKTeco devices
/// over a TCP/IP network. It supports operations such as fetching users,
/// attendance records, and device information, as well as controlling the device
/// (e.g., restarting, opening doors).
library;

export 'src/zk_base.dart';
export 'src/exceptions.dart';
export 'src/models/attendance.dart';
export 'src/models/user.dart';
export 'src/models/finger.dart';
