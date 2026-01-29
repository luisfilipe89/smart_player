import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/models/core/field_report.dart';
import 'package:move_young/providers/infrastructure/firebase_providers.dart';

import 'field_report_service.dart';
import 'field_report_service_instance.dart';

final fieldReportServiceProvider = Provider<IFieldReportService>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = FirebaseFirestore.instance;
  return FieldReportServiceInstance(auth, firestore);
});

class FieldReportActions {
  final IFieldReportService _service;

  FieldReportActions(this._service);

  Future<String> submit(FieldReportSubmission submission) {
    return _service.submitReport(submission);
  }
}

final fieldReportActionsProvider = Provider<FieldReportActions>((ref) {
  final service = ref.watch(fieldReportServiceProvider);
  return FieldReportActions(service);
});
