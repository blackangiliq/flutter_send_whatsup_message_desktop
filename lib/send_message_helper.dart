import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

Future<List<MessageData>> loadMessagesFromJson() async {
  try {
    // Define the file path manually (replace with your actual file path)
    final file = File('messages.json');

    // Check if the file exists
    if (await file.exists()) {
      // Read the JSON string from the file
      final jsonString = await file.readAsString();

      // Decode the JSON string into a List<dynamic>
      final jsonList = jsonDecode(jsonString) as List<dynamic>;

      // Convert the List<dynamic> to a List<MessageData>
      final messages = jsonList.map((item) => MessageData(
        phone: item['phone'],
        message: item['message'],
        isGroup: item['isGroup'] ?? false,
        sendAttempts: item['sendAttempts'] ?? 0,
        sendSuccess: item['sendSuccess'],
      )).toList();

      return messages;
    } else {
      // Return an empty list if file not found
      return [];
    }
  } catch (e) {
    print('Error loading messages: $e');
    return [];
  }
}

final web_controller = WebviewController();
final urlController = TextEditingController();

// JavaScript helper functions
const String _jsHelperFunctions = '''
  function waitForElement(selector, timeout = 5000, parentElement = document) {
    return new Promise((resolve, reject) => {
      const startTime = Date.now();
      const interval = setInterval(() => {
        const element = parentElement.querySelector(selector);
        if (element) {
          clearInterval(interval);
          resolve(element);
        } else if (Date.now() - startTime > timeout) {
          clearInterval(interval);
          resolve(null); 
        }
      }, 100); 
    });
  }
''';

// Function to create the message link and click it
Future<void> _createAndClickMessageLink(String link) async {
  await web_controller.executeScript('''
    function createMessageLink(link) {
      const bulkWhatsappLink = document.getElementById("blkwhattsapplink");
      if (bulkWhatsappLink) {
        bulkWhatsappLink.setAttribute("href", link);
      } else {
        const spanHtml = `<a href="\${link}" id="blkwhattsapplink"></a>`;
        const spans = document.querySelectorAll("#app .app-wrapper-web span");
        spans[4].innerHTML = spanHtml;
      }
      setTimeout(() => {
        document.getElementById("blkwhattsapplink").click();
      }, 500);
    }
    createMessageLink('$link'); 
  ''');
}
Future<void> saveMessageDataToJson(MessageData messageData) async {
  try {
    final file = File('messages.json');
    List<Map<String, dynamic>> existingMessages = [];

    // Load existing messages from the JSON file if it exists
    if (await file.exists()) {
      final jsonString = await file.readAsString();
      existingMessages = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    }

    // Append the new message data to the existing list
    existingMessages.add(messageData.toMap());

    // Convert the updated list of messages to a JSON string
    final jsonString = jsonEncode(existingMessages);

    // Write the JSON string to the file
    await file.writeAsString(jsonString);
    print('Message data saved to messages.json');
  } catch (e) {
    print('Error saving message data: $e');
  }
}


Future<bool> sendMessage(String number, String message) async {
  print("Sending message to $number: $message");

  if (message.isNotEmpty && message.contains("'")) {
    print('Invalid message: $message');
    message = message.replaceAll("'", "");
  }
  if (number.isEmpty) {
    print('Phone number is empty!');
    return false;
  }
  if (number.startsWith('0')) {
    number = number.substring(1);
    if (number.startsWith('0')) {
      number = number.substring(1);
    }
  }

  if (urlController.text.contains("send/?phone=")) {
    await web_controller.loadUrl("https://web.whatsapp.com/");
    await Future.delayed(Duration(seconds: 10));
  }

  try {
    // Inject helper functions
    await web_controller.executeScript(_jsHelperFunctions);

    final encodedText = Uri.encodeComponent(message);
    await _createAndClickMessageLink("https://wa.me/$number?text=$encodedText");

    await web_controller.executeScript('''
  messageSending = true;
     async function sendMessage() {
  try {
    await new Promise(resolve => setTimeout(resolve, 1000));
    const sendButton = await waitForElement('[data-icon="send"]'); 

    if (sendButton) {
      sendButton.click();
      console.log("Send button clicked");
      return true; 
    } else {
      console.log("Button not found");
      messageSending = false;
      return false; 
    }
  } catch (error) {
    console.error("An error occurred:", error); 
    return false; // Return false if an error occurs
  }
}

// Example usage:
sendMessage()
  .then(success => {
    console.log("Message sent successfully:", success);
    return true;
  });
    ''');
    await Future.delayed(Duration(seconds: 2));
    bool doseMessageSent = await checkWhatsappNumber("Phone number shared via url is invalid.");
print("doseMessageSent = $doseMessageSent    and the message not send  ${!doseMessageSent}");
    await saveMessageDataToJson(
      MessageData(phone: number, message: message, isGroup: false , sendSuccess: !doseMessageSent),
    );
    return !doseMessageSent;

  } catch (e) {
    print('Error sending message: $e');
    return false;
  }
}

