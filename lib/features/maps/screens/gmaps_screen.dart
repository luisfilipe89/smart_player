import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/models/core/field_report.dart';
import 'package:move_young/services/firebase_error_handler.dart';
import 'package:move_young/services/reports/field_report_provider.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/services/system/location_provider.dart';
import 'package:move_young/utils/type_converters.dart';
import 'package:move_young/utils/logger.dart';

class GenericMapScreen extends ConsumerStatefulWidget {
  final String title;
  final List<Map<String, dynamic>> locations;

  const GenericMapScreen({
    super.key,
    required this.title,
    required this.locations,
  });

  @override
  ConsumerState<GenericMapScreen> createState() => _GenericMapScreenState();
}

class _GenericMapScreenState extends ConsumerState<GenericMapScreen> {
  static const double _defaultZoom = 13;

  Map<String, dynamic>? _selectedLocation;
  GoogleMapController? _mapController;
  Position? _userPosition;
  String? _locationError;
  String? _selectedMarkerId;
  final Set<Marker> _markers = {};
  LatLng? _fallbackCameraTarget;

  //Local helper for capitalization
  String _titleCase(String s) {
    return s
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    if (widget.locations.isNotEmpty) {
      // Ensure we render any provided locations even if GPS lookup is slow.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _setLocationMarkers();
        }
      });
    }
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      final position = await ref
          .read(locationActionsProvider)
          .getCurrentPosition(accuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _userPosition = position;
      });
      _setLocationMarkers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = ref.read(locationActionsProvider).mapError(e);
      });
      NumberedLogger.e("Failed to get location: $e");
    }
  }

  LatLng? _parseLatLng(Map<String, dynamic> loc) {
    final latValue = loc['lat'] ?? loc['latitude'];
    final lonValue = loc['lon'] ?? loc['longitude'];
    final parsedLat = safeToDouble(latValue);
    final parsedLon = safeToDouble(lonValue);

    if (parsedLat == null || parsedLon == null) return null;
    return LatLng(parsedLat, parsedLon);
  }

  void _fitMapToBounds(List<LatLng> positions) {
    if (_mapController == null || positions.isEmpty) return;

    if (positions.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(positions.first, _defaultZoom),
      );
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(
        positions.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
        positions.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        positions.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
        positions.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
      ),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _setLocationMarkers({bool fitBounds = true}) {
    final markers = <Marker>{};
    final positions = <LatLng>[];

    for (var loc in widget.locations) {
      final position = _parseLatLng(loc);
      if (position == null) continue;

      _fallbackCameraTarget ??= position;
      positions.add(position);

      final rawLit = loc['lit'] ?? loc['lighting'];
      final lit = rawLit == 'yes' || rawLit == true;
      final markerId = '${position.latitude}-${position.longitude}';
      final isSelected = markerId == _selectedMarkerId;

      final markerColor = BitmapDescriptor.defaultMarkerWithHue(
        isSelected
            ? BitmapDescriptor.hueGreen
            : lit
                ? BitmapDescriptor.hueYellow
                : BitmapDescriptor.hueRed,
      );

      markers.add(
        Marker(
          markerId: MarkerId(markerId),
          position: position,
          icon: markerColor,
          onTap: () {
            setState(() {
              _selectedLocation = loc;
              _selectedMarkerId = markerId;
            });
            _setLocationMarkers(fitBounds: false);
            _mapController?.animateCamera(
              CameraUpdate.newLatLng(position),
            );
          },
        ),
      );
    }

    if (_userPosition != null) {
      final userLatLng =
          LatLng(_userPosition!.latitude, _userPosition!.longitude);
      markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: userLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: 'you'.tr()),
        ),
      );
      positions.add(userLatLng);
    }

    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });

    if (fitBounds) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _fitMapToBounds(positions);
      });
    }
  }

  Future<void> _openReportSheet() async {
    final location = _selectedLocation;
    if (location == null) return;

    final rawId = location['id']?.toString() ?? '';
    final lat = location['lat']?.toString() ?? location['latitude']?.toString();
    final lon =
        location['lon']?.toString() ?? location['longitude']?.toString();
    final fallbackId = rawId.isNotEmpty
        ? rawId
        : 'loc:${lat ?? 'unknown'}:${lon ?? 'unknown'}';
    final rawName = location['name']?.toString() ?? '';
    final fieldName =
        rawName.trim().isNotEmpty ? rawName.trim() : 'unnamed_location'.tr();
    final addressDisplay =
        location['address_display_name']?.toString().trim() ?? '';
    final addressShort =
        location['address_super_short']?.toString().trim() ?? '';
    final addressAlt = location['addressSuperShort']?.toString().trim() ?? '';
    final fieldAddress = () {
      if (addressDisplay.isNotEmpty) return addressDisplay;
      if (addressAlt.isNotEmpty) return addressAlt;
      if (addressShort.isNotEmpty) return addressShort;
      return null;
    }();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FieldReportSheet(
        fieldId: fallbackId,
        fieldName: fieldName,
        fieldAddress: fieldAddress,
      ),
    );

    if (!mounted || result != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('field_report_submitted'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _userPosition != null
        ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
        : _fallbackCameraTarget ??
            (widget.locations.isNotEmpty
                ? (_parseLatLng(widget.locations.first) ??
                    const LatLng(52.0907, 5.1214))
                : const LatLng(52.0907, 5.1214));

    final canRenderMap = _userPosition != null || _fallbackCameraTarget != null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _locationError != null
          ? (!canRenderMap
              ? _LocationErrorView(
                  message: _locationError!,
                  onOpenSettings: () async {
                    await ref.read(locationActionsProvider).openSettings();
                  },
                  onRetry: _initializeMap,
                )
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: initialTarget,
                        zoom: _defaultZoom,
                      ),
                      myLocationEnabled: _userPosition != null,
                      myLocationButtonEnabled: _userPosition != null,
                      markers: _markers,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (_markers.isEmpty) {
                          _setLocationMarkers();
                        } else {
                          _fitMapToBounds(
                            _markers
                                .map((m) => m.position)
                                .toList(growable: false),
                          );
                        }
                      },
                      onTap: (_) {
                        setState(() {
                          _selectedLocation = null;
                          _selectedMarkerId = null;
                        });
                      },
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      right: 8,
                      child: Material(
                        color: _locationError == null
                            ? Colors.transparent
                            : AppColors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                        child: _locationError == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: AppPaddings.allSmall,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: AppColors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _locationError!,
                                        style: AppTextStyles.small,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _initializeMap,
                                      child: Text('retry'.tr()),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: AppPaddings.symmSuperSmall,
                        child: const Text(
                          '© OpenStreetMap contributors (ODbL)',
                          style: AppTextStyles.superSmall,
                        ),
                      ),
                    ),
                  ],
                ))
          : (!canRenderMap
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: initialTarget,
                        zoom: _defaultZoom,
                      ),
                      myLocationEnabled: _userPosition != null,
                      myLocationButtonEnabled: _userPosition != null,
                      markers: _markers,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (_markers.isEmpty) {
                          _setLocationMarkers();
                        } else {
                          _fitMapToBounds(
                            _markers
                                .map((m) => m.position)
                                .toList(growable: false),
                          );
                        }
                      },
                      onTap: (_) {
                        setState(() {
                          _selectedLocation = null;
                          _selectedMarkerId = null;
                        });
                      },
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: AppPaddings.symmSuperSmall,
                        child: const Text(
                          '© OpenStreetMap contributors (ODbL)',
                          style: AppTextStyles.superSmall,
                        ),
                      ),
                    ),
                  ],
                )),
      bottomSheet: _selectedLocation == null
          ? null
          : SafeArea(
              child: SingleChildScrollView(
                child: Container(
                  padding: AppPaddings.allReg,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.card)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '📍 ${_selectedLocation!['name'] ?? 'unnamed_location'.tr()}',
                          style: AppTextStyles.cardTitle),
                      const SizedBox(height: AppHeights.small),
                      Builder(
                        builder: (context) {
                          final rawSurface =
                              (_selectedLocation?['surface'] ?? '').toString();
                          final surfaceLabel = rawSurface.isNotEmpty
                              ? _titleCase(rawSurface.replaceAll('_', ' '))
                              : 'unknown'.tr();

                          final litLabel = _selectedLocation?['lit'] == 'yes'
                              ? '\n💡 ${'lit'.tr()}'
                              : '';

                          return Text(
                            '$surfaceLabel$litLabel',
                            style: AppTextStyles.body,
                          );
                        },
                      ),
                      const SizedBox(height: AppHeights.big),
                      const Divider(height: 24),
                      ElevatedButton.icon(
                        onPressed: _openReportSheet,
                        icon: const Icon(Icons.report_problem_outlined),
                        label: Text('field_report_button'.tr()),
                      ),
                      const SizedBox(height: AppHeights.reg),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final lat = _selectedLocation!['lat'];
                                final lon = _selectedLocation!['lon'];
                                final uri = Uri.parse(
                                  'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon',
                                );
                                launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              icon: const Icon(Icons.directions),
                              label: Text("directions".tr()),
                            ),
                          ),
                          const SizedBox(width: AppWidths.small),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final lat = _selectedLocation!['lat'];
                                final lon = _selectedLocation!['lon'];
                                final gmapsLink =
                                    'https://maps.google.com/?q=$lat,$lon';
                                Share.share(
                                  'check_location'.tr(args: [gmapsLink]),
                                );
                              },
                              icon: const Icon(Icons.share),
                              label: Text("share_location".tr()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class FieldReportSheet extends ConsumerStatefulWidget {
  final String fieldId;
  final String fieldName;
  final String? fieldAddress;

  const FieldReportSheet({
    super.key,
    required this.fieldId,
    required this.fieldName,
    this.fieldAddress,
  });

  @override
  ConsumerState<FieldReportSheet> createState() => _FieldReportSheetState();
}

class _FieldReportSheetState extends ConsumerState<FieldReportSheet> {
  static const List<_ReportCategoryOption> _categoryOptions = [
    _ReportCategoryOption('surface_damage', 'field_report_category_surface'),
    _ReportCategoryOption('lighting', 'field_report_category_lighting'),
    _ReportCategoryOption('booking', 'field_report_category_booking'),
    _ReportCategoryOption('other', 'field_report_category_other'),
  ];

  late final TextEditingController _descriptionController;
  String _selectedCategory = _categoryOptions.first.value;
  bool _allowContact = false;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final description = _descriptionController.text.trim();

    if (description.length < 10) {
      setState(() {
        _errorMessage = 'field_report_error_description'.tr();
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _submitting = true;
    });

    try {
      await ref.read(fieldReportActionsProvider).submit(
            FieldReportSubmission(
              fieldId: widget.fieldId,
              fieldName: widget.fieldName,
              fieldAddress: widget.fieldAddress,
              category: _selectedCategory,
              description: description,
              allowContact: _allowContact,
            ),
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = FirebaseErrorHandler.getUserMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: AppPaddings.allReg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppHeights.reg),
                  decoration: BoxDecoration(
                    color: AppColors.lightgrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'field_report_title'.tr(),
                style: AppTextStyles.cardTitle,
              ),
              const SizedBox(height: AppHeights.superSmall),
              Text(
                widget.fieldName,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackText,
                ),
              ),
              if (widget.fieldAddress != null &&
                  widget.fieldAddress!.trim().isNotEmpty) ...[
                const SizedBox(height: AppHeights.superSmall),
                Text(
                  widget.fieldAddress!,
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.grey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppHeights.small),
              Text(
                'field_report_intro'.tr(),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppHeights.big),
              Text(
                'field_report_category_label'.tr(),
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppHeights.small),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categoryOptions
                    .map(
                      (option) => ChoiceChip(
                        label: Text(option.labelKey.tr()),
                        selected: _selectedCategory == option.value,
                        onSelected: (selected) {
                          if (!selected) return;
                          setState(() => _selectedCategory = option.value);
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: AppHeights.big),
              TextField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'field_report_description_label'.tr(),
                  hintText: 'field_report_description_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppHeights.reg),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('field_report_allow_contact'.tr()),
                subtitle: Text('field_report_allow_contact_hint'.tr()),
                value: _allowContact,
                onChanged: (value) => setState(() => _allowContact = value),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppHeights.small),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.small.copyWith(color: AppColors.red),
                ),
              ],
              const SizedBox(height: AppHeights.big),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('field_report_submit_button'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCategoryOption {
  final String value;
  final String labelKey;

  const _ReportCategoryOption(this.value, this.labelKey);
}

class _LocationErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  const _LocationErrorView({
    required this.message,
    required this.onOpenSettings,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppPaddings.allReg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTextStyles.cardTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppHeights.reg),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: onRetry,
                  child: Text('retry'.tr()),
                ),
                const SizedBox(width: AppWidths.regular),
                ElevatedButton(
                  onPressed: onOpenSettings,
                  child: Text('open_settings'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
