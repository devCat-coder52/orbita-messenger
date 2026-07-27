class User {
  final int id;
  final String login;
  final String? name;
  final String? avatarUrl;

  User({required this.id, required this.login, this.name, this.avatarUrl});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      login: json['login'],
      name: json['name'],
      avatarUrl: json['avatar_url'],
    );
  }
}