Future<bool> checkWhatsappNumber(String check_text) async {
  try {
    // Execute the JavaScript function to check if the invalid phone number message exists
    var result = await web_controller.executeScript('''
      var bodyText1 = document.body.innerText || document.body.textContent;
      var isInvalid1 = bodyText1.includes(`$check_text`);
      isInvalid1;
    ''');

    // Print the result in Dart
    print("Invalid phone number detected: $result");

    // Return the result based on whether the phone number is invalid
    return result == true;
  } catch (e) {
    print('Error during the invalid phone number check: $e');
    return false;
  }
}

Future<bool> sendMessageToGroup(String groupLink, String message) async {
  print("Sending group message to $groupLink: $message");

  if (message.isNotEmpty && message.contains("'")) {
    print("message: $message");
    message = message.replaceAll("'", "");
  }
  if (urlController.text.contains("send/?phone=")) {
    await web_controller.loadUrl("https://web.whatsapp.com/");
    await Future.delayed(Duration(seconds: 10));
  }

  try {
    // Inject helper functions
    await web_controller.executeScript(_jsHelperFunctions);

    // Create and click the group link
    await _createAndClickMessageLink(
        "https://web.whatsapp.com/accept?code=$groupLink");

    // Continue with sending the group message
    await web_controller.executeScript('''
      async function sendMessageToGroup(text) {
        await new Promise(resolve => setTimeout(resolve, 5000)); 
        const mainEl = document.querySelector("#main");
        if (!mainEl) {
          return alert("There is no opened conversation");
        }
        const textareaEl = mainEl.querySelector('div[contenteditable="true"]');
        if (!textareaEl) {
          return alert("There is no opened conversation");
        }
        textareaEl.focus();
        document.execCommand("insertText", false, text);
        textareaEl.dispatchEvent(new Event("change", { bubbles: true }));
        const sendButton = await waitForElement('[data-icon="send"]');
        if (sendButton) {
          sendButton.click();
          return true;
        } else {
          console.error("Send button not found");
          return false;
        }
      }
      sendMessageToGroup('$message'); 
    ''');
   await Future.delayed(Duration(seconds: 2));
    bool doseMessageSent = await checkWhatsappNumber("Couldn't join this group. Please try again.");
    print("doseMessageSent = $doseMessageSent    and the message not send  ${!doseMessageSent}");
    await saveMessageDataToJson(
      MessageData(phone: groupLink, message: message, isGroup: true ,sendSuccess: !doseMessageSent),
    );
    return !doseMessageSent;
  } catch (e) {
    print("error: $e");
    return false;
  }
}

class MessageData {
  final String phone;
  final String message;
  final bool isGroup;
  int? sendAttempts;
  bool? sendSuccess;

  MessageData({
    required this.phone,
    required this.message,
    this.isGroup = false,
    this.sendAttempts = 0,
    this.sendSuccess,
  });

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'message': message,
      'isGroup': isGroup,
      'sendAttempts': sendAttempts,
      'sendSuccess': sendSuccess,
    };
  }

  @override
  String toString() {
    return 'MessageData(phone: $phone, message: $message, isGroup: $isGroup, sendAttempts: $sendAttempts, sendSuccess: $sendSuccess)';
  }
}
