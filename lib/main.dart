import 'package:codecreate_whatsapp_bulk_sender/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sheard_var.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences prefs = await SharedPreferences.getInstance();

  isServerRunning = prefs.getBool('isServerRunning') ?? false;
  port_txt = prefs.getString('serverPort') ?? port_txt;

  runApp(MyApp());
}
