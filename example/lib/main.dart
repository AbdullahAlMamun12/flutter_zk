import 'package:flutter/material.dart';
import 'package:flutter_zk/flutter_zk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'Not Connected';
  final ZK zk = ZK('10.22.0.2');
  List<User> _users = [];
  bool _isLoading = false;

  Future<void> _getDeviceInfo() async {
    setState(() {
      _isLoading = true;
      _status = 'Connecting...';
      _users = [];
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('ZK Flutter Example'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                _status,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : _getDeviceInfo,
                    child: const Text('Device Info'),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _fetchUsers,
                    child: const Text('Fetch Users'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return Card(
                        child: ListTile(
                          title: Text(user.name),
                          subtitle: Text('ID: ${user.userId} | UID: ${user.uid} | Card: ${user.card}'),
                          trailing: Text('Priv: ${user.privilege}'),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
