import 'dart:convert';
import 'dart:io';
import 'package:codecreate_whatsapp_bulk_sender/message_hestory.dart';
import 'package:codecreate_whatsapp_bulk_sender/sass4/run_php_server.dart';
import 'package:codecreate_whatsapp_bulk_sender/sass4/sas4_helper.dart';
import 'package:codecreate_whatsapp_bulk_sender/setting_page.dart';
import 'package:codecreate_whatsapp_bulk_sender/sheard_var.dart';
import 'package:codecreate_whatsapp_bulk_sender/webview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:async';
import 'package:webview_windows/webview_windows.dart';
import 'send_message_helper.dart';
import 'sass4/sas4_users_screen.dart';
late _WhatsAppSenderState _whatsAppSenderState;

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurple,
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.white),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.pinkAccent),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            textStyle: TextStyle(fontSize: 18),
            elevation: 5,
          ),
        ),
      ),
      home: Scaffold(
        body: WhatsAppSender(),
      ),
    );
  }
}

class WhatsAppSender extends StatefulWidget {
  @override
  _WhatsAppSenderState createState() {
    _whatsAppSenderState = _WhatsAppSenderState();
    return _whatsAppSenderState;
  }
}

class _WhatsAppSenderState extends State<WhatsAppSender> {
  final _textController = TextEditingController();
  ScreenshotController screenshotController = ScreenshotController();
  final _numbersController = TextEditingController();
  final _delayController = TextEditingController(text: '3');
  bool _isSending = false;
  bool _stopSending = false;
  String _status = '';
  bool _isWebviewReady = false;
  final List<StreamSubscription> _subscriptions = [];
  int _sentMessagesCount = 0;
  int _failedMessagesCount = 0;

