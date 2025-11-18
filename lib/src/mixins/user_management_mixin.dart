import 'dart:async';
import 'dart:typed_data';

import '../zk_constants.dart';
import '../exceptions.dart';
import '../models/user.dart';
import 'connection_mixin.dart';
import 'network_mixin.dart';
import 'device_information_mixin.dart';
import 'device_control_mixin.dart';
import '../utils/logger.dart';

/// Provides methods for managing users on the device.
mixin UserManagementMixin
    on
        ConnectionMixin,
        NetworkMixin,
        DeviceInformationMixin,
        DeviceControlMixin {
  /// Retrieves a list of all users from the device.
  ///
  /// This method fetches the raw user data and parses it into a list of [User] objects.
  ///
  /// Returns a list of [User] objects. Returns an empty list if no users are found
  /// or if the data is invalid.
  ///
  /// Throws [ZKErrorResponse] if the command to fetch data fails.
  Future<List<User>> getUsers() async {
    await readSizes();

    if (usersCount == 0) {
      debugLog("No users found on device");
      return [];
    }

    debugLog("Device reports $usersCount users");

    final userData = await readWithBuffer(CMD_USERTEMP_RRQ, fct: FCT_USER);

    debugLog("Received user data: ${userData.length} bytes");

    if (userData.length <= 4) {
      debugLog("Warning: Insufficient user data");
      return [];
    }

    final totalSize = ByteData.sublistView(
      userData,
      0,
      4,
    ).getUint32(0, Endian.little);
    debugLog("Total size from header: $totalSize bytes");

    if (totalSize == 0) {
      return [];
    }

    final calculatedPacketSize = totalSize / usersCount;
    if ((calculatedPacketSize - 28).abs() < 1.0) {
      userPacketSize = 28;
    } else if ((calculatedPacketSize - 72).abs() < 1.0) {
      userPacketSize = 72;
    } else {
      debugLog("Warning: Unusual packet size: $calculatedPacketSize, using 72");
      userPacketSize = 72;
    }

    debugLog("Using packet size: $userPacketSize bytes per user");

    final users = <User>[];
    var offset = 4;

    for (int i = 0;
        i < usersCount && offset + userPacketSize <= userData.length;
        i++) {
      try {
        final userChunk = userData.sublist(offset, offset + userPacketSize);
        final byteData = ByteData.sublistView(userChunk);

        if (userPacketSize == 28) {
          final uid = byteData.getUint16(0, Endian.little);
          final privilege = byteData.getUint8(2);
          final passwordBytes = userChunk.sublist(3, 8);
          final nameBytes = userChunk.sublist(8, 16);
          final card = byteData.getUint32(16, Endian.little);
          final groupId = byteData.getUint8(21).toString();
          final userId = byteData.getUint32(24, Endian.little).toString();

          final password = decodeString(passwordBytes);
          final name = decodeString(nameBytes);

          users.add(
            User(
              uid: uid,
              privilege: privilege,
              password: password,
              name: name.isNotEmpty ? name : "NN-$userId",
              card: card,
              groupId: groupId,
              userId: userId,
            ),
          );
        } else {
          final uid = byteData.getUint16(0, Endian.little);
          final privilege = byteData.getUint8(2);
          final passwordBytes = userChunk.sublist(3, 11);
          final nameBytes = userChunk.sublist(11, 35);
          final card = byteData.getUint32(35, Endian.little);
          final groupIdBytes = userChunk.sublist(40, 47);
          final userIdBytes = userChunk.sublist(48, 72);

          final password = decodeString(passwordBytes);
          final name = decodeString(nameBytes);
          final groupId = decodeString(groupIdBytes);
          final userId = decodeString(userIdBytes);

          users.add(
            User(
              uid: uid,
              privilege: privilege,
              password: password,
              name: name.isNotEmpty ? name : "NN-$userId",
              card: card,
              groupId: groupId,
              userId: userId.isNotEmpty ? userId : uid.toString(),
            ),
          );
        }
      } catch (e) {
        debugLog("Error parsing user $i: $e");
      }

      offset += userPacketSize;
    }

    debugLog("Successfully parsed ${users.length} users");
    return users;
  }

  /// Creates a new user or updates an existing user on the device.
  ///
  /// To update a user, provide their existing [uid]. To create a new user,
  /// omit the [uid] and the device will assign a new one.
  ///
  /// - [uid]: The unique internal ID of the user to update. If null, a new user is created.
  /// - [name]: The name of the user.
  /// - [privilege]: The user's privilege level (0-14). Defaults to 0 (User).
  /// - [password]: The user's password.
  /// - [groupId]: The ID of the group the user belongs to.
  /// - [userId]: The custom user ID string. If not provided, it defaults to the `uid`.
  /// - [card]: The user's card number for RFID access.
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<void> setUser({
    int? uid,
    String name = '',
    int privilege = 0,
    String password = '',
    String groupId = '',
    String? userId,
    int card = 0,
  }) async {
    if (privilege != 0 && privilege != 14 && privilege != 2 && privilege != 6) {
      privilege = 0;
    }

    Uint8List commandString;

    if (userPacketSize == 28) {
      if (groupId.isEmpty) groupId = '0';

      final uidValue = uid ?? 0;
      final passwordPadded = password.padRight(5, '\x00').substring(0, 5);
      final namePadded = name.padRight(8, '\x00').substring(0, 8);
      final userIdValue = userId ?? (uid?.toString() ?? '0');

      final builder = BytesBuilder();

      final uidData = ByteData(2);
      uidData.setUint16(0, uidValue, Endian.little);
      builder.add(uidData.buffer.asUint8List());

      builder.add([privilege]);
      builder.add(passwordPadded.codeUnits);
      builder.add(namePadded.codeUnits);

      final cardData = ByteData(4);
      cardData.setUint32(0, card, Endian.little);
      builder.add(cardData.buffer.asUint8List());

      builder.add([0]);
      builder.add([int.parse(groupId)]);

      final tzData = ByteData(2);
      tzData.setUint16(0, 0, Endian.little);
      builder.add(tzData.buffer.asUint8List());

      final userIdData = ByteData(4);
      userIdData.setUint32(0, int.parse(userIdValue), Endian.little);
      builder.add(userIdData.buffer.asUint8List());

      commandString = builder.toBytes();
    } else {
      final uidValue = uid ?? 0;
      final passwordPadded = password.padRight(8, '\x00').substring(0, 8);
      final namePadded = name.padRight(24, '\x00').substring(0, 24);
      final groupIdPadded = groupId.padRight(7, '\x00').substring(0, 7);
      final userIdPadded = (userId ?? uid?.toString() ?? '')
          .padRight(24, '\x00')
          .substring(0, 24);

      final builder = BytesBuilder();

      final uidData = ByteData(2);
      uidData.setUint16(0, uidValue, Endian.little);
      builder.add(uidData.buffer.asUint8List());

      builder.add([privilege]);
      builder.add(passwordPadded.codeUnits);
      builder.add(namePadded.codeUnits);

      final cardData = ByteData(4);
      cardData.setUint32(0, card, Endian.little);
      builder.add(cardData.buffer.asUint8List());

      builder.add([0]);
      builder.add(groupIdPadded.codeUnits);
      builder.add([0]);
      builder.add(userIdPadded.codeUnits);

      commandString = builder.toBytes();
    }

    final response = await sendCommand(
      CMD_USER_WRQ,
      commandString: commandString,
    );
    final responseCode = parseHeader(response)[0];
    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("Can't set user");
    }
    await refreshData();
  }

  /// Deletes a user from the device.
  ///
  /// The user can be identified by either their [uid] or their [userId].
  /// One of the two must be provided.
  ///
  /// Throws [ZKErrorResponse] if the user is not found or the operation fails.
  Future<void> deleteUser({int? uid, String? userId}) async {
    if (uid == null && userId == null) {
      throw ZKErrorResponse("Either uid or userId must be provided");
    }

    if (uid == null) {
      final users = await getUsers();
      final matchedUsers = users.where((u) => u.userId == userId).toList();
      if (matchedUsers.isEmpty) {
        throw ZKErrorResponse("User not found");
      }
      uid = matchedUsers.first.uid;
    }

    final commandString = ByteData(2);
    commandString.setInt16(0, uid, Endian.little);
    final response = await sendCommand(
      CMD_DELETE_USER,
      commandString: commandString.buffer.asUint8List(),
    );
    final responseCode = parseHeader(response)[0];
    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("Can't delete user");
    }
    await refreshData();
  }
}
