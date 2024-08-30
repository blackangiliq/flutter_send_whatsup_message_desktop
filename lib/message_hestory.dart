import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'send_message_helper.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Future<List<MessageData>> _messagesFuture;
  List<MessageData> _messages = [];
  List<MessageData> _filteredMessages = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _messagesFuture = loadMessagesFromJson().then((messages) {
      setState(() {
        _messages = messages;
        _filteredMessages = messages;
      });
      return messages;
    });

    _searchController.addListener(() {
      _filterMessages();
    });
  }

  void _filterMessages() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMessages = _messages.where((message) {
        return message.phone.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _saveResults(String directoryPath) async {
    final successMessages = _messages
        .where((message) => message.sendSuccess ?? false)
        .map((message) => 'Phone: ${message.phone}, Message: ${message.message}')
        .toList();
    final failedMessages = _messages
        .where((message) => !(message.sendSuccess ?? false))
        .map((message) => 'Phone: ${message.phone}, Message: ${message.message}')
        .toList();

    final successContent = successMessages.isNotEmpty
        ? 'Successful Messages:\n\n${successMessages.join('\n')}\n\n'
        : '';
    final failedContent = failedMessages.isNotEmpty
        ? 'Failed Messages:\n\n${failedMessages.join('\n')}'
        : '';

    final successFile = File('$directoryPath/message_results_success.txt');
    await successFile.writeAsString(successContent);

    final failedFile = File('$directoryPath/message_results_failed.txt');
    await failedFile.writeAsString(failedContent);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Results saved to: $directoryPath'),
    ));
  }

  Future<void> _pickDirectoryAndSave() async {
    final directory = await FilePicker.platform.getDirectoryPath();
    if (directory != null) {
      await _saveResults(directory);
    }
  }

  Future<void> deleteAllRecordsFromJson() async {
    try {
      final file = File('messages.json');
      if (await file.exists()) {
        await file.writeAsString('[]'); // Write an empty array to clear the file
        print('All records deleted from messages.json');
      } else {
        print('File not found: messages.json');
      }
    } catch (e) {
      print('Error deleting all records: $e');
    }
  }

// Function to delete a specific record from the JSON file by phone number
  Future<void> deleteRecordFromJsonByPhone(String phoneNumber) async {
    try {
      final file = File('messages.json');
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final updatedJsonList = jsonList.where((item) {
          return item['phone'] != phoneNumber;
        }).toList();
        final updatedJsonString = jsonEncode(updatedJsonList);
        await file.writeAsString(updatedJsonString);
        print('Record with phone number $phoneNumber deleted from messages.json');
      } else {
        print('File not found: messages.json');
      }
    } catch (e) {
      print('Error deleting record: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            onPressed: _pickDirectoryAndSave,
            icon: const Icon(Icons.save),
          ),
          IconButton(
            onPressed: deleteAllRecordsFromJson,
            icon: const Icon(Icons.delete_sweep),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by phone number',
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                ),
                filled: true,
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<MessageData>>(
        future: _messagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No messages found.'));
          } else {
            return ListView.builder(
              itemCount: _filteredMessages.length,
              itemBuilder: (context, index) {
                final messageData = _filteredMessages[index];
                return ListTile(
                  title: Text(
                      'Phone: ${messageData.phone} ${messageData.sendSuccess ?? false ? '✅' : '❌'}'),
                  subtitle: Text('Message: ${messageData.message}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      messageData.isGroup
                          ? const Icon(Icons.group)
                          : const Icon(Icons.person),
                      IconButton(
                        onPressed: () => deleteRecordFromJsonByPhone(messageData.phone),
                        icon: const Icon(Icons.delete, color: Colors.red),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).pop(messageData.phone);
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}