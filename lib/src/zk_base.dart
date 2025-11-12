import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'zk_constants.dart';
import 'exceptions.dart';
import 'models/attendance.dart';
import 'models/user.dart';

class ZK {
  final String ip;
  final int port;
  final int timeout;
  final int password;
  final bool forceUdp;
  final bool ommitPing;

  Socket? _tcpSocket;
  StreamSubscription? _socketSubscription;
  bool isConnected = false;
  int _sessionId = 0;
  int _replyId = 0;

  // Device capacity info
  int usersCount = 0;
  int fingersCount = 0;
  int recordsCount = 0;
  int adminsCount = 0;
  int passwordsCount = 0;
  int fingersCapacity = 0;
  int usersCapacity = 0;
  int recordsCapacity = 0;
  int facesCount = 0;
  int facesCapacity = 0;
  int userPacketSize = 28; // Default for ZK6

  final Map<int, Completer<Uint8List>> _pendingReplies = {};
  final BytesBuilder _incomingBuffer = BytesBuilder();

  Uint8List _createHeader(
    int command,
    Uint8List commandString,
    int sessionId,
    int replyId,
  ) {
    final buf = BytesBuilder();
    final headerData = ByteData(8);
    headerData.setUint16(0, command, Endian.little);
    headerData.setUint16(2, 0, Endian.little); // Checksum placeholder
    headerData.setUint16(4, sessionId, Endian.little);
    headerData.setUint16(6, replyId, Endian.little);

    buf.add(headerData.buffer.asUint8List());
    buf.add(commandString);

    final fullPacket = buf.toBytes();
    final checksum = _createChecksum(fullPacket);

    // Replace placeholder with actual checksum
    fullPacket[2] = checksum[0];
    fullPacket[3] = checksum[1];

    return fullPacket;
  }

  Uint8List _createChecksum(Uint8List p) {
    int checksum = 0;
    for (int i = 0; i < p.length - (p.length % 2); i += 2) {
      checksum += (p[i + 1] << 8) | p[i];
      if (checksum > USHRT_MAX) {
        checksum -= USHRT_MAX;
      }
    }
    if (p.length % 2 == 1) {
      checksum += p.last;
    }
    while (checksum > USHRT_MAX) {
      checksum -= USHRT_MAX;
    }
    checksum = ~checksum & USHRT_MAX;

    final checksumBytes = ByteData(2);
    checksumBytes.setUint16(0, checksum, Endian.little);
    return checksumBytes.buffer.asUint8List();
  }

  Future<Uint8List> _sendCommand(
    int command, {
    Uint8List? commandString,
    bool bypassConnectionCheck = false,
  }) async {
    if (!isConnected && !bypassConnectionCheck) {
      throw ZKErrorConnection("Not connected");
    }
    commandString ??= Uint8List(0);

    _replyId = (_replyId + 1) % USHRT_MAX;
    final currentReplyId = _replyId;

    final header = _createHeader(
      command,
      commandString,
      _sessionId,
      currentReplyId,
    );

    final tcpHeader = ByteData(8);
    tcpHeader.setUint16(0, MACHINE_PREPARE_DATA_1, Endian.little);
    tcpHeader.setUint16(2, MACHINE_PREPARE_DATA_2, Endian.little);
    tcpHeader.setUint32(4, header.length, Endian.little);

    final packet = BytesBuilder();
    packet.add(tcpHeader.buffer.asUint8List());
    packet.add(header);

    final completer = Completer<Uint8List>();
    _pendingReplies[currentReplyId] = completer;

    try {
      if (_tcpSocket == null) {
        _pendingReplies.remove(currentReplyId);
        throw ZKErrorConnection("Socket is not available.");
      }
      _tcpSocket!.add(packet.toBytes());
    } catch (e) {
      _pendingReplies.remove(currentReplyId);
      throw ZKNetworkError("Failed to send command: $e");
    }

    return completer.future.timeout(
      Duration(seconds: timeout),
      onTimeout: () {
        _pendingReplies.remove(currentReplyId);
        throw ZKNetworkError("Command $command timed out.");
      },
    );
  }

