import 'dart:io';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';


class PhpServer {
  Process? _process;
  bool _isRunning = false;

  Future<void> startServer() async {
    if (_isRunning) {
      print('PHP server is already running.');
      return;
    }

    final phpExePath = p.absolute('php7/php.exe'); // Absolute path to PHP executable
    final scriptPath = p.absolute(p.join('php7', 'script_dir', 'sas')); // Absolute path to server script directory
    final args = ['-S', 'localhost:8000', '-t', scriptPath];


    try {
      _process = await Process.start(
        phpExePath,
        args,
        mode: ProcessStartMode.normal,

      );

      // Set flag to true
      _isRunning = true;

      // Listen to stdout
      _process!.stdout.transform(utf8.decoder).listen((data) {
        print('STDOUT: $data');
      });

      // Listen to stderr
      _process!.stderr.transform(utf8.decoder).listen((data) {
        print('STDERR: $data');
      });

      print('PHP server started on http://localhost:8000');
    } catch (e) {
      print('Error starting PHP server: $e');
    }
  }

  void stopServer() {
    if (_process != null) {
      _process!.kill();
      _process = null;
      _isRunning = false;
      print('PHP server stopped');
    } else {
      print('PHP server is not running.');
    }
  }
}





