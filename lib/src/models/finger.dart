// lib/src/models/finger.dart

import 'dart:typed_data';
import 'package:convert/convert.dart';

class Finger {
  final int uid;
  final int fid;
  final int valid;
  final Uint8List template;

  int get size => template.length;
  String get mark => '${hex.encode(template.sublist(0, 8))}...${hex.encode(template.sublist(template.length - 8))}';

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
