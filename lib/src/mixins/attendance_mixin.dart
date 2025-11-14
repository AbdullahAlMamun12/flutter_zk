import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../zk_constants.dart';
import '../exceptions.dart';
import '../models/attendance.dart';
import 'connection_mixin.dart';
import 'network_mixin.dart';
import 'device_information_mixin.dart';

/// Provides methods for retrieving attendance records from the device.
mixin AttendanceMixin on ConnectionMixin, NetworkMixin, DeviceInformationMixin {
  /// Retrieves attendance records from the device.
  ///
  /// This method fetches all attendance records and optionally filters and sorts them.
  ///
  /// - [fromDate]: Optional. The start date for filtering attendance records.
  ///   If null, defaults to the first day of the current month.
  /// - [toDate]: Optional. The end date for filtering attendance records.
  ///   If null, defaults to the current date.
  /// - [sort]: Optional. The sorting order for attendance records.
  ///   Can be 'asc' for ascending or 'desc' for descending (default).
  ///
  /// Returns a list of [Attendance] objects. Returns an empty list if no records are found
  /// or if the data is invalid.
  ///
  /// Throws [ZKErrorResponse] if the command to fetch data fails.
  Future<List<Attendance>> getAttendance({
    DateTime? fromDate,
    DateTime? toDate,
    String sort = 'desc',
  }) async {
    await readSizes();

    if (recordsCount == 0) {
      debugPrint("No attendance records found on device");
      return [];
    }

    final attendanceData = await readWithBuffer(CMD_ATTLOG_RRQ);

    debugPrint("Received attendance data: ${attendanceData.length} bytes");

    if (attendanceData.length <= 4) {
      debugPrint("Warning: Insufficient attendance data");
      return [];
    }

    final totalSize = ByteData.sublistView(
      attendanceData,
      0,
      4,
    ).getUint32(0, Endian.little);
    debugPrint("Total size from header: $totalSize bytes");

    if (totalSize == 0) {
      return [];
    }

    final recordSize = totalSize / recordsCount;
    debugPrint("Record size: $recordSize bytes per record");

    var attendances = <Attendance>[];
    var offset = 4;

    if (recordSize == 8) {
      while (offset + 8 <= attendanceData.length) {
        final byteData = ByteData.sublistView(attendanceData, offset);
        final uid = byteData.getUint16(0, Endian.little);
        final status = byteData.getUint8(2);
        final timestamp = decodeTime(byteData.getUint32(3, Endian.little));
        final punch = byteData.getUint8(7);

        attendances.add(
          Attendance(
            userId: uid.toString(),
            timestamp: timestamp,
            status: status,
            punch: punch,
            uid: uid,
          ),
        );

        offset += 8;
      }
    } else if (recordSize == 16) {
      while (offset + 16 <= attendanceData.length) {
        final byteData = ByteData.sublistView(attendanceData, offset);
        final userId = byteData.getUint32(0, Endian.little).toString();
        final timestamp = decodeTime(byteData.getUint32(4, Endian.little));
        final status = byteData.getUint8(8);
        final punch = byteData.getUint8(9);

        attendances.add(
          Attendance(
            userId: userId,
            timestamp: timestamp,
            status: status,
            punch: punch,
            uid: int.tryParse(userId) ?? 0,
          ),
        );

        offset += 16;
      }
    } else {
      while (offset + 40 <= attendanceData.length) {
        final byteData = ByteData.sublistView(attendanceData, offset);
        final uid = byteData.getUint16(0, Endian.little);
        final userIdBytes = attendanceData.sublist(offset + 2, offset + 26);
        final userId = decodeString(userIdBytes);
        final status = byteData.getUint8(26);
        final timestamp = decodeTime(byteData.getUint32(27, Endian.little));
        final punch = byteData.getUint8(31);

        attendances.add(
          Attendance(
            userId: userId.isNotEmpty ? userId : uid.toString(),
            timestamp: timestamp,
            status: status,
            punch: punch,
            uid: uid,
          ),
        );

        offset += 40;
      }
    }

    debugPrint("Successfully parsed ${attendances.length} attendance records");

    final now = DateTime.now();
    fromDate ??= DateTime(now.year, now.month, 1);
    toDate ??= now;

    final normalizedFromDate = DateTime(
      fromDate.year,
      fromDate.month,
      fromDate.day,
    );
    final normalizedToDate = DateTime(
      toDate.year,
      toDate.month,
      toDate.day,
      23,
      59,
      59,
      999,
    );

    var filteredAttendances = attendances.where((att) {
      final isAfterFrom = !att.timestamp.isBefore(normalizedFromDate);
      final isBeforeTo = !att.timestamp.isAfter(normalizedToDate);
      return isAfterFrom && isBeforeTo;
    }).toList();

    if (sort.toLowerCase() == 'asc') {
      filteredAttendances.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } else if (sort.toLowerCase() == 'dsc' || sort.toLowerCase() == 'desc') {
      filteredAttendances.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    return filteredAttendances;
  }
}
