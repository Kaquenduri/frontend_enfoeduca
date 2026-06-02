import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthService {
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token != null && !JwtDecoder.isExpired(token)) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      return decodedToken['user_id']?.toString();
    }
    return null;
  }
}
