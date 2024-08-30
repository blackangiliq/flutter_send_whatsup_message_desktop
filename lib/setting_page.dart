import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32_registry/win32_registry.dart';
import 'sheard_var.dart';
class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  TextEditingController _portController = TextEditingController(text: port_txt);
  final _formKey = GlobalKey<FormState>(); // Form key for validation

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      runOnStartup = prefs.getBool('runOnStartup') ?? false;
      isServerRunning = prefs.getBool('isServerRunning') ?? false;
      _portController.text = prefs.getString('serverPort') ?? port_txt;
      port_txt = prefs.getString('serverPort') ?? port_txt;
    });
    await _updateStartupTask();
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('runOnStartup', runOnStartup);
    await prefs.setBool('isServerRunning', isServerRunning);
    await prefs.setString('serverPort', _portController.text);
  }

  Future<void> _toggleRunOnStartup(bool value) async {
    setState(() {
      runOnStartup = value;
    });
    await _saveSettings();
    await _updateStartupTask();
  }

  Future<void> _updateStartupTask() async {
    try {
      if (Platform.isWindows) {
        String executablePath = Platform.resolvedExecutable;
        const keyPath = r'Software\Microsoft\Windows\CurrentVersion\Run';
        final key = Registry.openPath(
          RegistryHive.currentUser,
          path: keyPath,
          desiredAccessRights: AccessRights.allAccess,
        );

        if (runOnStartup) {
          key.createValue(
              RegistryValue('MyApp', RegistryValueType.string, executablePath));
        } else {
          key.deleteValue('MyApp');
        }

        key.close();
        print('Startup task updated successfully.');
      } else {
        print('Startup management not supported on this platform.');
      }
    } catch (e) {
      print('Error updating startup task: $e');
    }
  }

  // Function to start/stop the server (You'll need to implement the actual server logic)
  Future<void> _manageServer(bool start) async {
    // Implement your server start/stop logic here

    setState(() {
      isServerRunning = start;
    });
    // You should only save settings after successfully starting/stopping the server
    await _saveSettings();
    // Optionally, provide feedback to the user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Server ${start ? 'started' : 'stopped'}'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Function to check if a port is open
  Future<bool> _isPortOpen(int port) async {
    try {
      final socket = await RawSocket.connect('127.0.0.1', port);
      socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Run on Startup
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Run on Startup', style: TextStyle(fontSize: 16)),
                  Switch(
                    value: runOnStartup,
                    onChanged: _toggleRunOnStartup,
                    activeColor: Colors.blue,
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Server Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Server Status:', style: TextStyle(fontSize: 16)),
                  Text(isServerRunning ? "Running" : "Stopped",
                      style: TextStyle(
                          fontSize: 16,
                          color: isServerRunning ? Colors.green : Colors.red)),
                ],
              ),
              SizedBox(height: 20),

              // Port Input
              TextFormField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                  hintText: 'Enter port number (e.g., 8080)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a port number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              // Start/Stop Server Button
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    int port = int.tryParse(_portController.text) ?? 0;
                    if (isServerRunning) {
                      await _manageServer(false);
                    } else if (await _isPortOpen(port)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Port $port is already in use.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else {
                      await _manageServer(true);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isServerRunning ? Colors.red : Colors.blue,
                  minimumSize: Size(double.infinity, 48),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  textStyle: TextStyle(fontSize: 18),
                ),
                child: Text(isServerRunning ? 'Stop Server' : 'Start Server'),
              ),
              // how to use the server documentation
              isServerRunning
                  ? Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width -12,
                        margin: EdgeInsets.only(top: 20),
                        child: SelectionArea(
                          child: Text(
                            "How to use the server: \n"
                                "\n"
                                "ip:port/api/sendText?phone=phone&text=urMessage"
                                "\n"
                                "\n"
                                "for sending text message to group: "
                                "\n"
                                "\n"
                                "ip:port/api/sendTextTogroup?phone=groupLink&text=textMessage"
                                "\n"
                                "\n"
                                "u can see the screen in the browser"
                                "\n"
                                "\n"
                                "ip:port/api/screenshot",
                            style: TextStyle(fontSize: 16),
                            textAlign:  TextAlign.center,
                          ),
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.blue,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 5,
                              blurRadius: 7,
                              offset: Offset(0, 3),
                            )
                          ],
                        ),
                      ),
                    )
                  : Container(),
            ],
          ),
        ),
      ),
    );
  }
}
