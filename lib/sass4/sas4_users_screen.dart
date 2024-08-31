import 'package:codecreate_whatsapp_bulk_sender/sass4/sas4_helper.dart';
import 'package:flutter/material.dart';


class Sass4UserListScreen extends StatefulWidget {
  @override
  _Sass4UserListScreenState createState() => _Sass4UserListScreenState();
}

class _Sass4UserListScreenState extends State<Sass4UserListScreen> {
  List<UserData> _users = [];
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await fetchUserData();
      setState(() {
        _users = users;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
      });
      print('Error fetching data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('المشتركين على وشك النفاذ'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(child: Text('Error fetching data'))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Card(
                      color: user.phone.isEmpty ? Colors.black : Colors.white10,
                      margin: EdgeInsets.all(16.0),
                      elevation: 8.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.username,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 12.0),
                            Text('Phone: ${user.phone}', style: Theme.of(context).textTheme.bodySmall),
                            SizedBox(height: 8.0),
                            Text('Expiration: ${user.expiration}', style: Theme.of(context).textTheme.bodySmall),
                            SizedBox(height: 8.0),
                            Text('First Name: ${user.firstname}', style: Theme.of(context).textTheme.bodySmall),
                            SizedBox(height: 8.0),
                            Text('Last Name: ${user.lastname}', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    );

                  },
                ),
    );
  }
}
