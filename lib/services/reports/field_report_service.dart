import 'package:move_young/models/core/field_report.dart';

abstract class IFieldReportService {
  /// Stores a new field issue report and returns the generated report ID.
  Future<String> submitReport(FieldReportSubmission submission);
}
