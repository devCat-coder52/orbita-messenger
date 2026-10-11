class Member {
  final int id;
  final String name;
  final String? avatarUrl;
  final String? gender;

  const Member({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.gender,
  });

  factory Member.fromObject(Map<String, dynamic> json) {
    return Member(
      id: json['user_id'],
      name: json['user_name'],
      avatarUrl: json['avatar_url'],
      gender: json['gender'],
    );
  }

  factory Member.fromMap(Map<String, dynamic> json) {
    return Member(
      id: json['id'] ?? -1,
      name: (json['name'] ?? json['login'] ?? 'UNKNOWN').toString(),
      avatarUrl: json['avatar_url'],
      gender: json['gender'],
    );
  }

  factory Member.anonymous() => const Member(id: -1, name: 'UNKNOWN');

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'avatar_url': avatarUrl, 'gender': gender};
  }
}
