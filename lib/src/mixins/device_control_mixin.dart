import 'dart:async';
import 'dart:typed_data';

import '../zk_constants.dart';
import '../exceptions.dart';
import 'connection_mixin.dart';

/// Provides methods for controlling the device's state and operations.
mixin DeviceControlMixin on ConnectionMixin {
  /// Enables the device, allowing it to accept user input and perform operations.
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<void> enableDevice() async {
    final response = await sendCommand(CMD_ENABLEDEVICE);
    final responseCode = parseHeader(response)[0];
    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("Can't enable device");
    }
  }

  /// Disables the device, preventing it from accepting user input.
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<void> disableDevice() async {
    final response = await sendCommand(CMD_DISABLEDEVICE);
    final responseCode = parseHeader(response)[0];
    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("Can't disable device");
    }
  }

  /// Restarts the device.
  ///
  /// The connection will be lost after this command is executed.
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<void> restart() async {
    final response = await sendCommand(CMD_RESTART);
    final responseCode = parseHeader(response)[0];
    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("Can't restart device");
    }
    isConnected = false;
  }

  /// Powers off the device.
  ///
  /// The connection will be lost after this command is executed.
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<void> powerOff() async {
    final response = await sendCommand(CMD_POWEROFF);
    final responseCode = parseHeader(response)[0];
    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("Can't power off device");
    }
    isConnected = false;
  }

  /// Refreshes the device's internal data.
  ///
  /// This is often required after making changes to users or other data.
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<void> refreshData() async {
    final response = await sendCommand(CMD_REFRESHDATA);
    final responseCode = parseHeader(response)[0];
    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("Can't refresh data");
    }
  }

  /// Unlocks the door connected to the device's relay.
  ///
  /// [time] The duration in seconds to keep the door unlocked (default is 3).
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<void> unlock({int time = 3}) async {
    final commandString = ByteData(4);
    commandString.setUint32(
      0,
      time * 10,
      Endian.little,
    ); // Device expects time in 100ms intervals
    final response = await sendCommand(
      CMD_UNLOCK,
      commandString: commandString.buffer.asUint8List(),
    );
    final responseCode = parseHeader(response)[0];
    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("Can't unlock door");
    }
  }

  /// Plays a pre-recorded voice message on the device.
  ///
  /// [index] The index of the voice message to play.
  ///
  /// Common voice indices:
  /// - 0: "Thank You"
  /// - 1: "Incorrect Password"
  /// - 2: "Access Denied"
  /// - 3: "Invalid ID"
  ///
  /// Returns `true` if the command was sent successfully, `false` otherwise.
  Future<bool> testVoice({int index = 0}) async {
    try {
      final commandString = ByteData(4);
      commandString.setUint32(0, index, Endian.little);
      final response = await sendCommand(
        CMD_TESTVOICE,
        commandString: commandString.buffer.asUint8List(),
      );
      final responseCode = parseHeader(response)[0];
      return responseCode == CMD_ACK_OK;
    } catch (e) {
      return false;
    }
  }
}
