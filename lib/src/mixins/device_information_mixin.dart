import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../zk_constants.dart';
import '../exceptions.dart';
import 'connection_mixin.dart';

/// Provides methods for retrieving information and settings from the device.
mixin DeviceInformationMixin on ConnectionMixin {
  /// Decodes a null-terminated string from a byte list.
  /// (Internal use only)
  String decodeString(Uint8List data, {Encoding encoding = utf8}) {
    try {
      final nullPos = data.indexOf(0);
      final endPos = nullPos > -1 ? nullPos : data.length;
      final validData = data.sublist(0, endPos);
      return encoding.decode(validData).trim();
    } catch (e) {
      debugPrint("Error decoding string: $e");
      return "";
    }
  }

  /// Retrieves the firmware version of the device.
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<String> getFirmwareVersion() async {
    final response = await sendCommand(CMD_GET_VERSION);
    final data = response.sublist(8);
    return decodeString(data);
  }

  /// Retrieves the serial number of the device.
  ///
  /// Returns an empty string if the serial number cannot be retrieved.
  /// Throws [ZKErrorResponse] if the command fails.
  Future<String> getSerialNumber() async {
    final commandString = Uint8List.fromList('~SerialNumber\x00'.codeUnits);
    final response = await sendCommand(
      CMD_OPTIONS_RRQ,
      commandString: commandString,
    );
    final dataString = decodeString(response.sublist(8));
    final parts = dataString.split('=');
    if (parts.length > 1) {
      return parts[1];
    }
    return "";
  }

  /// Retrieves the platform information of the device.
  ///
  /// Returns an empty string if the platform cannot be retrieved.
  /// Throws [ZKErrorResponse] if the command fails.
  Future<String> getPlatform() async {
    final commandString = Uint8List.fromList('~Platform\x00'.codeUnits);
    final response = await sendCommand(
      CMD_OPTIONS_RRQ,
      commandString: commandString,
    );
    final dataString = decodeString(response.sublist(8));
    final parts = dataString.split('=');
    if (parts.length > 1) {
      return parts[1];
    }
    return "";
  }

  /// Retrieves the MAC address of the device.
  ///
  /// Returns an empty string if the MAC address cannot be retrieved.
  /// Throws [ZKErrorResponse] if the command fails.
  Future<String> getMacAddress() async {
    final commandString = Uint8List.fromList('MAC\x00'.codeUnits);
    final response = await sendCommand(
      CMD_OPTIONS_RRQ,
      commandString: commandString,
    );
    final dataString = decodeString(response.sublist(8));
    final parts = dataString.split('=');
    if (parts.length > 1) {
      return parts[1];
    }
    return "";
  }

  /// Retrieves the name of the device.
  ///
  /// Returns an empty string if the name cannot be retrieved.
  Future<String> getDeviceName() async {
    try {
      final commandString = Uint8List.fromList('~DeviceName\x00'.codeUnits);
      final response = await sendCommand(
        CMD_OPTIONS_RRQ,
        commandString: commandString,
      );
      final dataString = decodeString(response.sublist(8));
      final parts = dataString.split('=');
      if (parts.length > 1) {
        return parts[1];
      }
      return "";
    } catch (e) {
      return "";
    }
  }

  /// Retrieves the face recognition algorithm version.
  ///
  /// Returns `null` if the version cannot be retrieved.
  Future<int?> getFaceVersion() async {
    try {
      final commandString = Uint8List.fromList('ZKFaceVersion\x00'.codeUnits);
      final response = await sendCommand(
        CMD_OPTIONS_RRQ,
        commandString: commandString,
      );
      final dataString = decodeString(response.sublist(8));
      final parts = dataString.split('=');
      if (parts.length > 1) {
        return int.tryParse(parts[1]) ?? 0;
      }
      return 0;
    } catch (e) {
      return null;
    }
  }

  /// Retrieves the fingerprint algorithm version.
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<int> getFingerprintVersion() async {
    try {
      final commandString = Uint8List.fromList('~ZKFPVersion\x00'.codeUnits);
      final response = await sendCommand(
        CMD_OPTIONS_RRQ,
        commandString: commandString,
      );
      final dataString = decodeString(response.sublist(8));
      final parts = dataString.split('=');
      if (parts.length > 1) {
        return int.tryParse(parts[1].replaceAll('=', '')) ?? 0;
      }
      return 0;
    } catch (e) {
      throw ZKErrorResponse("Can't read fingerprint version");
    }
  }

  /// Retrieves the network parameters (IP, subnet mask, gateway) of the device.
  Future<Map<String, String>> getNetworkParams() async {
    String ipAddr = ip;
    String mask = '';
    String gateway = '';

    try {
      final ipResponse = await sendCommand(
        CMD_OPTIONS_RRQ,
        commandString: Uint8List.fromList('IPAddress\x00'.codeUnits),
      );
      final ipString = decodeString(ipResponse.sublist(8));
      final ipParts = ipString.split('=');
      if (ipParts.length > 1) {
        ipAddr = ipParts[1];
      }
    } catch (e) {
      debugPrint("Error getting IP: $e");
    }

    try {
      final maskResponse = await sendCommand(
        CMD_OPTIONS_RRQ,
        commandString: Uint8List.fromList('NetMask\x00'.codeUnits),
      );
      final maskString = decodeString(maskResponse.sublist(8));
      final maskParts = maskString.split('=');
      if (maskParts.length > 1) {
        mask = maskParts[1];
      }
    } catch (e) {
      debugPrint("Error getting NetMask: $e");
    }

    try {
      final gateResponse = await sendCommand(
        CMD_OPTIONS_RRQ,
        commandString: Uint8List.fromList('GATEIPAddress\x00'.codeUnits),
      );
      final gateString = decodeString(gateResponse.sublist(8));
      final gateParts = gateString.split('=');
      if (gateParts.length > 1) {
        gateway = gateParts[1];
      }
    } catch (e) {
      debugPrint("Error getting Gateway: $e");
    }

    return {'ip': ipAddr, 'mask': mask, 'gateway': gateway};
  }

  /// Retrieves the current time from the device.
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<DateTime> getTime() async {
    final response = await sendCommand(CMD_GET_TIME);
    final data = ByteData.sublistView(response, 8);
    final t = data.getUint32(0, Endian.little);
    return decodeTime(t);
  }

  /// Sets the time on the device.
  ///
  /// [timestamp] The new date and time to set.
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<void> setTime(DateTime timestamp) async {
    final encoded = encodeTime(timestamp);
    final commandString = ByteData(4);
    commandString.setUint32(0, encoded, Endian.little);

    final response = await sendCommand(
      CMD_SET_TIME,
      commandString: commandString.buffer.asUint8List(),
    );
    final responseCode = parseHeader(response)[0];
    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("Can't set time");
    }
  }

  /// Decodes a ZKTeco timestamp integer into a [DateTime] object.
  /// (Internal use only)
  DateTime decodeTime(int t) {
    final second = t % 60;
    int temp = t ~/ 60;
    final minute = temp % 60;
    temp = temp ~/ 60;
    final hour = temp % 24;
    temp = temp ~/ 24;
    final day = temp % 31 + 1;
    temp = temp ~/ 31;
    final month = temp % 12 + 1;
    temp = temp ~/ 12;
    final year = temp + 2000;

    return DateTime(year, month, day, hour, minute, second);
  }

  /// Encodes a [DateTime] object into a ZKTeco timestamp integer.
  /// (Internal use only)
  int encodeTime(DateTime t) {
    return (((t.year % 100) * 12 * 31 + ((t.month - 1) * 31) + t.day - 1) *
            (24 * 60 * 60) +
        (t.hour * 60 + t.minute) * 60 +
        t.second);
  }
}
