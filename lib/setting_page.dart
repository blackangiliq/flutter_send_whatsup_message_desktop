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
  TextEditingController messageTextControleer = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  TimeOfDay _selectedTime1 = TimeOfDay.now();
  TimeOfDay _selectedTime2 = TimeOfDay.now();

  List<bool> _selectedDays = List.generate(7, (_) => true);

  bool _isDaily = true;

  List<bool> _selectedHours = List.generate(24, (_) => false);
  String _selectedHoursDisplay = 'No hours selected';

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
      AotuoMaticSending = prefs.getBool('AotuoMaticSending') ?? false;
      _portController.text = prefs.getString('serverPort') ?? port_txt;
      port_txt = prefs.getString('serverPort') ?? port_txt;
      _isDaily = prefs.getBool('isDaily') ?? true;

      String? savedTime1 = prefs.getString('scheduledTime1');
      if (savedTime1 != null) {
        _selectedTime1 = TimeOfDay.fromDateTime(DateTime.parse(savedTime1));
      }
      String? savedTime2 = prefs.getString('scheduledTime2');
      if (savedTime2 != null) {
        _selectedTime2 = TimeOfDay.fromDateTime(DateTime.parse(savedTime2));
      }

      List<String> savedDays = prefs.getStringList('selectedDays') ??
          List.generate(7, (index) => 'true');
      _selectedDays = savedDays.map((day) => day == 'true').toList();

      Set<String> savedHours =
          (prefs.getStringList('selectedHours') ?? []).toSet();
      _selectedHours =
          List.generate(24, (index) => savedHours.contains(index.toString()));
      _updateSelectedHoursDisplay();
    });
    await _updateStartupTask();
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('runOnStartup', runOnStartup);
    await prefs.setBool('isServerRunning', isServerRunning);
    await prefs.setBool('AotuoMaticSending', AotuoMaticSending);
    await prefs.setString('serverPort', _portController.text);
    await prefs.setBool('isDaily', _isDaily);

    DateTime now = DateTime.now();
    DateTime scheduledTime1 = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime1.hour,
      _selectedTime1.minute,
    );
    await prefs.setString('scheduledTime1', scheduledTime1.toString());

    DateTime scheduledTime2 = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime2.hour,
      _selectedTime2.minute,
    );
    await prefs.setString('scheduledTime2', scheduledTime2.toString());

    List<String> daysToSave =
        _selectedDays.map((selected) => selected.toString()).toList();
    await prefs.setStringList('selectedDays', daysToSave);

    List<String> hoursToSave = _selectedHours
        .asMap()
        .entries
        .where((entry) => entry.value)
        .map((entry) => entry.key.toString())
        .toList();
    await prefs.setStringList('selectedHours', hoursToSave);
  }

  Future<void> _toggleRunOnStartup(bool value) async {
    setState(() {
      runOnStartup = value;
    });
    await _saveSettings();
    await _updateStartupTask();
  }

  Future<void> _selectTime(bool isFirstTime) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: isFirstTime ? _selectedTime1 : _selectedTime2,
    );
    if (pickedTime != null) {
      setState(() {
        if (isFirstTime) {
          _selectedTime1 = pickedTime;
        } else {
          _selectedTime2 = pickedTime;
        }
      });
      await _saveSettings();
    }
  }

  Future<void> _toggleAotuoMaticSending(bool value) async {
    setState(() {
      AotuoMaticSending = value;
    });
    await _saveSettings();
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

  Future<void> _manageServer(bool start) async {
    setState(() {
      isServerRunning = start;
    });

    await _saveSettings();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Server ${start ? 'started' : 'stopped'}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _isPortOpen(int port) async {
    try {
      final socket = await RawSocket.connect('127.0.0.1', port);
      socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  void _updateSelectedHoursDisplay() {
    List<String> selectedHourStrings = [];
    for (int i = 0; i < _selectedHours.length; i++) {
      if (_selectedHours[i]) {
        selectedHourStrings.add('${i.toString().padLeft(2, '0')}:00');
      }
    }

    setState(() {
      _selectedHoursDisplay = selectedHourStrings.join(', ');
      if (_selectedHoursDisplay.isEmpty) {
        _selectedHoursDisplay = 'No hours selected';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاعدادات')),
      body: SingleChildScrollView(
        // Make the content scrollable
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تشغيل البرنامج تلقائيا عند اعادة تشغيل الجهاز',
                      style: TextStyle(fontSize: 16)),
                  Switch(
                    value: runOnStartup,
                    onChanged: _toggleRunOnStartup,
                    activeColor: Colors.blue,
                  ),
                ],
              ),
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width - 100,
                  margin: const EdgeInsets.all(10),
                  height: 2,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ارسال رسائل للمشتركين بشكل تلقائي ( يجب اخيتار الوقت )',
                      style: TextStyle(fontSize: 16)),
                  Switch(
                    value: AotuoMaticSending,
                    onChanged: _toggleAotuoMaticSending,
                    activeColor: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (AotuoMaticSending) ...[
                const Center(
                    child:
                        Text('أيام الإرسال', style: TextStyle(fontSize: 16))),
                const SizedBox(
                  height: 20,
                ),
                Center(
                  child: Wrap(
                    spacing: 8.0,
                    children: List.generate(
                      7,
                      (index) {
                        final dayName = [
                          'السبت',
                          'الأحد',
                          'الاثنين',
                          'الثلاثاء',
                          'الأربعاء',
                          'الخميس',
                          'الجمعة',
                        ][index];
                        return ChoiceChip(
                          selectedColor: Colors.blue,
                          selectedShadowColor: Colors.amber,
                          label: Text(dayName),
                          selected: _selectedDays[index],
                          onSelected: (selected) {
                            setState(() {
                              _selectedDays[index] = selected;
                            });
                            _saveSettings();
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                InkWell(
                  onTap: () {
                    _selectTime(true);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('في الايام المختارة اعلاه سيبدأ الارسال في توقيت :',
                          style: TextStyle(fontSize: 20)),
                      Text(
                        _selectedTime1 != null
                            ? _selectedTime1.format(context)
                            : 'لم يتم اختيار وقت',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const Icon(Icons.access_time),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: () {
                    _selectTime(false);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('في الايام المختارة اعلاه سينتهي الارسال في توقيت :',
                          style: TextStyle(fontSize: 20)),
                      Text(
                        _selectedTime2 != null
                            ? _selectedTime2.format(context)
                            : 'لم يتم اختيار وقت',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const Icon(Icons.access_time),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: messageTextControleer,
                  keyboardType: TextInputType.number,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    hintStyle: TextStyle(color: Colors.blue),
                    labelText: 'الرسالة الي توصل للمشتركين ',
                    border: OutlineInputBorder(),
                    hintText: 'مرحبا عزيزي المشترك : %الاسم '
                        '\n'
                        'سينتهي اشتراكك في خدمة الانترنت'
                        '\n'
                        'في تاريخ : %تاريخ'
                        '\n'
                        'بعد : %يوم %ساعة %دقيقة',
                  ),
                ),
              ],
              // Server Status
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width - 100,
                  margin: const EdgeInsets.all(10),
                  height: 2,
                  color: Colors.blue,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(isServerRunning ? "يعمل" : "متوقف",
                      style: TextStyle(
                          fontSize: 16,
                          color: isServerRunning ? Colors.green : Colors.red)),
                  const Center(
                    child: Text('حالة سيرفر المطورين',
                        style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Port Input
              TextFormField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'منفذ الاتصال',
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
              const SizedBox(height: 20),
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
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else {
                      await _manageServer(true);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isServerRunning ? Colors.red : Colors.blue,
                  minimumSize: const Size(double.infinity, 48),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: Text(isServerRunning
                    ? 'ايقاف سيرفر المطورين'
                    : 'تشغيل سيرفر المطورين'),
              ),
              // how to use the server documentation
              isServerRunning
                  ? Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width - 12,
                        margin: const EdgeInsets.only(top: 20),
                        child: const SelectionArea(
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
                            textAlign: TextAlign.center,
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
                              offset: const Offset(0, 3),
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
