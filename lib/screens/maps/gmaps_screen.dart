import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:move_young/theme/tokens.dart';

class GenericMapScreen extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> locations;

  const GenericMapScreen({
    super.key,
    required this.title,
    required this.locations,
  });

  @override
  State<GenericMapScreen> createState() => _GenericMapScreenState();
}

class _GenericMapScreenState extends State<GenericMapScreen> {
  static const double _defaultZoom = 13;

  Map<String, dynamic>? _selectedLocation;
  GoogleMapController? _mapController;
  Position? _userPosition;
  String? _locationError;
  String? _selectedMarkerId;
  final Set<Marker> _markers = {};

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
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      final locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
      );

      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      setState(() {
        _userPosition = position;
      });
      _setLocationMarkers();
    } catch (e) {
      if (e.toString().contains('PERMISSION DENIED')) {
        setState(() {
          _locationError = 'location_denied'.tr();
        });
      } else {
        setState(() {
          _locationError = 'failed_location'.tr();
        });
      }
      debugPrint("Failed to get location: $e");
    }
  }

  void _fitMapToBounds(List<LatLng> positions) {
    if (_mapController == null || positions.length < 2) return;
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
      final parsedLat = double.tryParse(loc['lat'].toString());
      final parsedLon = double.tryParse(loc['lon'].toString());
      if (parsedLat == null || parsedLon == null) continue;

      final position = LatLng(parsedLat, parsedLon);
      positions.add(position);

      final lit = loc['lit'] == 'yes' || loc['lit'] == true;
      final markerId = '$parsedLat-$parsedLon';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _locationError != null
          ? Center(
              child: Text(
                _locationError!,
                style: AppTextStyles.cardTitle,
                textAlign: TextAlign.center,
              ),
            )
          : _userPosition == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          _userPosition!.latitude,
                          _userPosition!.longitude,
                        ),
                        zoom: _defaultZoom,
                      ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      markers: _markers,
                      onMapCreated: (controller) => _mapController = controller,
                      onTap: (_) {
                        setState(() {
                          _selectedLocation = null;
                        });
                      },
                    ),
                    Positioned(
                      left: 8,
                      bottom: 28, // slightly above Google logo
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.7),
                        padding: AppPaddings.symmSuperSmall,
                        child: const Text(
                          '© OpenStreetMap contributors (ODbL)',
                          style: AppTextStyles.superSmall,
                        ),
                      ),
                    ),
                  ],
                ),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
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
                          const SizedBox(width: AppWidths.big),
                          ElevatedButton.icon(
                            onPressed: () {
                              final lat = _selectedLocation!['lat'];
                              final lon = _selectedLocation!['lon'];
                              final gmapsLink =
                                  'https://maps.google.com/?q=$lat,$lon';
                              Share.share(
                                  'check_location'.tr(args: [gmapsLink]));
                            },
                            icon: const Icon(Icons.share),
                            label: Text("share_location".tr()),
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
