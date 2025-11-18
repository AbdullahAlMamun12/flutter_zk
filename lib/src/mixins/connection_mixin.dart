import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../zk_constants.dart';
import '../exceptions.dart';
import '../utils/logger.dart';

/// Handles the low-level TCP/IP connection and communication with the ZKTeco device.
mixin ConnectionMixin {
  // Abstract properties that must be provided by the implementing class

  /// The IP address of the ZKTeco device.
  String get ip;

  /// The port number for the device connection.
  int get port;

  /// The connection timeout in seconds.
  int get timeout;

  /// The device's communication password.
  int get password;

  /// Whether to force UDP communication (not yet supported).
  bool get forceUdp;

  // Connection state

  /// The underlying TCP socket for communication.
  Socket? tcpSocket;

  /// The subscription to the socket's stream of data.
  StreamSubscription? socketSubscription;

  /// Whether the device is currently connected.
  bool isConnected = false;

  /// The session ID assigned by the device upon connection.
  int sessionId = 0;

  /// The reply ID used to track command-response pairs.
  int replyId = 0;

  // Device capacity info

  /// The number of users currently stored on the device.
  int usersCount = 0;

  /// The number of fingerprint templates stored on the device.
  int fingersCount = 0;

  /// The number of attendance records stored on the device.
  int recordsCount = 0;

  /// The number of administrators registered on the device.
  int adminsCount = 0;

  /// The number of passwords stored on the device.
  int passwordsCount = 0;

  /// The maximum number of fingerprint templates the device can store.
  int fingersCapacity = 0;

  /// The maximum number of users the device can store.
  int usersCapacity = 0;

  /// The maximum number of attendance records the device can store.
  int recordsCapacity = 0;

  /// The number of face templates stored on the device.
  int facesCount = 0;

  /// The maximum number of face templates the device can store.
  int facesCapacity = 0;

  /// The size of the user data packet.
  int userPacketSize = 28;

  // Network buffers

  /// A map of pending replies, keyed by reply ID.
  final Map<int, Completer<Uint8List>> pendingReplies = {};

  /// A buffer for incoming data from the socket.
  final BytesBuilder incomingBuffer = BytesBuilder();

  /// A completer for handling large data packets.
  Completer<Uint8List>? dataPacketCompleter;

  /// Establishes a connection to the ZKTeco device.
  ///
  /// This method initiates a TCP connection, performs authentication if necessary,
  /// and sets up the device for communication.
  ///
  /// Throws [ZKNetworkError] if the connection fails.
  /// Throws [ZKErrorResponse] if the device returns an unexpected response.
  Future<void> connect() async {
    if (isConnected) {
      return;
    }
    try {
      if (!forceUdp) {
        tcpSocket = await Socket.connect(
          ip,
          port,
          timeout: Duration(seconds: timeout),
        );
        socketSubscription = tcpSocket!.listen(
          handleResponse,
          onError: (error) {
            if (isConnected) {
              debugLog("Socket error: $error");
              disconnect();
            }
          },
          onDone: () {
            if (isConnected) {
              debugLog("Socket closed by remote");
              disconnect();
            }
          },
        );

        replyId = USHRT_MAX - 1;

        final connectResponse = await sendCommand(
          CMD_CONNECT,
          bypassConnectionCheck: true,
        );
        final responseHeader = parseHeader(connectResponse);
        sessionId = responseHeader[2];
        final responseCode = responseHeader[0];

        if (responseCode == CMD_ACK_UNAUTH) {
          await auth();
        } else if (responseCode != CMD_ACK_OK) {
          throw ZKErrorResponse(
            "Unexpected response to connect command: $responseCode",
          );
        }

        isConnected = true;
        userPacketSize = 72;
      } else {
        throw UnimplementedError("UDP connection is not yet supported.");
      }
    } catch (e) {
      await disconnect();
      throw ZKNetworkError("Failed to connect to device: $e");
    }
  }

  /// Disconnects from the ZKTeco device.
  ///
  /// This method sends a disconnect command to the device and closes the
  /// underlying socket connection.
  Future<void> disconnect() async {
    if (!isConnected && tcpSocket == null) return;
    if (!isConnected) return;
    isConnected = false;

    try {
      await sendCommand(CMD_EXIT, bypassConnectionCheck: true);
    } catch (e) {
      debugLog("Error during disconnect: $e");
    } finally {
      await socketSubscription?.cancel();
      tcpSocket?.destroy();
      tcpSocket = null;
      socketSubscription = null;
      pendingReplies.clear();
      incomingBuffer.clear();
      dataPacketCompleter = null;
    }
  }

  /// Authenticates with the device using the provided password.
  ///
  /// This method is called automatically during the connection process if
  /// the device requires authentication.
  ///
  /// Throws [ZKErrorResponse] if authentication fails.
  Future<void> auth() async {
    final key = makeCommandKey(password, sessionId);
    final response = await sendCommand(
      CMD_AUTH,
      commandString: key,
      bypassConnectionCheck: true,
    );
    final responseHeader = parseHeader(response);
    final responseCode = responseHeader[0];

    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("Authentication failed with code: $responseCode");
    }
  }

  /// Creates the authentication key for the `auth` command.
  /// (Internal use only)
  Uint8List makeCommandKey(int key, int sessionId) {
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

  /// Creates the 8-byte header for a command packet.
  /// (Internal use only)
  Uint8List createHeader(
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
    final checksum = createChecksum(fullPacket);

    fullPacket[2] = checksum[0];
    fullPacket[3] = checksum[1];

    return fullPacket;
  }

  /// Calculates the checksum for a command packet.
  /// (Internal use only)
  Uint8List createChecksum(Uint8List p) {
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

  /// Sends a command to the device and waits for a reply.
  ///
  /// [command] The command code to send.
  /// [commandString] The optional command data payload.
  /// [bypassConnectionCheck] Whether to bypass the connection check (for internal use).
  ///
  /// Returns the full response payload from the device.
  ///
  /// Throws [ZKErrorConnection] if not connected.
  /// Throws [ZKNetworkError] if the command times out or fails to send.
  Future<Uint8List> sendCommand(
    int command, {
    Uint8List? commandString,
    bool bypassConnectionCheck = false,
  }) async {
    if (!isConnected && !bypassConnectionCheck) {
      throw ZKErrorConnection("Not connected");
    }
    commandString ??= Uint8List(0);

    replyId = (replyId + 1) % USHRT_MAX;
    final currentReplyId = replyId;

    final header = createHeader(
      command,
      commandString,
      sessionId,
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
    pendingReplies[currentReplyId] = completer;

    try {
      if (tcpSocket == null) {
        pendingReplies.remove(currentReplyId);
        throw ZKErrorConnection("Socket is not available.");
      }
      tcpSocket!.add(packet.toBytes());
    } catch (e) {
      pendingReplies.remove(currentReplyId);
      throw ZKNetworkError("Failed to send command: $e");
    }

    return completer.future.timeout(
      Duration(seconds: timeout),
      onTimeout: () {
        pendingReplies.remove(currentReplyId);
        throw ZKNetworkError("Command $command timed out.");
      },
    );
  }

  /// Parses the 8-byte header from a response packet.
  /// (Internal use only)
  List<int> parseHeader(Uint8List data) {
    if (data.length < 8) {
      throw ZKErrorResponse("Invalid header length: ${data.length}");
    }
    final headerData = ByteData.sublistView(data, 0, 8);
    return [
      headerData.getUint16(0, Endian.little), // command
      headerData.getUint16(2, Endian.little), // checksum
      headerData.getUint16(4, Endian.little), // session id
      headerData.getUint16(6, Endian.little), // reply id
    ];
  }

  /// Handles incoming data from the TCP socket.
  ///
  /// This method parses incoming packets, matches them with pending commands,
  /// and completes the corresponding futures.
  /// (Internal use only)
  void handleResponse(Uint8List data) {
    incomingBuffer.add(data);

    while (true) {
      final buffer = incomingBuffer.toBytes();
      if (buffer.length < 8) break;

      final tcpHeader = ByteData.sublistView(buffer, 0, 8);
      final magic1 = tcpHeader.getUint16(0, Endian.little);
      final magic2 = tcpHeader.getUint16(2, Endian.little);
      final payloadSize = tcpHeader.getUint32(4, Endian.little);

      if (magic1 != MACHINE_PREPARE_DATA_1 ||
          magic2 != MACHINE_PREPARE_DATA_2) {
        debugLog("Error: Invalid TCP packet received. Clearing buffer.");
        incomingBuffer.clear();
        break;
      }

      if (buffer.length < 8 + payloadSize) break;

      final responsePayload = buffer.sublist(8, 8 + payloadSize);
      final header = parseHeader(responsePayload);
      final replyId = header[3];
      final responseCode = header[0];

      debugLog(
        "Received packet - Code: $responseCode, ReplyId: $replyId, PayloadSize: $payloadSize",
      );

      if (responseCode == CMD_DATA &&
          dataPacketCompleter != null &&
          !dataPacketCompleter!.isCompleted) {
        debugLog(
          "Completing data packet completer with ${responsePayload.length} bytes",
        );
        dataPacketCompleter!.complete(responsePayload);
      } else if (pendingReplies.containsKey(replyId)) {
        pendingReplies[replyId]!.complete(responsePayload);
        pendingReplies.remove(replyId);
      } else if (pendingReplies.isNotEmpty) {
        debugLog(
          "Warning: ReplyId mismatch. Expected one of ${pendingReplies.keys}, got $replyId",
        );
        final firstKey = pendingReplies.keys.first;
        pendingReplies[firstKey]!.complete(responsePayload);
        pendingReplies.remove(firstKey);
      } else {
        debugLog(
          "Warning: Received response with no pending completer - Code: $responseCode, ReplyId: $replyId",
        );
      }

      final remainingBytes = buffer.sublist(8 + payloadSize);
      incomingBuffer.clear();
      incomingBuffer.add(remainingBytes);
    }
  }
}
