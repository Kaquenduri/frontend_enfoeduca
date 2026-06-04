import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse(
    'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/users/',
  );
  final response = await http.get(url);
  print(response.statusCode);
  if (response.statusCode == 200) {
    final users = json.decode(response.body);
    print('Total users: ${users.length}');
    if (users.isNotEmpty) print('First: ${users[0]}');
  } else {
    print(response.body);
  }
}
