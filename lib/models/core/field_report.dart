import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable representation of a field issue report stored in Firestore.
class FieldReport {
  final String id;
  final String fieldId;
  final String fieldName;
  final String? fieldAddress;
  final String category;
  final String description;
  final bool allowContact;
  final String status;
  final String submittedBy;
  final String? municipalityId;
  final String? contactEmail;
  final String? contactName;
  final String? submittedByEmail;
  final String? submittedByName;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const FieldReport({
    required this.id,
    required this.fieldId,
    required this.fieldName,
    this.fieldAddress,
    required this.category,
    required this.description,
    required this.allowContact,
    required this.status,
    required this.submittedBy,
    this.municipalityId,
    this.contactEmail,
    this.contactName,
    this.submittedByEmail,
    this.submittedByName,
    this.createdAt,
    this.updatedAt,
  });

  factory FieldReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return FieldReport(
      id: snapshot.id,
      fieldId: (data['fieldId'] ?? '') as String,
      fieldName: (data['fieldName'] ?? '') as String,
      fieldAddress: data['fieldAddress'] as String?,
      category: (data['category'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      allowContact: (data['allowContact'] ?? false) as bool,
      status: (data['status'] ?? 'pending') as String,
      submittedBy: (data['submittedBy'] ?? '') as String,
      municipalityId: data['municipalityId'] as String?,
      contactEmail: data['contactEmail'] as String?,
      contactName: data['contactName'] as String?,
      submittedByEmail: data['submittedByEmail'] as String?,
      submittedByName: data['submittedByName'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }
}

/// Payload used when submitting a new field report.
class FieldReportSubmission {
  final String fieldId;
  final String fieldName;
  final String category;
  final String description;
  final bool allowContact;
  final String? municipalityId;
  final String? fieldAddress;

  const FieldReportSubmission({
    required this.fieldId,
    required this.fieldName,
    required this.category,
    required this.description,
    this.allowContact = false,
    this.municipalityId,
    this.fieldAddress,
  });

  FieldReportSubmission copyWith({
    String? fieldId,
    String? fieldName,
    String? category,
    String? description,
    bool? allowContact,
    String? municipalityId,
    String? fieldAddress,
  }) {
    return FieldReportSubmission(
      fieldId: fieldId ?? this.fieldId,
      fieldName: fieldName ?? this.fieldName,
      category: category ?? this.category,
      description: description ?? this.description,
      allowContact: allowContact ?? this.allowContact,
      municipalityId: municipalityId ?? this.municipalityId,
      fieldAddress: fieldAddress ?? this.fieldAddress,
    );
  }
}
