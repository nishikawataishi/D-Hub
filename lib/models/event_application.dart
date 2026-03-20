import 'package:cloud_firestore/cloud_firestore.dart';

/// イベント申し込みのステータス
enum ApplicationStatus {
  applied,   // 申し込み済み（審査中）
  accepted,  // 承認済み
  rejected;  // 却下

  String get label {
    switch (this) {
      case ApplicationStatus.applied:
        return '審査中';
      case ApplicationStatus.accepted:
        return '承認済み';
      case ApplicationStatus.rejected:
        return '却下';
    }
  }

  static ApplicationStatus fromString(String value) {
    switch (value) {
      case 'accepted':
        return ApplicationStatus.accepted;
      case 'rejected':
        return ApplicationStatus.rejected;
      default:
        return ApplicationStatus.applied;
    }
  }
}

/// イベント参加申し込みデータモデル
/// Firestoreパス: events/{eventId}/applications/{studentId}
class EventApplication {
  final String id;         // ドキュメントID（= studentId）
  final String eventId;
  final String studentId;
  final String studentName;
  final String studentFaculty;
  final int studentGrade;
  final String? studentIconUrl;
  final ApplicationStatus status;
  final DateTime appliedAt;
  final DateTime? respondedAt;

  const EventApplication({
    required this.id,
    required this.eventId,
    required this.studentId,
    required this.studentName,
    required this.studentFaculty,
    required this.studentGrade,
    this.studentIconUrl,
    required this.status,
    required this.appliedAt,
    this.respondedAt,
  });

  factory EventApplication.fromFirestore(
    Map<String, dynamic> data,
    String id,
    String eventId,
  ) {
    return EventApplication(
      id: id,
      eventId: eventId,
      studentId: data['studentId'] as String? ?? id,
      studentName: data['studentName'] as String? ?? '未設定',
      studentFaculty: data['studentFaculty'] as String? ?? '未設定',
      studentGrade: data['studentGrade'] as int? ?? 1,
      studentIconUrl: data['studentIconUrl'] as String?,
      status: ApplicationStatus.fromString(data['status'] as String? ?? 'applied'),
      appliedAt: (data['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentFaculty': studentFaculty,
      'studentGrade': studentGrade,
      if (studentIconUrl != null) 'studentIconUrl': studentIconUrl,
      'status': status.name,
      'appliedAt': Timestamp.fromDate(appliedAt),
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
    };
  }
}
