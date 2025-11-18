import 'dart:async';
import 'dart:typed_data';

import '../zk_constants.dart';
import '../exceptions.dart';
import 'connection_mixin.dart';
import '../utils/logger.dart';

/// Provides methods for handling network-level data transfer, including
/// reading device capacity and handling large data packets.
mixin NetworkMixin on ConnectionMixin {
  /// Reads the device's capacity information (number of users, fingerprints, etc.)
  /// and populates the corresponding properties in [ConnectionMixin].
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<void> readSizes() async {
    final response = await sendCommand(CMD_GET_FREE_SIZES);
    final responseCode = parseHeader(response)[0];
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

  /// Frees the data buffer on the device.
  ///
  /// This should be called after a large data transfer is complete.
  /// (Internal use only)
  ///
  /// Throws [ZKErrorResponse] if the operation fails.
  Future<void> freeData() async {
    final response = await sendCommand(CMD_FREE_DATA);
    final responseCode = parseHeader(response)[0];
    if (responseCode != CMD_ACK_OK) {
      throw ZKErrorResponse("freeData failed with code $responseCode");
    }
  }

  /// Reads a chunk of data from the device's buffer.
  /// (Internal use only)
  Future<Uint8List> readChunk(int start, int size) async {
    final commandString = ByteData(8);
    commandString.setInt32(0, start, Endian.little);
    commandString.setInt32(4, size, Endian.little);

    debugLog("_readChunk: Requesting $size bytes from offset $start");

    dataPacketCompleter = Completer<Uint8List>();
    final localCompleter = dataPacketCompleter!;

    final response = await sendCommand(
      1504, // CMD_READ_BUFFER, not in constants
      commandString: commandString.buffer.asUint8List(),
    );

    final header = parseHeader(response);
    final responseCode = header[0];

    debugLog("_readChunk: Initial response code: $responseCode");

    if (responseCode == CMD_DATA) {
      final data = response.sublist(8);
      debugLog("_readChunk: Got data directly (${data.length} bytes)");
      dataPacketCompleter = null;
      return data;
    } else if (responseCode == CMD_PREPARE_DATA) {
      debugLog("_readChunk: Got PREPARE_DATA, waiting for CMD_DATA...");

      try {
        final dataResponse = await localCompleter.future.timeout(
          Duration(seconds: timeout + 5),
          onTimeout: () {
            dataPacketCompleter = null;
            throw ZKNetworkError("Timeout waiting for CMD_DATA packet");
          },
        );

        dataPacketCompleter = null;

        final dataHeader = parseHeader(dataResponse);
        final dataCode = dataHeader[0];

        if (dataCode == CMD_DATA) {
          final data = dataResponse.sublist(8);
          debugLog("_readChunk: Received CMD_DATA with ${data.length} bytes");
          return data;
        } else {
          throw ZKErrorResponse("Expected CMD_DATA, got: $dataCode");
        }
      } catch (e) {
        dataPacketCompleter = null;
        debugLog("_readChunk error: $e");
        rethrow;
      }
    } else if (responseCode == CMD_ACK_OK) {
      final data = response.sublist(8);
      debugLog("_readChunk: Got ACK_OK with ${data.length} bytes");
      dataPacketCompleter = null;
      return data;
    }

    dataPacketCompleter = null;
    throw ZKErrorResponse(
      "Unexpected response code in _readChunk: $responseCode",
    );
  }

  /// Reads large data records (like users or attendance logs) from the device.
  ///
  /// This method handles the protocol for reading data that is too large to fit
  /// in a single packet, reading it in chunks.
  /// (Internal use only)
  Future<Uint8List> readWithBuffer(
    int command, {
    int fct = 0,
    int ext = 0,
  }) async {
    const maxChunk = 65472;

    final commandString = ByteData(11);
    commandString.setUint8(0, 1);
    commandString.setUint16(1, command, Endian.little);
    commandString.setInt32(3, fct, Endian.little);
    commandString.setInt32(7, ext, Endian.little);

    debugLog(
      "readWithBuffer: Sending command $command with fct=$fct, ext=$ext",
    );

    final response = await sendCommand(
      1503, // CMD_READ_WITH_BUFFER, not in constants
      commandString: commandString.buffer.asUint8List(),
    );

    final header = parseHeader(response);
    final responseCode = header[0];
    final responseData = response.sublist(8);

    debugLog(
      "readWithBuffer: Response code: $responseCode, data length: ${responseData.length}",
    );

    if (responseCode == CMD_DATA) {
      debugLog(
        "readWithBuffer: Received data directly (${responseData.length} bytes)",
      );
      return responseData;
    }

    if (responseData.length < 5) {
      debugLog(
        "readWithBuffer: Response too short: ${responseData.length} bytes",
      );
      throw ZKErrorResponse("Response data too short");
    }

    final size = ByteData.sublistView(
      responseData,
      1,
      5,
    ).getUint32(0, Endian.little);

    if (size == 0) {
      debugLog("readWithBuffer: Size is 0, returning empty");
      return Uint8List(0);
    }

    debugLog("readWithBuffer: Total size to read: $size bytes");

    final remain = size % maxChunk;
    final packets = (size - remain) ~/ maxChunk;

    debugLog(
      "readWithBuffer: Need $packets full chunks + $remain remainder bytes",
    );

    final allData = BytesBuilder();
    int start = 0;

    for (int i = 0; i < packets; i++) {
      debugLog(
        "readWithBuffer: Reading chunk ${i + 1}/$packets (offset: $start, size: $maxChunk)",
      );
      final chunk = await readChunk(start, maxChunk);
      allData.add(chunk);
      start += chunk.length;
      debugLog(
        "readWithBuffer: Chunk ${i + 1} complete, read ${chunk.length} bytes, total: $start/$size",
      );

      await Future.delayed(Duration(milliseconds: 10));
    }

    if (remain > 0) {
      debugLog(
        "readWithBuffer: Reading final chunk (offset: $start, size: $remain)",
      );
      final chunk = await readChunk(start, remain);
      allData.add(chunk);
      start += chunk.length;
      debugLog(
        "readWithBuffer: Final chunk complete, read ${chunk.length} bytes, total: $start/$size",
      );
    }

    await freeData();

    final finalData = allData.toBytes();
    debugLog("readWithBuffer: Complete! Total bytes read: ${finalData.length}");

    return finalData;
  }
}
