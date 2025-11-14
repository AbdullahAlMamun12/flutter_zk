// lib/src/models/finger.dart

import 'dart:typed_data';
import 'package:convert/convert.dart';

/// Represents a fingerprint template stored on the device.
class Finger {
  /// The unique internal ID of the user who owns the fingerprint.
  final int uid;

  /// The finger ID, indicating which finger this template is for (0-9).
  final int fid;

  /// A flag indicating if the fingerprint is valid.
  ///
  /// Typically, a value of 1 means valid.
  final int valid;

  /// The raw fingerprint template data.
  final Uint8List template;

  /// The size of the fingerprint template in bytes.
  int get size => template.length;

  /// A truncated hex representation of the template for display purposes.
  String get mark =>
      '${hex.encode(template.sublist(0, 8))}...${hex.encode(template.sublist(template.length - 8))}';

  /// Creates a new [Finger] instance.
  Finger({
    required this.uid,
    required this.fid,
    required this.valid,
    required this.template,
  });

  @override
  String toString() {
    return "<Finger> [uid:$uid, fid:$fid, size:$size v:$valid t:$mark]";
  }
}
