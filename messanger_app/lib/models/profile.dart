import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
      nickName: map['nick_name'] as String?,
      login: map['login'] as String? ?? '',
      bio: map['bio'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      location: map['location'] as String?,
      avatarUrl: rawAvatar == null
          ? null
          : '${dotenv.env['BASE_URL']}/$rawAvatar',
      birthDate: birthDateData as DateTime?,
      gender: map['gender'] as String? ?? 'Не указано',
    );
  }
}
