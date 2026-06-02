abstract class User {
  final String userId;
  final String name;
  final String lastName;
  final String email;
  final String state;

  // Parametros
  const User({
    required this.userId,
    required this.name,
    required this.lastName,
    required this.email,
    required this.state,
  });
}
