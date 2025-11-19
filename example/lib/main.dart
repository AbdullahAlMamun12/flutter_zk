import 'package:flutter/material.dart';
import 'package:flutter_zk/flutter_zk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'Not Connected';
  final ZK zk = ZK('192.168.0.2');
  List<User> _users = [];
  List<Attendance> _attendances = [];
  bool _isLoading = false;
  String _currentView = 'deviceInfo'; // 'deviceInfo', 'users', 'attendances'

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _status = 'Fetching users...';
      _users = [];
      _attendances = [];
      _currentView = 'users';
    });

    try {
      await zk.connect();
      final users = await zk.getUsers();
      setState(() {
        _users = users;
        _status = 'Found ${users.length} users.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
    } finally {
      if (zk.isConnected) {
        await zk.disconnect();
      }
    }
  }

  Future<void> _fetchAttendances() async {
    setState(() {
      _isLoading = true;
      _status = 'Fetching attendances...';
      _users = [];
      _attendances = [];
      _currentView = 'attendances';
    });

    try {
      await zk.connect();
      final attendances = await zk.getAttendance(
        fromDate: DateTime.now().subtract(const Duration(days: 7)),
        toDate: DateTime.now(),
        sort: 'desc',
      );
      setState(() {
        _attendances = attendances;
        _status = 'Found ${attendances.length} attendance records.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
    } finally {
      if (zk.isConnected) {
        await zk.disconnect();
      }
    }
  }

  Future<void> _executeAndShow(
    String initialMessage,
    Future<String> Function(ZK zk) zkOperation,
  ) async {
    setState(() {
      _isLoading = true;
      _status = initialMessage;
      _users = [];
      _attendances = [];
      _currentView = 'deviceInfo';
    });

    try {
      await zk.connect();
      final result = await zkOperation(zk);
      setState(() {
        _status = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
    } finally {
      if (zk.isConnected) {
        await zk.disconnect();
      }
    }
  }

  Future<void> _executeAndNotify(
    String initialMessage,
    String successMessage,
    Future<void> Function(ZK zk) zkOperation,
  ) async {
    setState(() {
      _isLoading = true;
      _status = initialMessage;
      _users = [];
      _attendances = [];
      _currentView = 'deviceInfo';
    });

    try {
      await zk.connect();
      await zkOperation(zk);
      setState(() {
        _status = successMessage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
    } finally {
      if (zk.isConnected) {
        await zk.disconnect();
      }
    }
  }

  Future<void> _showInputDialog({
    required BuildContext context,
    required String title,
    required String labelText,
    required String initialValue,
    required void Function(String value) onConfirm,
  }) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: labelText),
            keyboardType: TextInputType.number,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm(controller.text);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('ZK Example'),
            backgroundColor: Colors.blue,
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                const DrawerHeader(
                  decoration: BoxDecoration(color: Colors.blue),
                  child: Text(
                    'ZK Demo Menu',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Users'),
                  onTap: () {
                    Navigator.pop(context);
                    if (!_isLoading) _fetchUsers();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_note),
                  title: const Text('Attendances'),
                  onTap: () {
                    Navigator.pop(context);
                    if (!_isLoading) _fetchAttendances();
                  },
                ),
                const Divider(),
                ExpansionTile(
                  leading: const Icon(Icons.perm_device_information),
                  title: const Text('Device Info'),
                  children: [
                    ListTile(
                      title: const Text('Get Firmware Version'),
                      onTap: () {
                        Navigator.pop(context);
                        _executeAndShow(
                          'Getting firmware...',
                          (zk) async =>
                              'Firmware: ${await zk.getFirmwareVersion()}',
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Get Serial Number'),
                      onTap: () {
                        Navigator.pop(context);
                        _executeAndShow(
                          'Getting serial number...',
                          (zk) async =>
                              'Serial Number: ${await zk.getSerialNumber()}',
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Get Device Time'),
                      onTap: () {
                        Navigator.pop(context);
                        _executeAndShow(
                          'Getting device time...',
                          (zk) async => 'Time: ${await zk.getTime()}',
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Get Platform'),
                      onTap: () {
                        Navigator.pop(context);
                        _executeAndShow(
                          'Getting platform...',
                          (zk) async => 'Platform: ${await zk.getPlatform()}',
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Get MAC Address'),
                      onTap: () {
                        Navigator.pop(context);
                        _executeAndShow(
                          'Getting MAC address...',
                          (zk) async =>
                              'MAC Address: ${await zk.getMacAddress()}',
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Get Device Name'),
                      onTap: () {
                        Navigator.pop(context);
                        _executeAndShow(
                          'Getting device name...',
                          (zk) async =>
                              'Device Name: ${await zk.getDeviceName()}',
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Get Face Version'),
                      onTap: () {
                        Navigator.pop(context);
                        _executeAndShow(
                          'Getting face version...',
                          (zk) async =>
                              'Face Version: ${await zk.getFaceVersion()}',
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Get Fingerprint Version'),
                      onTap: () {
                        Navigator.pop(context);
                        _executeAndShow(
                          'Getting fingerprint version...',
                          (zk) async =>
                              'FP Version: ${await zk.getFingerprintVersion()}',
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Get Network Params'),
                      onTap: () {
                        Navigator.pop(context);
                        _executeAndShow('Getting network params...', (
                          zk,
                        ) async {
                          final params = await zk.getNetworkParams();
                          return 'IP: ${params['ip']}\nMask: ${params['mask']}\nGateway: ${params['gateway']}';
                        });
                      },
                    ),
                  ],
                ),
                ExpansionTile(
                  leading: const Icon(Icons.developer_board),
                  title: const Text('Device Control'),
                  children: [
                    ListTile(
                      title: const Text('Restart'),
                      onTap: () {
                        Navigator.pop(context);
                        _executeAndNotify(
                          'Restarting...',
                          'Device is restarting',
                          (zk) => zk.restart(),
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Power Off'),
                      onTap: () {
                        Navigator.pop(context);
                        _executeAndNotify(
                          'Powering off...',
                          'Device is powering off',
                          (zk) => zk.powerOff(),
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Refresh Data'),
                      onTap: () {
                        Navigator.pop(context);
                        _executeAndNotify(
                          'Refreshing data...',
                          'Data refreshed',
                          (zk) => zk.refreshData(),
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Unlock Door'),
                      onTap: () {
                        final scaffoldContext = context;
                        Navigator.pop(scaffoldContext);
                        _showInputDialog(
                          context: scaffoldContext,
                          title: 'Unlock Door',
                          labelText: 'Duration (seconds)',
                          initialValue: '3',
                          onConfirm: (value) {
                            final time = int.tryParse(value) ?? 3;
                            _executeAndNotify(
                              'Unlocking door...',
                              'Door unlocked',
                              (zk) => zk.unlock(time: time),
                            );
                          },
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Test Voice'),
                      onTap: () {
                        final scaffoldContext = context;
                        Navigator.pop(scaffoldContext);
                        _showInputDialog(
                          context: scaffoldContext,
                          title: 'Test Voice',
                          labelText: 'Voice Index',
                          initialValue: '0',
                          onConfirm: (value) {
                            final index = int.tryParse(value) ?? 0;
                            _executeAndNotify(
                              'Testing voice...',
                              'Voice test sent',
                              (zk) => zk.testVoice(index: index),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
                ExpansionTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('User Actions'),
                  children: [
                    ListTile(
                      title: const Text('Set User (Not Implemented)'),
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Implement a form to get user details
                      },
                    ),
                    ListTile(
                      title: const Text('Delete User (Not Implemented)'),
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Implement a dialog to get user ID/UID
                      },
                    ),
                  ],
                ),
                ExpansionTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('Data Management'),
                  children: [
                    ListTile(
                      title: const Text('Clear Attendance'),
                      onTap: () {
                        final scaffoldContext = context;
                        Navigator.pop(scaffoldContext);
                        _showConfirmationDialog(
                          context: scaffoldContext,
                          title: 'Clear Attendance',
                          content:
                              'Are you sure you want to clear all attendance records?',
                          onConfirm: () {
                            _executeAndNotify(
                              'Clearing attendance...',
                              'Attendance records cleared',
                              (zk) => zk.clearAttendance(),
                            );
                          },
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Clear All Data'),
                      onTap: () {
                        final scaffoldContext = context;
                        Navigator.pop(scaffoldContext);
                        _showConfirmationDialog(
                          context: scaffoldContext,
                          title: 'Clear All Data',
                          content:
                              'Are you sure you want to clear ALL data (users, attendance, etc)? This cannot be undone.',
                          onConfirm: () {
                            _executeAndNotify(
                              'Clearing all data...',
                              'All data cleared',
                              (zk) => zk.clearData(),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (_currentView == 'deviceInfo' && !_isLoading)
                  Center(
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                if (_isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_currentView == 'users')
                  Expanded(
                    child: ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          elevation: 2.0,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        user.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18.0,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 170,
                                      child: Text(
                                        'Privilege: ${user.privilege}',
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('User ID: ${user.userId}'),
                                        Text('UID: ${user.uid}'),
                                      ],
                                    ),
                                    SizedBox(
                                      width: 170,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Card: ${user.card}'),
                                          Text('password: ${user.password}'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else if (_currentView == 'attendances')
                  Expanded(
                    child: ListView.builder(
                      itemCount: _attendances.length,
                      itemBuilder: (context, index) {
                        final attendance = _attendances[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          elevation: 2.0,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'User ID: ${attendance.userId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.0,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  'Timestamp: ${attendance.timestamp.toLocal().toString().split('.')[0]}',
                                ),
                                Text('Status: ${attendance.status}'),
                                Text('Punch: ${attendance.punch}'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