  List<int> _parseHeader(Uint8List data) {
    if (data.length < 8)
      throw ZKErrorResponse("Invalid header length: ${data.length}");
    final headerData = ByteData.sublistView(data, 0, 8);
    return [
      headerData.getUint16(0, Endian.little), // command
      headerData.getUint16(2, Endian.little), // checksum
      headerData.getUint16(4, Endian.little), // session_id
      headerData.getUint16(6, Endian.little), // reply_id
    ];
  }

  // Updated _handleResponse to handle CMD_DATA responses better
  void _handleResponse(Uint8List data) {
    _incomingBuffer.add(data);

    while (true) {
      final buffer = _incomingBuffer.toBytes();
      if (buffer.length < 8) {
        break; // Not enough data for a TCP header
      }

      final tcpHeader = ByteData.sublistView(buffer, 0, 8);
      final magic1 = tcpHeader.getUint16(0, Endian.little);
      final magic2 = tcpHeader.getUint16(2, Endian.little);
      final payloadSize = tcpHeader.getUint32(4, Endian.little);

      if (magic1 != MACHINE_PREPARE_DATA_1 ||
          magic2 != MACHINE_PREPARE_DATA_2) {
        print("Error: Invalid TCP packet received. Clearing buffer.");
        _incomingBuffer.clear();
        break;
      }

      if (buffer.length < 8 + payloadSize) {
        break; // Not enough data for the full payload
      }

      final responsePayload = buffer.sublist(8, 8 + payloadSize);
      final header = _parseHeader(responsePayload);
      final replyId = header[3];
      final responseCode = header[0];

      // Handle both command replies and data packets
      if (_pendingReplies.containsKey(replyId)) {
        _pendingReplies[replyId]!.complete(responsePayload);
        _pendingReplies.remove(replyId);
      } else if (responseCode == CMD_DATA || responseCode == CMD_PREPARE_DATA) {
        // This might be a data packet for a chunk read
        // Store it for the next pending reply to pick up
        print("Received ${responseCode == CMD_DATA ? 'DATA' : 'PREPARE_DATA'} packet with replyId: $replyId");

        // Try to match with any pending reply (sometimes replyId doesn't match exactly)
        if (_pendingReplies.isNotEmpty) {
          final firstKey = _pendingReplies.keys.first;
          _pendingReplies[firstKey]!.complete(responsePayload);
          _pendingReplies.remove(firstKey);
        }
      } else {
        print("Received data for unknown replyId: $replyId, code: $responseCode");
      }

      // Remove the processed packet from the buffer
      final remainingBytes = buffer.sublist(8 + payloadSize);
      _incomingBuffer.clear();
      _incomingBuffer.add(remainingBytes);
    }
  }

