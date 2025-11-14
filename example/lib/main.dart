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
  final ZK zk = ZK('10.22.0.2');
  List<User> _users = [];
  List<Attendance> _attendances = [];
  bool _isLoading = false;
  String _currentView = 'deviceInfo'; // 'deviceInfo', 'users', 'attendances'

  Future<void> _getDeviceInfo() async {
    setState(() {
      _isLoading = true;
      _status = 'Connecting...';
      _users = [];
      _attendances = [];
      _currentView = 'deviceInfo';
    });

    try {
      await zk.connect();
      final firmware = await zk.getFirmwareVersion();
      final serial = await zk.getSerialNumber();
      final time = await zk.getTime();

      setState(() {
        _status =
            'Connected!\nFirmware: $firmware\nSerial: $serial\nDevice Time: $time';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
    } finally {
      await zk.disconnect();
    }
  }

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
      await zk.disconnect();
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
        fromDate: DateTime.now(),
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
      await zk.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('ZK Example')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                _status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator()
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
                                    child: Text('Privilege: ${user.privilege}'),
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
                )
              else
                const SizedBox.shrink(), // Or display device info here if desired
            ],
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.devices),
                onPressed: _isLoading ? null : _getDeviceInfo,
              ),
              IconButton(
                icon: const Icon(Icons.people),
                onPressed: _isLoading ? null : _fetchUsers,
              ),
              IconButton(
                icon: const Icon(Icons.event_note),
                onPressed: _isLoading ? null : _fetchAttendances,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
