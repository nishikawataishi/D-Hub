import 'campus.dart';

class UserProfile {
  final String id;
  final String name;
  final String faculty;
  final int grade;
  final Campus mainCampus;
  final List<String> interests;
  final String? iconUrl;
  final List<String> photoUrls;

  UserProfile({
    required this.id,
    required this.name,
    required this.faculty,
    required this.grade,
    required this.mainCampus,
    required this.interests,
    this.iconUrl,
    this.photoUrls = const [],
  });

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String docId) {
    return UserProfile(
      id: docId,
      name: data['name'] ?? '未設定',
      faculty: data['faculty'] ?? '未設定',
      grade: data['grade'] ?? 1,
      mainCampus: data['mainCampus'] != null
          ? Campus.fromString(data['mainCampus'])
          : Campus.imadegawa,
      interests: List<String>.from(data['interests'] ?? []),
      iconUrl: data['iconUrl'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'faculty': faculty,
      'grade': grade,
      'mainCampus': mainCampus.name,
      'interests': interests,
      if (iconUrl != null) 'iconUrl': iconUrl,
      'photoUrls': photoUrls,
    };
  }

  UserProfile copyWith({
    String? name,
    String? faculty,
    int? grade,
    Campus? mainCampus,
    List<String>? interests,
    String? iconUrl,
    List<String>? photoUrls,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      faculty: faculty ?? this.faculty,
      grade: grade ?? this.grade,
      mainCampus: mainCampus ?? this.mainCampus,
      interests: interests ?? this.interests,
      iconUrl: iconUrl ?? this.iconUrl,
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }
}
