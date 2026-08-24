class User {
  final int id;
  final String login;
  final String? name;
  final String? avatarUrl;
  final String? bio;
  final DateTime? birthDate;
  final String? gender;
  final String? location;

  User({
    required this.id,
    required this.login,
    this.name,
    this.avatarUrl,
    this.bio,
    this.birthDate,
    this.gender,
    this.location,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      login: json['login'],
      name: json['name'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'])
          : null,
      gender: json['gender'],
      location: json['location'],
    );
  }
}