  // Queue for messages
  final List<MessageData> _messageQueue = [];
  bool _isProcessingQueue = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    isServerRunning ? _startServer() : null ;
  }

  final server = PhpServer();


  void _showSendMessageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(' ارسال رسائل بشكل يدوي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _numbersController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'ارقام التلفونات ',
                hintText: 'مثال 77293XXXXXX'
                    'او'
                    '9647729XXXXXXX',
              ),
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: InputDecoration(labelText: 'حط الرسالة هنا' ),
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: _delayController,
              decoration: InputDecoration(labelText: 'التأخير بين كل رسالة ورسالة (بالثواني)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: sendMessagesToAll,
            child: Text('Send'),
          ),
        ],
      ),
    );
  }

  static void navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsPage()),
    );
  }

  void _startServer() async {
    var interfaces = await NetworkInterface.list();
    String? ipAddress;

    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (addr.address.isNotEmpty &&
            !addr.address.startsWith('127.') &&
            addr.type == InternetAddressType.IPv4) {
          ipAddress = addr.address;
          break;
        }
      }
      if (ipAddress != null) {
        break;
      }
    }

    if (ipAddress == null) {
      print('Could not find a suitable IP address.');
      return;
    }

    var server = await HttpServer.bind(InternetAddress.anyIPv4, 3000);

    print('HTTP server started on $ipAddress:${server.port}');

    await for (var request in server) {
      if (request.method == 'GET' && request.uri.path == '/api/sendText') {
        try {

          var phone = request.uri.queryParameters['phone']!;
          var message = request.uri.queryParameters['text']!;
          print('get request to $phone: $message');
          _stopSending = false;
          _addMessageToQueue(phone, message);
          request.response
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode({'status': 'success'}));
        } catch (e) {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write(jsonEncode({'status': 'error', 'message': e.toString()}));
        }
      } else if (request.method == 'GET' &&
          request.uri.path == '/api/sendTextTogroup') {
        try {
          var phone = request.uri.queryParameters['phone']!;
          var message = request.uri.queryParameters['text']!;
          print('get request to $phone: $message');

          _addMessageToQueue(phone, message, isGroup: true);
          request.response
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode({'status': 'success'}));
        } catch (e) {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write(jsonEncode({'status': 'error', 'message': e.toString()}));
        }
      }

      else if (request.method == 'GET' && request.uri.path == '/api/screenshot') {
        try {
          print('get request to screenshot');

          final capturedImage = await screenshotController.capture(delay: Duration(milliseconds: 10));

          if (capturedImage != null) {
            // Convert the image to bytes
            final imageBytes = capturedImage.buffer.asUint8List();

            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType('image', 'png')
              ..add(imageBytes)
              ..close(); // Close the response after sending the image
          } else {
            throw Exception("Failed to capture screenshot");
          }
        } catch (e) {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write(jsonEncode({'status': 'error', 'message': e.toString()}))
            ..close(); // Close the response in case of an error
        }
      }
      else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found');
      }
      await request.response.close();
    }
  }


  void _addMessageToQueue(String phone, String message,
      {bool isGroup = false}) {
    print('Adding message to queue: $phone: $message');
    setState(() {
      _messageQueue.add(MessageData(
        phone: phone,
        message: message,
        isGroup: isGroup,
      ));
    });
    _processQueue();
  }

  Future<void> _processQueue() async {

    if (_isProcessingQueue || _messageQueue.isEmpty) return;
    print('Processing queue...');
    // print( "_messageQueue: ${_messageQueue}");
    // print("_isProcessingQueue: $_isProcessingQueue");
    print("_stopSending: $_stopSending");
    _isProcessingQueue = true;

    while (_messageQueue.isNotEmpty) {
      if (_stopSending) {
        _isProcessingQueue = false;
        return;
      }

      final messageData = _messageQueue.removeAt(0);

      if (messageData.sendAttempts! >= 1) {
        // Mark message as failed after 3 attempts
        setState(() {
          _failedMessagesCount++;
        });
        _updateStatus();
        continue;
      }

      bool messageSent = false;
      if (messageData.isGroup) {
        messageSent =
            await sendMessageToGroup(messageData.phone, messageData.message);
      } else {
        messageSent = await sendMessage(messageData.phone, messageData.message);
      }

      if (messageSent) {
        setState(() {
          _sentMessagesCount++;
        });
      } else {
        // Increment attempts if message sending failed
        messageData.sendAttempts = (messageData.sendAttempts ?? 0) + 1;
        _messageQueue.add(messageData); // Add back to queue for retry
      }
      _updateStatus();

      // Wait for the specified delay before sending the next message
      await Future.delayed(
          Duration(seconds: int.tryParse(_delayController.text) ?? 5));
    }
    _isProcessingQueue = false;
  }

  void _updateStatus() {
    setState(() {
      _status =
          'تم الارسال: $_sentMessagesCount, حطا بالارسال: $_failedMessagesCount, المتبقي من الرسائل: ${_messageQueue.length}';
    });
  }

  Future<void> initPlatformState() async {
    await web_controller.initialize();

    web_controller.loadingState.listen((url) {
      if (url == LoadingState.navigationCompleted) {
        setState(() {
          _isWebviewReady = true;
        });
      }
    });
    _subscriptions.add(web_controller.url.listen((url) {
      urlController.text = url;
    }));

    _subscriptions
        .add(web_controller.containsFullScreenElementChanged.listen((flag) {
      debugPrint('Contains fullscreen element: $flag');
    }));

    await web_controller.loadUrl('https://web.whatsapp.com/');

    if (!mounted) return;
    setState(() {});
  }

  void sendMessagesToAll() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _stopSending = false;
      _sentMessagesCount = 0;
      _failedMessagesCount = 0;
      _updateStatus(); // Initial status update
    });

    List<String> numbers = _numbersController.text
        .split('\n')
        .map((number) => number.trim())
        .toList();

    for (var number in numbers) {
      if (_stopSending) {
        setState(() {
          _isSending = false;
          _stopSending = true;
        });
        break;
      }
      if (number.isNotEmpty) {
        _addMessageToQueue(number, _textController.text);
      }
    }
  }

  void stopSending() {
    setState(() {
      _stopSending = true;
      _isSending = false;
      _status = 'تم ايقاف الارسال!';
    });
  }

  void _showDetailedMessage(MessageData messageData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حالة الرسائل'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Phone: ${messageData.phone}'),
            Text('Message: ${messageData.message}'),
            Text('Group: ${messageData.isGroup ? 'Yes' : 'No'}'),
            Text('Send Attempts: ${messageData.sendAttempts ?? 0}'),
            Text(
                'Status: ${messageData.sendSuccess == true ? 'تم الارسال' : (messageData.sendSuccess == false ? 'خطا' : 'جاري')}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('اي اي اي'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Padding(
            padding: const EdgeInsets.all(1.0),
            child: ListView(
              shrinkWrap: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              children: <Widget>[
                const SizedBox(height: 20),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,



                  children: <Widget>[

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,                      children: [
                        ElevatedButton(
                          onPressed: _isSending ? null : _showSendMessageDialog,
                          child: Text(_isSending ? 'جاري الارسال...' : 'ارسال رسائل بشكل يدوي'),
                        ),
                        ElevatedButton(
                          onPressed: () => web_controller.openDevTools(),
                          child: Text('Open Dev Tools'),
                        ),
                        ElevatedButton(
                          onPressed: stopSending,
                          child: Text('Stop'),
                        ),
                      ],
                    ),

                    SizedBox(height: 20,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            navigateToSettings(context);
                          },
                          child: Text('اعدادات'),
                        ),

                        ElevatedButton(
                          onPressed: () {
                            showMessagesDialog(context); // Call the function to show the dialog
                          },
                          child: Text('سجل الرسائل'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            server.startServer();
                            await Future.delayed(Duration(seconds: 1));
                            showSas4SusersList(context);

                          },
                          child: Text('ارسال رسائل لمشتركين Sas4'),
                        ),  ElevatedButton(
                          onPressed: () async {
                            await fetchUserData();
                            allUsers.forEach((action){
                              if  (action.phone != null && action.phone.isNotEmpty)
                              print(formatPhoneNumber( action.phone));

                            });


                          },
                          child: Text(' الاكسباير تجربة لستة'),
                        ),
                        // ElevatedButton(
                        //   onPressed: () {
                        //     server.startServer();
                        //   },
                        //   child: Text('test'),
                        // ),




                      ],
                    ),

                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      // Show dialog with message queue details
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Message Queue'),
                          content: _messageQueue.isEmpty
                              ? Text('Message queue is empty.')
                              : Container(
                                  width: double.maxFinite, // Set width to max
                                  height: 300, // Set height as needed
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _messageQueue.length,
                                    itemBuilder: (context, index) {
                                      final messageData = _messageQueue[index];
                                      return ListTile(
                                        title: Text(messageData.phone),
                                        subtitle: Text(messageData
                                                    .message.length >
                                                20
                                            ? '${messageData.message.substring(0, 20)}...'
                                            : messageData.message),
                                        trailing: Icon(
                                          messageData.sendSuccess == true
                                              ? Icons.check_circle
                                              : (messageData.sendSuccess ==
                                                      false
                                                  ? Icons.error
                                                  : Icons.schedule),
                                          color: messageData.sendSuccess == true
                                              ? Colors.green
                                              : (messageData.sendSuccess ==
                                                      false
                                                  ? Colors.red
                                                  : Colors.orange),
                                        ),
                                        onTap: () =>
                                            _showDetailedMessage(messageData),
                                      );
                                    },
                                  ),
                                ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(
                      _status,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: 'URL',
                    hintText: 'Enter the URL to send the message',
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 1000,
                  color: Colors.transparent,
                  child: Screenshot(
                      controller:  screenshotController,
                      child: WhatsAppWebView(webController: web_controller)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showMessagesDialog(BuildContext context) async {
    final selectedPhone = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height - 100, // Adjust height as needed
            child: MessagesScreen(), // Embed the MessagesScreen here
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog without returning any value
              },
            ),
          ],
        );
      },
    );

    if (selectedPhone != null) {
      // Handle the selected phone number here
      print('Selected phone number: $selectedPhone');
      sendMessage(selectedPhone, "");
    }
  }


  Future<void> showSas4SusersList(BuildContext context) async {
     showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height - 100, // Adjust height as needed
            child: Sass4UserListScreen(), // Embed the MessagesScreen here
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog without returning any value
              },
            ),
          ],
        );
      },
    );

  }
  @override
  void dispose() {
    web_controller.dispose();
    _textController.dispose();
    urlController.dispose();
    _numbersController.dispose();
    _delayController.dispose();
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
