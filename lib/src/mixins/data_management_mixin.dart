import 'dart:async';

import '../zk_constants.dart';
import '../exceptions.dart';
import 'connection_mixin.dart';

/// Provides methods for managing stored data on the device.
mixin DataManagementMixin on ConnectionMixin {
  /// Clears all data from the device, including users, attendance records,
  /// and fingerprint templates.
  ///
  /// **Warning:** This is a destructive operation and cannot be undone.
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<void> clearData() async {
    final response = await sendCommand(CMD_CLEAR_DATA);
    final responseCode = parseHeader(response)[0];
    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("Can't clear data");
    }
  }

  /// Clears all attendance records from the device.
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<void> clearAttendance() async {
    final response = await sendCommand(CMD_CLEAR_ATTLOG);
    final responseCode = parseHeader(response)[0];
    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("Can't clear attendance");
    }
  }
}
