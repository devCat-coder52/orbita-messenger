class Member {
  final int id;
  final String name;
  final String? avatarUrl;
  final String? gender;

  Member({required this.id, required this.name, this.avatarUrl, this.gender});

  factory Member.fromObject(Map<String, dynamic> json) {
    return Member(
      id: json['user_id'],
      name: json['user_name'],
      avatarUrl: json['avatar_url'],
      gender: json['gender'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'avatar_url': avatarUrl, 'gender': gender};
  }
}
