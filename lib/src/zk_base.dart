import 'mixins/connection_mixin.dart';
import 'mixins/device_control_mixin.dart';
import 'mixins/device_information_mixin.dart';
import 'mixins/user_management_mixin.dart';
import 'mixins/attendance_mixin.dart';
import 'mixins/data_management_mixin.dart';
import 'mixins/network_mixin.dart';

/// The main class for interacting with a ZKTeco biometric device.
///
/// This class provides a comprehensive set of methods for managing the device,
/// including connecting, fetching data, managing users, and controlling
/// device operations. It is composed of several mixins, each handling a
/// specific area of functionality.
class ZK with
    ConnectionMixin,
    NetworkMixin,
    DeviceControlMixin,
    DeviceInformationMixin,
    UserManagementMixin,
    AttendanceMixin,
    DataManagementMixin {

  @override
  final String ip;

  @override
  final int port;

  @override
  final int timeout;

  @override
  final int password;

  @override
  final bool forceUdp;

  /// Creates a new instance of the ZK class.
  ///
  /// [ip] The IP address of the ZKTeco device.
  /// [port] The port number for the device connection (default is 4370).
  /// [timeout] The connection timeout in seconds (default is 10).
  /// [password] The device's communication password (default is 0).
  /// [forceUdp] Whether to force UDP communication (not yet supported).
  ZK(
    this.ip, {
    this.port = 4370,
    this.timeout = 10,
    this.password = 0,
    this.forceUdp = false,
  });

  /// Returns a string representation of the ZK device, including connection
  /// details and device capacity information.
  @override
  String toString() {
    return "ZK tcp://$ip:$port users[$userPacketSize]:$usersCount/$usersCapacity "
        "fingers:$fingersCount/$fingersCapacity records:$recordsCount/$recordsCapacity "
        "faces:$facesCount/$facesCapacity";
  }
}
