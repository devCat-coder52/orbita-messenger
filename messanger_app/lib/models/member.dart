import '../utils/json_utils.dart';

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
      id: asIntOr(json['user_id'], -1),
      name: (json['user_name'] ?? 'UNKNOWN').toString(),
      avatarUrl: json['avatar_url'] as String?,
      gender: json['gender'] as String?,
    );
  }

  factory Member.fromMap(Map<String, dynamic> json) {
    return Member(
      id: asIntOr(json['id'], -1),
      name: (json['name'] ?? json['login'] ?? 'UNKNOWN').toString(),
      avatarUrl: json['avatar_url'] as String?,
      gender: json['gender'] as String?,
    );
  }

  factory Member.anonymous() => const Member(id: -1, name: 'UNKNOWN');

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'avatar_url': avatarUrl, 'gender': gender};
  }
}
