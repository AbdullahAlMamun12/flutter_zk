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

  // Add a special completer for data packets
  Completer<Uint8List>? _dataPacketCompleter;

  ZK(
      this.ip, {
        this.port = 4370,
        this.timeout = 10,
        this.password = 0,
        this.forceUdp = false,
        this.ommitPing = false,
      });

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

  // FIXED: Better response handling with proper CMD_DATA detection
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

      print("Received packet - Code: $responseCode, ReplyId: $replyId, PayloadSize: $payloadSize");

      // Handle CMD_DATA packets - check if we have a data completer waiting
      if (responseCode == CMD_DATA && _dataPacketCompleter != null && !_dataPacketCompleter!.isCompleted) {
        print("Completing data packet completer with ${responsePayload.length} bytes");
        _dataPacketCompleter!.complete(responsePayload);
        // Don't set to null here - let the _readChunk method handle it
      }
      // Handle regular command responses
      else if (_pendingReplies.containsKey(replyId)) {
        _pendingReplies[replyId]!.complete(responsePayload);
        _pendingReplies.remove(replyId);
      }
      // Handle responses that might have wrong reply ID
      else if (_pendingReplies.isNotEmpty) {
        print("Warning: ReplyId mismatch. Expected one of ${_pendingReplies.keys}, got $replyId");
        final firstKey = _pendingReplies.keys.first;
        _pendingReplies[firstKey]!.complete(responsePayload);
        _pendingReplies.remove(firstKey);
      } else {
        print("Warning: Received response with no pending completer - Code: $responseCode, ReplyId: $replyId");
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
    if (!isConnected && _tcpSocket == null) return;

    if (!isConnected) return;
    isConnected = false;

    try {
      await _sendCommand(CMD_EXIT, bypassConnectionCheck: true);
    } catch (e) {
      print("Error during disconnect: $e");
    } finally {
      await _socketSubscription?.cancel();
      _tcpSocket?.destroy();
      _tcpSocket = null;
      _socketSubscription = null;
      _pendingReplies.clear();
      _incomingBuffer.clear();
      _dataPacketCompleter = null;
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
      usersCapacity = data.getInt32(15 * 4, Endian.little);
      usersCount = data.getInt32(4 * 4, Endian.little);
      fingersCapacity = data.getInt32(14 * 4, Endian.little);
      fingersCount = data.getInt32(6 * 4, Endian.little);
      recordsCapacity = data.getInt32(16 * 4, Endian.little);
      recordsCount = data.getInt32(8 * 4, Endian.little);
      passwordsCount = data.getInt32(12 * 4, Endian.little);
      adminsCount = data.getInt32(10 * 4, Endian.little);
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

  // FIXED: Completely rewritten _readChunk
  Future<Uint8List> _readChunk(int start, int size) async {
    final commandString = ByteData(8);
    commandString.setInt32(0, start, Endian.little);
    commandString.setInt32(4, size, Endian.little);

    print("_readChunk: Requesting $size bytes from offset $start");

    // Set up the data packet completer BEFORE sending the command
    _dataPacketCompleter = Completer<Uint8List>();
    final localCompleter = _dataPacketCompleter!; // Keep local reference

    final response = await _sendCommand(
      1504, // CMD_READ_BUFFER_CHUNK
      commandString: commandString.buffer.asUint8List(),
    );

    final header = _parseHeader(response);
    final responseCode = header[0];

    print("_readChunk: Initial response code: $responseCode");

    if (responseCode == CMD_DATA) {
      // Data is directly in the response
      final data = response.sublist(8);
      print("_readChunk: Got data directly (${data.length} bytes)");
      _dataPacketCompleter = null;
      return data;
    } else if (responseCode == CMD_PREPARE_DATA) {
      // Device is preparing to send data, wait for CMD_DATA packet
      print("_readChunk: Got PREPARE_DATA, waiting for CMD_DATA...");

      try {
        // Use local reference to avoid null issue
        final dataResponse = await localCompleter.future.timeout(
          Duration(seconds: timeout + 5),
          onTimeout: () {
            _dataPacketCompleter = null;
            throw ZKNetworkError("Timeout waiting for CMD_DATA packet");
          },
        );

        _dataPacketCompleter = null; // Clear after successful completion

        final dataHeader = _parseHeader(dataResponse);
        final dataCode = dataHeader[0];

        if (dataCode == CMD_DATA) {
          final data = dataResponse.sublist(8);
          print("_readChunk: Received CMD_DATA with ${data.length} bytes");
          return data;
        } else {
          throw ZKErrorResponse("Expected CMD_DATA, got: $dataCode");
        }
      } catch (e) {
        _dataPacketCompleter = null;
        print("_readChunk error: $e");
        rethrow;
      }
    } else if (responseCode == CMD_ACK_OK) {
      // Some devices send ACK_OK with embedded data
      final data = response.sublist(8);
      print("_readChunk: Got ACK_OK with ${data.length} bytes");
      _dataPacketCompleter = null;
      return data;
    }

    _dataPacketCompleter = null;
    throw ZKErrorResponse("Unexpected response code in _readChunk: $responseCode");
  }

  // FIXED: Improved readWithBuffer
  Future<Uint8List> _readWithBuffer(
      int command, {
        int fct = 0,
        int ext = 0,
      }) async {
    const maxChunk = 65472; // 0xFFC0 for TCP

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

    // Read size from bytes 1-4 of responseData
    if (responseData.length < 5) {
      print("readWithBuffer: Response too short: ${responseData.length} bytes");
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

    print("readWithBuffer: Need $packets full chunks + $remain remainder bytes");

    final allData = BytesBuilder();
    int start = 0;

    // Read full chunks
    for (int i = 0; i < packets; i++) {
      print("readWithBuffer: Reading chunk ${i + 1}/$packets (offset: $start, size: $maxChunk)");
      final chunk = await _readChunk(start, maxChunk);
      allData.add(chunk);
      start += chunk.length;
      print("readWithBuffer: Chunk ${i + 1} complete, read ${chunk.length} bytes, total: $start/$size");

      // Small delay between chunks to avoid overwhelming the device
      await Future.delayed(Duration(milliseconds: 10));
    }

    // Read remainder
    if (remain > 0) {
      print("readWithBuffer: Reading final chunk (offset: $start, size: $remain)");
      final chunk = await _readChunk(start, remain);
      allData.add(chunk);
      start += chunk.length;
      print("readWithBuffer: Final chunk complete, read ${chunk.length} bytes, total: $start/$size");
    }

    await freeData();

    final finalData = allData.toBytes();
    print("readWithBuffer: Complete! Total bytes read: ${finalData.length}");

    return finalData;
  }

  String _decodeString(Uint8List data, {Encoding encoding = utf8}) {
    try {
      final nullPos = data.indexOf(0);
      final endPos = nullPos > -1 ? nullPos : data.length;
      final validData = data.sublist(0, endPos);
      return encoding.decode(validData).trim();
    } catch (e) {
      print("Error decoding string: $e");
      return "";
    }
  }

  Future<List<User>> getUsers() async {
    await readSizes();

    if (usersCount == 0) {
      print("No users found on device");
      return [];
    }

    print("Device reports $usersCount users");

    final userData = await _readWithBuffer(CMD_USERTEMP_RRQ, fct: FCT_USER);

    print("Received user data: ${userData.length} bytes");

    if (userData.length <= 4) {
      print("Warning: Insufficient user data");
      return [];
    }

    final totalSize = ByteData.sublistView(userData, 0, 4).getUint32(0, Endian.little);
    print("Total size from header: $totalSize bytes");

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
      print("Warning: Unusual packet size: $calculatedPacketSize, using 72");
      userPacketSize = 72;
    }

    print("Using packet size: $userPacketSize bytes per user");

    final users = <User>[];
    var offset = 4;

    for (int i = 0; i < usersCount && offset + userPacketSize <= userData.length; i++) {
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

  Future<List<Attendance>> getAttendance({DateTime? fromDate, DateTime? toDate, String sort = 'desc'}) async {
    await readSizes();

    if (recordsCount == 0) {
      print("No attendance records found on device");
      return [];
    }


    final attendanceData = await _readWithBuffer(CMD_ATTLOG_RRQ);

    print("Received attendance data: ${attendanceData.length} bytes");

    if (attendanceData.length <= 4) {
      print("Warning: Insufficient attendance data");
      return [];
    }

    final totalSize = ByteData.sublistView(attendanceData, 0, 4).getUint32(0, Endian.little);
    print("Total size from header: $totalSize bytes");

    if (totalSize == 0) {
      return [];
    }

    // Determine record size
    final recordSize = totalSize / recordsCount;
    print("Record size: $recordSize bytes per record");

    var attendances = <Attendance>[];
    var offset = 4;

    // Parse based on record size
    if (recordSize == 8) {
      // Format: uid(2), status(1), timestamp(4), punch(1)
      while (offset + 8 <= attendanceData.length) {
        final byteData = ByteData.sublistView(attendanceData, offset);
        final uid = byteData.getUint16(0, Endian.little);
        final status = byteData.getUint8(2);
        final timestamp = _decodeTime(byteData.getUint32(3, Endian.little));
        final punch = byteData.getUint8(7);

        attendances.add(Attendance(
          userId: uid.toString(),
          timestamp: timestamp,
          status: status,
          punch: punch,
          uid: uid,
        ));

        offset += 8;
      }
    } else if (recordSize == 16) {
      // Format: userId(4), timestamp(4), status(1), punch(1), reserved(2), workcode(4)
      while (offset + 16 <= attendanceData.length) {
        final byteData = ByteData.sublistView(attendanceData, offset);
        final userId = byteData.getUint32(0, Endian.little).toString();
        final timestamp = _decodeTime(byteData.getUint32(4, Endian.little));
        final status = byteData.getUint8(8);
        final punch = byteData.getUint8(9);

        attendances.add(Attendance(
          userId: userId,
          timestamp: timestamp,
          status: status,
          punch: punch,
          uid: int.tryParse(userId) ?? 0,
        ));

        offset += 16;
      }
    } else {
      // Format: uid(2), userId(24), status(1), timestamp(4), punch(1), space(8)
      while (offset + 40 <= attendanceData.length) {
        final byteData = ByteData.sublistView(attendanceData, offset);
        final uid = byteData.getUint16(0, Endian.little);
        final userIdBytes = attendanceData.sublist(offset + 2, offset + 26);
        final userId = _decodeString(userIdBytes);
        final status = byteData.getUint8(26);
        final timestamp = _decodeTime(byteData.getUint32(27, Endian.little));
        final punch = byteData.getUint8(31);

        attendances.add(Attendance(
          userId: userId.isNotEmpty ? userId : uid.toString(),
          timestamp: timestamp,
          status: status,
          punch: punch,
          uid: uid,
        ));

        offset += 40;
      }
    }

    print("Successfully parsed ${attendances.length} attendance records");

    // Default values for date filtering
    final now = DateTime.now();
    fromDate ??= DateTime(now.year, now.month, 1);
    toDate ??= now;

    // Filtering
    final normalizedFromDate = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final normalizedToDate = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59, 999);

    var filteredAttendances = attendances.where((att) {
      final isAfterFrom = !att.timestamp.isBefore(normalizedFromDate);
      final isBeforeTo = !att.timestamp.isAfter(normalizedToDate);
      return isAfterFrom && isBeforeTo;
    }).toList();

    // Sorting
    if (sort.toLowerCase() == 'asc') {
      filteredAttendances.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } else if (sort.toLowerCase() == 'dsc' || sort.toLowerCase() == 'desc') {
      filteredAttendances.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return filteredAttendances;
  }

  DateTime _decodeTime(int t) {
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
}
