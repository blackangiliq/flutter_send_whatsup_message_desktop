import 'package:codecreate_whatsapp_bulk_sender/sheard_var.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

List<UserData> allUsers = [];

class UserData {
  final String username;
  final String phone;
  final String expiration;
  final String firstname;
  final String lastname;

  UserData({
    required this.username,
    required this.phone,
    required this.expiration,
    required this.firstname,
    required this.lastname,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      username: json['username'] ?? '',
      phone: json['phone'] ?? '',
      expiration: json['expiration'] ?? '',
      firstname: json['firstname'] ?? '',
      lastname: json['lastname'] ?? '',
    );
  }
}

// Function to fetch user data
Future<List<UserData>> fetchUserData() async {
  final String baseUrl = 'http://localhost:8000/get_user_detels.php';//http://localhost:8000/get_user_detels.php    http://localhost:8080/get_user_details_506.php.bak.json
  final String ip = 'admin.halasat-ftth.iq'; //  213.183.63.188 admin.halasat-ftth.iq
  final String username = 'OMC_Pst_Dis@506_510'; //admin@palestine  OMC_Pst_Dis@506_510
  final String password = '69QV1Ucg<\$1y'; //48654265     69QV1Ucg<\$1y


  int currentPage = 1;
  int lastPage;

  do {
    final String url =
        '$baseUrl?ip=$ip&username=$username&password=$password&page=$currentPage&count=100';

    print(url);
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Extract the last_page value from the response
        lastPage = data['last_page'];

        final List<dynamic> usersJson = data['data'];

        for (var userJson in usersJson) {
          final user = UserData.fromJson(userJson);
          allUsers.add(user);
        }

        currentPage++;
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (e) {
      throw Exception('Failed to load user data: $e');
    }
  } while (currentPage <= lastPage);

  return allUsers;
}
