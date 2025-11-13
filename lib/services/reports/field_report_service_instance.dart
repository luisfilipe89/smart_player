import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/db/db_paths.dart';
import 'package:move_young/models/core/field_report.dart';
import 'package:move_young/services/firebase_error_handler.dart';
import 'package:move_young/utils/logger.dart';
import 'package:move_young/utils/service_error.dart';

import 'field_report_service.dart';

class FieldReportServiceInstance implements IFieldReportService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FieldReportServiceInstance(
    this._auth,
    this._firestore,
  );

  static const _minDescriptionLength = 10;

  @override
  Future<String> submitReport(FieldReportSubmission submission) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('Please sign in before reporting an issue.');
    }

    final fieldId = submission.fieldId.trim();
    final fieldName = submission.fieldName.trim();
    final fieldAddress = submission.fieldAddress?.trim();
    final category = submission.category.trim();
    final description = submission.description.trim();

    if (fieldId.isEmpty || fieldName.isEmpty) {
      throw const ValidationException('Field information is required.');
    }
    if (category.isEmpty) {
      throw const ValidationException('Please select a category.');
    }
    if (description.length < _minDescriptionLength) {
      throw const ValidationException(
        'Please provide a bit more detail about the issue.',
      );
    }

    final docRef =
        _firestore.collection(DbPaths.fieldReports).doc(); // Pre-generate ID

    final payload = <String, dynamic>{
      'fieldId': fieldId,
      'fieldName': fieldName,
      'fieldAddress': fieldAddress,
      'category': category,
      'description': description,
      'allowContact': submission.allowContact,
      'municipalityId': submission.municipalityId,
      'status': 'pending',
      'submittedBy': user.uid,
      'submittedByEmail': user.email,
      'submittedByName': user.displayName,
      'contactEmail':
          submission.allowContact ? (user.email ?? '') : null, // optional
      'contactName':
          submission.allowContact ? (user.displayName ?? '') : null, // optional
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'source': 'mobile',
    }
      ..removeWhere(
        (key, value) =>
            value == null || (value is String && value.trim().isEmpty),
      );

    try {
      await docRef.set(payload);
      return docRef.id;
    } catch (error) {
      NumberedLogger.e('❌ Failed to submit field report: $error');
      throw FirebaseErrorHandler.toServiceException(error);
    }
  }
}

