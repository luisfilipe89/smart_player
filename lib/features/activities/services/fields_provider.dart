import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_fields_service.dart';

final localFieldsServiceProvider =
    Provider<LocalFieldsService>((_) => const LocalFieldsService());

class FieldsActions {
  final LocalFieldsService _local;

  FieldsActions(this._local);

  Future<List<Map<String, dynamic>>> fetchFields({
    required String sportType,
    bool bypassCache = false,
  }) async {
    final local = await _local.loadFields(sportType: sportType);
    if (local != null && local.isNotEmpty) return local;

    return <Map<String, dynamic>>[];
  }
}

final fieldsActionsProvider = Provider<FieldsActions>((ref) {
  final local = ref.watch(localFieldsServiceProvider);
  return FieldsActions(local);
});


