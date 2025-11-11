# flutter_zk

A Flutter plugin to connect and interact with ZKTeco biometric attendance devices over TCP/IP. This package is a Dart implementation inspired by the `pyzk` Python library.

## Features

- Connect to ZKTeco devices.
- Authenticate with a device password.
- Get device information:
  - Firmware Version
  - Serial Number
  - Device Time
- Fetch user data from the device.
- Disconnect gracefully.
- Robust error handling.

## Getting started

### Prerequisites

Ensure your Flutter development environment is set up. Your ZKTeco device must be connected to the same network as your application and must be reachable via its IP address.

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_zk:
    git:
      url: https://github.com/AbdullahAlMamun12/flutter_zk 
      ref: main
```

Then, run `flutter pub get` in your terminal.

## Usage

Here is a basic example of how to use the `flutter_zk` package.

```dart
import 'package:flutter_zk/flutter_zk.dart';

void main() async {
  final zk = ZK('192.168.1.201', port: 4370, password: 0);

  try {
    // Connect to the device
    await zk.connect();
    print('Connected to device.');

    // Get firmware version
    final firmware = await zk.getFirmwareVersion();
    print('Firmware Version: $firmware');

    // Get serial number
    final serial = await zk.getSerialNumber();
    print('Serial Number: $serial');

    // Get all users
    print('Fetching users...');
    final users = await zk.getUsers();
    print('Found ${users.length} users.');
    for (var user in users) {
      print('- UID: ${user.uid}, UserID: ${user.userId}, Name: ${user.name}');
    }

  } catch (e) {
    print('An error occurred: $e');
  } finally {
    // Always ensure to disconnect
    await zk.disconnect();
    print('Disconnected from device.');
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
- `Future<DateTime> getTime()`: Retrieves the current time from the device.
- `Future<List<User>> getUsers()`: Fetches a list of all users registered on the device.

## Error Handling

The package uses custom exceptions for error handling:
- `ZKNetworkError`: Thrown for socket-level or network-related issues (e.g., connection timeout, host not reachable).
- `ZKErrorConnection`: Thrown for state-related connection errors (e.g., trying to send a command before connecting).
- `ZKErrorResponse`: Thrown when the device returns an unexpected or error response to a command.

It is recommended to wrap calls to the library in a `try...catch` block.

## Additional information

This package is currently under development. More features, such as fetching attendance records and managing users, will be added in the future.

To file issues or contribute to the package, please visit the [GitHub repository](https://github.com/AbdullahAlMamun12/flutter_zk).
