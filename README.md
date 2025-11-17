# flutter_zk

A Flutter plugin to connect and interact with ZKTeco biometric attendance devices over TCP/IP. This package is a Dart implementation inspired by the `pyzk` Python library.

## Features

- Connect to ZKTeco devices.
- Authenticate with a device password.
- Get device information:
  - Firmware Version
  - Serial Number
  - Device Time
  - Platform
  - MAC Address
  - Device Name
  - Face and Fingerprint Algorithm Versions
  - Network Parameters (IP, Subnet Mask, Gateway)
- Manage users:
  - Fetch user data from the device.
  - Add and update users.
  - Delete users.
- Fetch attendance records from the device.
- Control device operations:
  - Enable/Disable device.
  - Restart/Power off device.
  - Refresh data.
  - Unlock doors.
  - Play voice messages.
- Manage data:
  - Clear all data.
  - Clear attendance records.
- Disconnect gracefully.
- Robust error handling.

## Getting started

### Prerequisites

Ensure your Flutter development environment is set up. Your ZKTeco device must be connected to the same network as your application and must be reachable via its IP address.

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_zk: ^1.0.0 
```

Then, run `flutter pub get` in your terminal.

## Usage

Here is a basic example of how to use the `flutter_zk` package.

```dart
import 'package:flutter_zk/flutter_zk.dart';
import 'package:flutter_zk/src/utils/logger.dart'; // Import the custom logger

void main() async {
  final zk = ZK('192.168.1.201', port: 4370, password: 0);

  try {
    // Connect to the device
    await zk.connect();
    debugLog('Connected to device.');

    // Get firmware version
    final firmware = await zk.getFirmwareVersion();
    debugLog('Firmware Version: $firmware');

    // Get serial number
    final serial = await zk.getSerialNumber();
    debugLog('Serial Number: $serial');

    // Get all users
    debugLog('Fetching users...');
    final users = await zk.getUsers();
    debugLog('Found ${users.length} users.');
    for (var user in users) {
      debugLog('- UID: ${user.uid}, UserID: ${user.userId}, Name: ${user.name}');
    }

  } catch (e) {
    debugLog('An error occurred: $e', error: e);
  } finally {
    // Always ensure to disconnect
    await zk.disconnect();
    debugLog('Disconnected from device.');
  }
}
```

## API Overview

### `ZK(String ip, {int port, int password})`

Creates a new `ZK` instance.
- `ip`: The IP address of the ZKTeco device.
- `port`: The communication port (default is `4370`).
- `password`: The device's communication password (default is `0`).

### Core Methods

- `Future<void> connect()`: Establishes a connection with the device and performs authentication.
- `Future<void> disconnect()`: Closes the connection to the device.
- `Future<String> getFirmwareVersion()`: Retrieves the device's firmware version.
- `Future<String> getSerialNumber()`: Retrieves the device's serial number.
- `Future<String> getPlatform()`: Retrieves the device's platform information.
- `Future<String> getMacAddress()`: Retrieves the device's MAC address.
- `Future<String> getDeviceName()`: Retrieves the device's name.
- `Future<int?> getFaceVersion()`: Retrieves the face recognition algorithm version.
- `Future<int> getFingerprintVersion()`: Retrieves the fingerprint algorithm version.
- `Future<Map<String, String>> getNetworkParams()`: Retrieves the network parameters (IP, subnet mask, gateway) of the device.
- `Future<DateTime> getTime()`: Retrieves the current time from the device.
- `Future<void> setTime(DateTime timestamp)`: Sets the time on the device.
- `Future<List<User>> getUsers()`: Fetches a list of all users registered on the device.
- `Future<void> setUser({int? uid, String name, int privilege, String password, String groupId, String? userId, int card})`: Creates a new user or updates an existing user on the device.
- `Future<void> deleteUser({int? uid, String? userId})`: Deletes a user from the device.
- `Future<List<Attendance>> getAttendance({DateTime? fromDate, DateTime? toDate, String sort})`: Retrieves attendance records from the device.
- `Future<void> enableDevice()`: Enables the device, allowing it to accept user input and perform operations.
- `Future<void> disableDevice()`: Disables the device, preventing it from accepting user input.
- `Future<void> restart()`: Restarts the device.
- `Future<void> powerOff()`: Powers off the device.
- `Future<void> refreshData()`: Refreshes the device's internal data.
- `Future<void> unlock({int time})`: Unlocks the door connected to the device's relay.
- `Future<bool> testVoice({int index})`: Plays a pre-recorded voice message on the device.
- `Future<void> clearData()`: Clears all data from the device.
- `Future<void> clearAttendance()`: Clears all attendance records from the device.


It is recommended to wrap calls to the library in a `try...catch` block.

## Additional information


To file issues or contribute to the package, please visit the [GitHub repository](https://github.com/AbdullahAlMamun12/flutter_zk).
