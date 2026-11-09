import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';

class Profile {
  final String? nickName;
  final String login;
  final String? bio;
  final String? email;
  final String? phone;
  final String? location;

  final String? avatarUrl;

  final DateTime? birthDate;
  final String gender;

  /// Показывать ли другим, что пользователь в сети.
  final bool showOnline;

  /// Показывать ли другим время последнего визита.
  final bool showLastSeen;

  const Profile({
    this.nickName,
    this.login = '',
    this.bio,
    this.email,
    this.phone,
    this.location,
    this.avatarUrl,
    this.birthDate,
    this.gender = 'Не указано',
    this.showOnline = true,
    this.showLastSeen = true,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    final rawAvatar = map['avatar_url'];
    var birthDateData = map['birth_date'];
    if (birthDateData is Timestamp) {
      birthDateData = birthDateData.toDate();
    } else if (birthDateData is String) {
      birthDateData = DateTime.tryParse(birthDateData);
    } else {
      birthDateData = null;
    }

    return Profile(
      nickName: (map['nick_name'] ?? map['name']) as String?,
      login: map['login'] as String? ?? '',
      bio: map['bio'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      location: map['location'] as String?,
      avatarUrl: rawAvatar == null
          ? null
          : '${AppConfig.baseUrl}/$rawAvatar',
      birthDate: birthDateData as DateTime?,
      gender: map['gender'] as String? ?? 'Не указано',
      showOnline: map['show_online'] != false,
      showLastSeen: map['show_last_seen'] != false,
    );
  }
}
