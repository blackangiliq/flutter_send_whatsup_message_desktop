import 'package:codecreate_whatsapp_bulk_sender/sass4/sas4_helper.dart';

bool runOnStartup = false;
bool AotuoMaticSending = false;
bool isServerRunning = false;
String port_txt = "3000";



String formatPhoneNumber(String phone) {
  // 1. Remove leading/trailing spaces
  phone = phone.trim();

  // 2. Replace only the first '0' if it exists
  if (phone.startsWith('0')) {
    phone = phone.substring(1);
  }

  // 3. Split by separators
  List<String> parts = phone.split(RegExp(r'[-/\\ ]+'));

  // 4. Find the first valid part
  for (var part in parts) {
    if (part.length >= 8 && RegExp(r'^\d+$').hasMatch(part)) {
      if (part.startsWith('0')) {
        part = part.substring(1);
      }
      return part;
    }
  }

  return "";
}