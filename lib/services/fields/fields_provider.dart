import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/services/fields/local_fields_service.dart';
import 'package:move_young/services/external/overpass_provider.dart';

final localFieldsServiceProvider =
    Provider<LocalFieldsService>((_) => const LocalFieldsService());

class FieldsActions {
  final LocalFieldsService _local;
  final OverpassActions _overpass;
  final bool disableNetwork;

  FieldsActions(this._local, this._overpass, {this.disableNetwork = true});

  Future<List<Map<String, dynamic>>> fetchFields({
    required String areaName,
    required String sportType,
    bool bypassCache = false,
  }) async {
    final local =
        await _local.loadFields(areaName: areaName, sportType: sportType);
    if (local != null && local.isNotEmpty) return local;

    if (!disableNetwork) {
      return _overpass.fetchFields(
        areaName: areaName,
        sportType: sportType,
        bypassCache: bypassCache,
      );
    }

    return <Map<String, dynamic>>[];
  }
}

final fieldsActionsProvider = Provider<FieldsActions>((ref) {
  final local = ref.watch(localFieldsServiceProvider);
  final overpass = ref.watch(overpassActionsProvider);
  return FieldsActions(local, overpass, disableNetwork: true);
});