  Future<void> _auth() async {
    final key = _makeCommandKey(password, _sessionId);
    final response = await _sendCommand(
      CMD_AUTH,
      commandString: key,
      bypassConnectionCheck: true,
    );
    final responseHeader = _parseHeader(response);
    final responseCode = responseHeader[0];

    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("Authentication failed with code: $responseCode");
    }
  }

  Uint8List _makeCommandKey(int key, int sessionId) {
    key = key.toUnsigned(32);
    sessionId = sessionId.toUnsigned(32);

    int k = 0;
    for (int i = 0; i < 32; i++) {
      if ((key & (1 << i)) != 0) {
        k = (k << 1) | 1;
      } else {
        k = k << 1;
      }
    }
    k += sessionId;

    var packedK = ByteData(4)..setUint32(0, k.toUnsigned(32), Endian.little);

    packedK.setUint8(0, packedK.getUint8(0) ^ 'Z'.codeUnitAt(0));
    packedK.setUint8(1, packedK.getUint8(1) ^ 'K'.codeUnitAt(0));
    packedK.setUint8(2, packedK.getUint8(2) ^ 'S'.codeUnitAt(0));
    packedK.setUint8(3, packedK.getUint8(3) ^ 'O'.codeUnitAt(0));

    int val1 = packedK.getUint16(0, Endian.little);
    int val2 = packedK.getUint16(2, Endian.little);

    var swappedK = ByteData(4);
    swappedK.setUint16(0, val2, Endian.little);
    swappedK.setUint16(2, val1, Endian.little);

    const int ticks = 50;
    final int b = 0xff & ticks;

    swappedK.setUint8(0, swappedK.getUint8(0) ^ b);
    swappedK.setUint8(1, swappedK.getUint8(1) ^ b);
    swappedK.setUint8(2, b);
    swappedK.setUint8(3, swappedK.getUint8(3) ^ b);

    return swappedK.buffer.asUint8List();
  }

  ZK(
    this.ip, {
    this.port = 4370,
    this.timeout = 60,
    this.password = 0,
    this.forceUdp = false,
    this.ommitPing = false,
  });

  Future<void> connect() async {
    if (isConnected) {
      return;
    }
    try {
      if (!forceUdp) {
        _tcpSocket = await Socket.connect(
          ip,
          port,
          timeout: Duration(seconds: timeout),
        );
        _socketSubscription = _tcpSocket!.listen(
          _handleResponse,
          onError: (error) {
            if (isConnected) {
              print("Socket error: $error");
              disconnect();
            }
          },
          onDone: () {
            if (isConnected) {
              print("Socket closed by remote");
              disconnect();
            }
          },
        );

        _replyId = USHRT_MAX - 1;

        // Special case for CMD_CONNECT, send without being "connected"
        final connectResponse = await _sendCommand(
          CMD_CONNECT,
          bypassConnectionCheck: true,
        );
        final responseHeader = _parseHeader(connectResponse);
        _sessionId = responseHeader[2];
        final responseCode = responseHeader[0];

        if (responseCode == CMD_ACK_UNAUTH) {
          await _auth();
        } else if (responseCode != CMD_ACK_OK) {
          throw ZKErrorResponse(
            "Unexpected response to connect command: $responseCode",
          );
        }

        isConnected = true;
        userPacketSize = 72; // Default for ZK8/TCP
      } else {
        throw UnimplementedError("UDP connection is not yet supported.");
      }
    } catch (e) {
      await disconnect();
      throw ZKNetworkError("Failed to connect to device: $e");
    }
  }

  Future<void> disconnect() async {
    if (!isConnected && _tcpSocket == null)
      return; // Already disconnected or never connected

    // Prevent re-entrancy
    if (!isConnected) return;
    isConnected = false; // Set immediately to prevent race conditions

    try {
      await _sendCommand(CMD_EXIT, bypassConnectionCheck: true);
    } catch (e) {
      throw ZKErrorConnection("Failed to disconnect: $e");
    } finally {
      await _socketSubscription?.cancel();
      _tcpSocket?.destroy();
      _tcpSocket = null;
      _socketSubscription = null;
      _pendingReplies.clear();
      _incomingBuffer.clear();
    }
  }

  Future<String> getFirmwareVersion() async {
    final response = await _sendCommand(CMD_GET_VERSION);
    final data = response.sublist(8);
    return _decodeString(data);
  }

  Future<String> getSerialNumber() async {
    final commandString = Uint8List.fromList('~SerialNumber\x00'.codeUnits);
    final response = await _sendCommand(
      CMD_OPTIONS_RRQ,
      commandString: commandString,
    );
    final dataString = _decodeString(response.sublist(8));
    final parts = dataString.split('=');
    if (parts.length > 1) {
      return parts[1];
    }
    return "";
  }

  Future<DateTime> getTime() async {
    final response = await _sendCommand(CMD_GET_TIME);
    final data = ByteData.sublistView(response, 8);
    final t = data.getUint32(0, Endian.little);

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

  Future<void> readSizes() async {
    final response = await _sendCommand(CMD_GET_FREE_SIZES);
    final responseCode = _parseHeader(response)[0];
    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("readSizes failed with code $responseCode");
    }
    var data = ByteData.sublistView(response, 8);
    if (data.lengthInBytes >= 80) {
      usersCapacity = data.getInt32(15 * 4, Endian.little); // 5000
      usersCount = data.getInt32(4 * 4, Endian.little); // 35
      fingersCapacity = data.getInt32(14 * 4, Endian.little); // 3000
      fingersCount = data.getInt32(6 * 4, Endian.little); // 69
      recordsCapacity = data.getInt32(16 * 4, Endian.little); // 100000
      recordsCount = data.getInt32(8 * 4, Endian.little); // 780
      passwordsCount = data.getInt32(12 * 4, Endian.little); // 3
      adminsCount = data.getInt32(10 * 4, Endian.little); // 8163
      data = ByteData.sublistView(response, 8 + 80);
    }
    if (data.lengthInBytes >= 12) {
      facesCount = data.getInt32(0, Endian.little);
      facesCapacity = data.getInt32(8, Endian.little);
    }
  }

  Future<void> freeData() async {
    final response = await _sendCommand(CMD_FREE_DATA);
    final responseCode = _parseHeader(response)[0];
    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("freeData failed with code $responseCode");
    }
  }

  // Future<Uint8List> _readChunk(int start, int size) async {
  //   final commandString = ByteData(8);
  //   commandString.setInt32(0, start, Endian.little);
  //   commandString.setInt32(4, size, Endian.little);
  //
  //
  //   final response = await _sendCommand(
  //     1504,
  //     commandString: commandString.buffer.asUint8List(),
  //   );
  //   final responseCode = _parseHeader(response)[0];
  //
  //   if (responseCode == CMD_DATA) {
  //     return response.sublist(8);
  //   }
  //   // This is a fallback for devices that might behave differently
  //   if (response.length > 8) {
  //     return response.sublist(8);
  //   }
  //   throw ZKErrorResponse("Failed to read chunk at $start");
  // }


  // Corrected _readChunk method
  // Completely rewritten _readChunk
  Future<Uint8List> _readChunk(int start, int size) async {
    final commandString = ByteData(8);
    commandString.setInt32(0, start, Endian.little);
    commandString.setInt32(4, size, Endian.little);

    print("_readChunk: Requesting $size bytes from offset $start");

    final response = await _sendCommand(
      1504, // CMD_READ_BUFFER_CHUNK
      commandString: commandString.buffer.asUint8List(),
    );

    final header = _parseHeader(response);
    final responseCode = header[0];

    print("_readChunk: Response code: $responseCode, response length: ${response.length}");

    if (responseCode == CMD_DATA) {
      // Data is in the response after the 8-byte header
      final data = response.sublist(8);
      print("_readChunk: Returning ${data.length} bytes");
      return data;
    } else if (responseCode == CMD_PREPARE_DATA) {
      // The device is telling us data is coming
      // We need to wait for the actual CMD_DATA packet
      print("_readChunk: Got PREPARE_DATA, waiting for DATA packet...");

      // The next packet should be CMD_DATA
      // Wait for it with a new completer
      final dataCompleter = Completer<Uint8List>();

      // Set up a temporary listener for the next packet
      _replyId = (_replyId + 1) % USHRT_MAX;
      _pendingReplies[_replyId] = dataCompleter;

      try {
        final dataResponse = await dataCompleter.future.timeout(
          Duration(seconds: timeout),
          onTimeout: () {
            _pendingReplies.remove(_replyId);
            throw ZKNetworkError("Timeout waiting for DATA packet");
          },
        );

        final dataHeader = _parseHeader(dataResponse);
        final dataCode = dataHeader[0];

        if (dataCode == CMD_DATA) {
          final data = dataResponse.sublist(8);
          print("_readChunk: Received DATA packet with ${data.length} bytes");
          return data;
        } else {
          throw ZKErrorResponse("Expected CMD_DATA, got: $dataCode");
        }
      } catch (e) {
        print("_readChunk error: $e");
        rethrow;
      }
    } else if (responseCode == CMD_ACK_OK) {
      // Sometimes we get ACK_OK with embedded data
      final data = response.sublist(8);
      print("_readChunk: Got ACK_OK with ${data.length} bytes");
      return data;
    }

    throw ZKErrorResponse("Unexpected response code in _readChunk: $responseCode");
  }


  // Future<Uint8List> readWithBuffer(int command, {int fct = 0, int ext = 0}) async {
  //   final int maxChunk = 0xFFC0; // 65472 bytes
  //
  //   // python pack('<bhii', 1, command, fct, ext) -> 11 bytes
  //   final commandString = ByteData(11);
  //   commandString.setUint8(0, 1);
  //   commandString.setUint16(1, command, Endian.little);
  //   commandString.setInt32(3, fct, Endian.little);
  //   commandString.setInt32(7, ext, Endian.little);
  //
  //   final response = await _sendCommand(
  //     1503,
  //     commandString: commandString.buffer.asUint8List(),
  //   );
  //   final responseCode = _parseHeader(response)[0];
  //   final responseData = response.sublist(8);
  //
  //   if (responseCode == CMD_DATA) {
  //     return responseData;
  //   }
  //
  //   final size = ByteData.sublistView(
  //     responseData,
  //     1,
  //     5,
  //   ).getUint32(0, Endian.little);
  //   if (size == 0) return Uint8List(0);
  //
  //   final allData = BytesBuilder();
  //   int start = 0;
  //
  //   while (start < size) {
  //     final chunkSize = (size - start) > maxChunk ? maxChunk : (size - start);
  //     // final chunkSize = 80;
  //     final chunk = await _readChunk(start, chunkSize);
  //     allData.add(chunk);
  //     start += chunk.length; // Use actual chunk length
  //   }
  //
  //   await freeData();
  //   return allData.toBytes();
  // }

  // Add this helper method to safely decode strings with error handling


  /// Updated readWithBuffer
  Future<Uint8List> readWithBuffer(
      int command, {
        int fct = 0,
        int ext = 0,
      }) async {

    var maxChunk = 65472; // 65472 bytes for TCP

    // Pack: <bhii = 1 byte + 2 bytes + 4 bytes + 4 bytes = 11 bytes
    final commandString = ByteData(11);
    commandString.setUint8(0, 1);
    commandString.setUint16(1, command, Endian.little);
    commandString.setInt32(3, fct, Endian.little);
    commandString.setInt32(7, ext, Endian.little);

    print("readWithBuffer: Sending command $command with fct=$fct, ext=$ext");

    final response = await _sendCommand(
      1503, // CMD_DATA_WRRQ
      commandString: commandString.buffer.asUint8List(),
    );

    final header = _parseHeader(response);
    final responseCode = header[0];
    final responseData = response.sublist(8);

    print("readWithBuffer: Response code: $responseCode, data length: ${responseData.length}");

    // If we get CMD_DATA directly, return it
    if (responseCode == CMD_DATA) {
      print("readWithBuffer: Received data directly (${responseData.length} bytes)");
      return responseData;
    }

    // Read size from bytes 1-4 of responseData (skip first byte)
    if (responseData.length < 5) {
      print("readWithBuffer: Response too short: ${responseData.length} bytes");
      print("Response hex: ${responseData.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}");
      throw ZKErrorResponse("Response data too short");
    }

    final size = ByteData.sublistView(responseData, 1, 5).getUint32(0, Endian.little);

    if (size == 0) {
      print("readWithBuffer: Size is 0, returning empty");
      return Uint8List(0);
    }

    print("readWithBuffer: Total size to read: $size bytes");

    // Calculate chunks
    final remain = size % maxChunk;
    final packets = (size - remain) ~/ maxChunk;

    print("readWithBuffer: Need $packets chunks of $maxChunk + $remain remainder");

    final allData = BytesBuilder();
    int start = 0;
    int totalRead = 0;

    // Read full chunks
    for (int i = 0; i < packets; i++) {
      print("readWithBuffer: Reading chunk ${i + 1}/$packets");
      final chunk = await _readChunk(start, maxChunk);
      allData.add(chunk);
      totalRead += chunk.length;
      start += chunk.length; // Use actual chunk length
      print("readWithBuffer: Read ${chunk.length} bytes, total: $totalRead/$size");
    }

    // Read remainder
    if (remain > 0) {
      print("readWithBuffer: Reading final $remain bytes");
      final chunk = await _readChunk(start, remain);
      allData.add(chunk);
      start += remain;
      totalRead += chunk.length;
      print("readWithBuffer: Read ${chunk.length} bytes, total: $totalRead/$size");
    }

    await freeData();

    final finalData = allData.toBytes();
    print("readWithBuffer: Complete! Read ${finalData.length} bytes");

    return finalData;
  }

  String _decodeString(Uint8List data, {Encoding encoding = utf8}) {
    try {
      final nullPos = data.indexOf(0);
      final endPos = nullPos > -1 ? nullPos : data.length;

      // Filter out any invalid bytes before decoding
      final validData = data.sublist(0, endPos);

      return encoding.decode(validData).trim();
    } catch (e) {
      print("Error decoding string: $e, bytes: $data");
      return "";
    }
  }

  // Updated getUsers (same as before but with better error handling)
  Future<List<User>> getUsers() async {
    await readSizes();

    if (usersCount == 0) {
      print("No users found on device");
      return [];
    }

    print("Device reports $usersCount users");

    final userData = await readWithBuffer(CMD_USERTEMP_RRQ, fct: FCT_USER);

    print("Received user data: ${userData.length} bytes");

    if (userData.length <= 4) {
      print("Warning: Insufficient user data");
      return [];
    }

    // First 4 bytes = total size
    final totalSize = ByteData.sublistView(userData, 0, 4).getUint32(0, Endian.little);

    print("Total size from header: $totalSize bytes");
    print("Buffer length: ${userData.length} bytes");

    if (totalSize == 0) {
      return [];
    }

    // Determine packet size
    final calculatedPacketSize = totalSize / usersCount;

    if ((calculatedPacketSize - 28).abs() < 1.0) {
      userPacketSize = 28;
    } else if ((calculatedPacketSize - 72).abs() < 1.0) {
      userPacketSize = 72;
    } else {
      print("Warning: Unusual packet size: $calculatedPacketSize");
      userPacketSize = 72;
    }

    print("Packet size: $userPacketSize bytes per user");

    // Verify we have enough data
    final expectedDataSize = 4 + (usersCount * userPacketSize);
    if (userData.length < expectedDataSize) {
      print("ERROR: Not enough data! Expected $expectedDataSize, got ${userData.length}");
      print("This means chunk reading failed.");
      return [];
    }

    final users = <User>[];
    var offset = 4;

    for (int i = 0; i < usersCount; i++) {
      if (offset + userPacketSize > userData.length) {
        print("Ran out of data at user $i (offset $offset)");
        break;
      }

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

          final password = _decodeString(passwordBytes);
          final name = _decodeString(nameBytes);

          if (i < 3) {
            print("User $i: uid=$uid, name='$name', userId=$userId");
          }

          users.add(User(
            uid: uid,
            privilege: privilege,
            password: password,
            name: name.isNotEmpty ? name : "NN-$userId",
            card: card,
            groupId: groupId,
            userId: userId,
          ));
        } else {
          final uid = byteData.getUint16(0, Endian.little);
          final privilege = byteData.getUint8(2);
          final passwordBytes = userChunk.sublist(3, 11);
          final nameBytes = userChunk.sublist(11, 35);
          final card = byteData.getUint32(35, Endian.little);
          final groupIdBytes = userChunk.sublist(40, 47);
          final userIdBytes = userChunk.sublist(48, 72);

          final password = _decodeString(passwordBytes);
          final name = _decodeString(nameBytes);
          final groupId = _decodeString(groupIdBytes);
          final userId = _decodeString(userIdBytes);

          if (i < 3) {
            print("User $i: uid=$uid, name='$name', userId='$userId'");
          }

          users.add(User(
            uid: uid,
            privilege: privilege,
            password: password,
            name: name.isNotEmpty ? name : "NN-$userId",
            card: card,
            groupId: groupId,
            userId: userId.isNotEmpty ? userId : uid.toString(),
          ));
        }
      } catch (e) {
        print("Error parsing user $i: $e");
      }

      offset += userPacketSize;
    }

    print("Successfully parsed ${users.length} users");
    return users;
  }

  Future<List<Attendance>> getAttendance() async {
    // This command also uses buffered data transfer, which is complex.
    final response = await _sendCommand(CMD_ATTLOG_RRQ);
    final data = response.sublist(8);

    if (_parseHeader(response)[0] != CMD_PREPARE_DATA) {
      throw ZKErrorResponse("Failed to prepare data for attendance records.");
    }

    // The data following PREPARE_DATA contains the size of the total attendance log.
    final totalSize = ByteData.sublistView(data).getUint32(0, Endian.little);
    if (totalSize == 0) return [];

    // The logic to read all the data chunks would go here.
    // It involves sending CMD_DATA commands until all bytes are received.
    // This is a simplified example.

    print(
      "Fetching attendance is a complex buffered operation. This is a placeholder.",
    );
    return [];
  }
}
