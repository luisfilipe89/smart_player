import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:move_young/services/external/overpass_provider.dart';
import 'package:move_young/screens/maps/gmaps_screen.dart';
import 'package:move_young/widgets/navigation/reverse_geocoding.dart';
import 'package:move_young/widgets/sports/sport_field_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/config/_config.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/system/location_service.dart';

// Top-level function for isolate processing (distance calculations)
List<Map<String, dynamic>> _processLocationsIsolate(
    Map<String, dynamic> params) {
  final locations = params['locations'] as List<Map<String, dynamic>>;
  final userLat = params['userLat'] as double;
  final userLon = params['userLon'] as double;

  for (var loc in locations) {
    final lat = loc['lat'];
    final lon = loc['lon'];

    final distance = Geolocator.distanceBetween(
      userLat,
      userLon,
      lat ?? 0,
      lon ?? 0,
    );
    loc['distance'] = distance.isFinite ? distance : double.infinity;
  }

  locations.sort(
      (a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
  return locations;
}

class GenericSportScreen extends ConsumerStatefulWidget {
  final String title;
  final String sportType;

  const GenericSportScreen({
    super.key,
    required this.title,
    required this.sportType,
  });

  @override
  ConsumerState<GenericSportScreen> createState() => _GenericSportScreenState();
}

class _GenericSportScreenState extends ConsumerState<GenericSportScreen>
    with AutomaticKeepAliveClientMixin {
  Set<String> _favoriteIds = {}; // ✅ Favorite locations
  List<Map<String, dynamic>> _allLocations = [];
  List<Map<String, dynamic>> _filteredLocations = [];
  bool _isLoading = true;
  String? _error;
  Position? _userPosition;
  Timer? _debounce;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, String> _locationCache = {};

  late final List<FilterDefinition> _filters;

  final FilterSelection _selection = FilterSelection(
    choiceSelections: {},
    toggles: {'lit': false},
  );

  @override
  void initState() {
    super.initState();
    _filters = SportFiltersRegistry.buildForSport(widget.sportType);
    _loadFavorites();
    _loadData();
    _searchController
        .addListener(() => _onSearchChanged(_searchController.text));
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteIds =
          prefs.getStringList('favoriteSportLocations')?.toSet() ?? {};
    });
  }

  Future<void> _toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
      prefs.setStringList('favoriteSportLocations', _favoriteIds.toList());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = query;
        _applyFilters();
      });
    });
  }

  Future<void> _loadData({bool bypassCache = false}) async {
    try {
      final pos = await const LocationService()
          .getCurrentPosition(accuracy: LocationAccuracy.best);
      _userPosition = pos;

      final overpassActions = ref.read(overpassActionsProvider);
      final locations = await overpassActions.fetchFields(
        areaName: "'s-Hertogenbosch",
        sportType: widget.sportType,
        bypassCache: bypassCache,
      );

      // Process distance calculations in isolate to avoid blocking UI
      final processedLocations = await compute(_processLocationsIsolate, {
        'locations': List<Map<String, dynamic>>.from(locations),
        'userLat': _userPosition!.latitude,
        'userLon': _userPosition!.longitude,
      });

      // Set display names (with name if available, otherwise defer reverse geocoding)
      for (var loc in processedLocations) {
        if (loc['name'] != null && loc['name'].toString().trim().isNotEmpty) {
          loc['displayName'] = loc['name'];
        } else {
          // Defer reverse geocoding - will be lazy loaded when needed
          final key = '${loc['lat']},${loc['lon']}';
          loc['displayName'] = 'Loading...'; // Temporary placeholder
          loc['_needsGeocoding'] = true;
          loc['_geocodingKey'] = key;
        }
        if (!mounted) return;
      }

      if (!mounted) return;
      setState(() {
        _allLocations = processedLocations;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = const LocationService().mapError(e);
        _isLoading = false;
      });
      debugPrint('Error in _loadData: $e');
    }
  }

  Future<void> _loadStreetNameIfNeeded(Map<String, dynamic> loc) async {
    if (loc['_needsGeocoding'] == true && loc['displayName'] == 'Loading...') {
      final key = loc['_geocodingKey'] as String;
      if (_locationCache.containsKey(key)) {
        setState(() {
          loc['displayName'] = _locationCache[key];
          loc['_needsGeocoding'] = false;
        });
      } else {
        try {
          final streetName = await getNearestStreetName(
            loc['lat'] as double,
            loc['lon'] as double,
          );
          _locationCache[key] = streetName;
          setState(() {
            loc['displayName'] = streetName;
            loc['_needsGeocoding'] = false;
          });
        } catch (e) {
          setState(() {
            loc['displayName'] = 'Unknown Location';
            loc['_needsGeocoding'] = false;
          });
        }
      }
    }
  }

  void _applyFilters() {
    _filteredLocations = _allLocations.where((field) {
      final name = (field['name'] ?? '').toString().toLowerCase();
      final address = (field['addr:street'] ?? '').toString().toLowerCase();

      if (_searchQuery.isNotEmpty &&
          !name.contains(_searchQuery.toLowerCase()) &&
          !address.contains(_searchQuery.toLowerCase())) {
        return false;
      }

      return matchesFilters(
        sportType: widget.sportType,
        location: field,
        selection: _selection,
      );
    }).toList();
  }

  void _openMapWithFiltered() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GenericMapScreen(
          title: widget.title,
          locations: _filteredLocations,
        ),
      ),
    );
  }

  void _openDirections(String lat, String lon) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=walking';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('could_not_open_maps'.tr())),
      );
    }
  }

  Future<void> _shareLocation(String name, String lat, String lon) async {
    final message = "Meet me at $name! 📍 https://maps.google.com/?q=$lat,$lon";
    await Share.share(message);
  }

  String _formatDistance(double distance) {
    if (distance == double.infinity) return 'distance_unknown'.tr();
    return distance < 1000
        ? '${distance.toStringAsFixed(0)} m away'
        : '${(distance / 1000).toStringAsFixed(1)} km away';
  }

  Future<String> _getDisplayName(Map<String, dynamic> loc) async {
    // If name exists, use it
    if (loc['name'] != null && loc['name'].toString().trim().isNotEmpty) {
      return loc['name'];
    }

    // Check if already has displayName (from initial load or cache)
    if (loc['displayName'] != null && loc['displayName'] != 'Loading...') {
      return loc['displayName'];
    }

    // If needs geocoding, load it
    if (loc['_needsGeocoding'] == true) {
      await _loadStreetNameIfNeeded(loc);
      return loc['displayName'] ?? 'Unknown Location';
    }

    // Fallback: direct geocoding
    final lat = loc['lat'];
    final lon = loc['lon'];
    final key = '$lat,$lon';

    if (_locationCache.containsKey(key)) {
      final streetName = _locationCache[key]!;
      loc['displayName'] = streetName;
      return streetName;
    }

    final streetName = await getNearestStreetName(lat, lon);
    _locationCache[key] = streetName;
    loc['displayName'] = streetName;
    return streetName;
  }

  bool _truthy(String? v) {
    final s = v?.toLowerCase();
    return s == 'yes' || s == 'true' || s == '1' || s == 'y';
  }

  // Amber bulb: outline only when off; outline + fill stacked when on
  Widget _bulbGlyph(bool on) {
    const size = 18.0;
    if (on) {
      return Stack(
        alignment: Alignment.center,
        children: const [
          Icon(Icons.lightbulb_outline, size: size, color: Colors.amber),
          Icon(Icons.lightbulb, size: size - 1, color: Colors.amber),
        ],
      );
    }
    return const Icon(Icons.lightbulb_outline, size: size, color: Colors.amber);
  }

// Make soccer 'surface' icons green (grass / artificial_turf)
  Color? _surfaceIconColor(String key, String? value) {
    if (key == 'surface' && (value == 'grass' || value == 'artificial_turf')) {
      return Colors.green; // tweak shade if you want
    }
    return null; // default color
  }

  Widget _buildCharacteristicsRow(Map<String, dynamic> field) {
    final tags = (field['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final keys = SportCharacteristics.get(widget.sportType);

    final List<Widget> characteristics = [];

    for (final key in keys) {
      final rawValue = tags[key]?.toString();
      final label = SportCharacteristics.labelFor(key, rawValue);
      final labelToShow = label.isEmpty ? '-' : label;

      // Default icon via composed key; toggles like 'lit' pass only the key
      Widget leading;
      Color textColor = AppColors.grey;

      if (key == 'lit') {
        final isLit = _truthy(rawValue);
        leading = _bulbGlyph(isLit); // ← amber glyphs
        textColor = isLit ? AppColors.amber : AppColors.grey;
      } else {
        final iconData =
            SportDisplayRegistry.iconFor(widget.sportType, key, rawValue) ??
                Icons.info_outline;
        final color = _surfaceIconColor(key, rawValue) ??
            AppColors.grey; // ← green for grass/artificial
        leading = Icon(iconData, size: 18, color: color);
      }

      characteristics.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 6),
          Text(labelToShow,
              style: AppTextStyles.small.copyWith(color: textColor)),
        ],
      ));
    }

    return Padding(
      padding: AppPaddings.topSuperSmall,
      child: Wrap(
        spacing: AppSpacing.content,
        runSpacing: 4,
        children: characteristics.isNotEmpty
            ? characteristics
            : [
                Text('no_characteristics_available'.tr(),
                    style: const TextStyle(color: AppColors.darkgrey))
              ],
      ),
    );
  }

  Widget _chipLabel({required Widget leading, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTextStyles.small.copyWith(color: AppColors.blackText),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    if (_filters.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final neutralBg = AppColors.superlightgrey;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: AppPaddings.symmHorizontalReg,
      child: ChipTheme(
        data: theme.chipTheme.copyWith(
          backgroundColor: neutralBg,
          selectedColor: neutralBg,
          disabledColor: neutralBg,
          labelStyle: AppTextStyles.small.copyWith(color: AppColors.blackText),
          secondaryLabelStyle:
              AppTextStyles.small.copyWith(color: AppColors.blackText),
          side: const BorderSide(color: Colors.transparent),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: const StadiumBorder(),
        ),
        child: Row(
          children: _filters.expand((def) {
            // ---------- CHOICE FILTERS (e.g., surface: grass/artificial) ----------
            if (def.type == FilterType.choice) {
              final selectedValue = _selection.choiceSelections[def.key];

              return def.options.map((opt) {
                final isSelected = selectedValue == opt.value;

                // pick accent: option > filter > none
                final Color? accent = opt.accentColor ?? def.accentColor;

                final icon = SportDisplayRegistry.iconFor(
                      widget.sportType,
                      def.key,
                      opt.value,
                    ) ??
                    Icons.tune;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: _chipLabel(
                      leading: Icon(
                        icon,
                        size: 18,
                        color: isSelected
                            ? (accent ?? AppColors.grey)
                            : AppColors.grey,
                      ), // green for grass/artificial
                      text: opt.label,
                    ),
                    selected: isSelected,
                    showCheckmark: false,
                    side: BorderSide(
                      color: isSelected
                          ? (accent ?? AppColors.blackShadow)
                          : Colors.transparent,
                    ),
                    onSelected: (on) {
                      setState(() {
                        _selection.choiceSelections[def.key] =
                            (on && !isSelected)
                                ? opt.value
                                : null; // tap to select, tap again to clear
                        _applyFilters();
                      });
                    },
                  ),
                );
              }).toList();
            }

            // ---------- TOGGLE FILTERS (e.g., lit) ----------
            final on = _selection.toggles[def.key] ?? false;
            final Color? accent = def.accentColor; // e.g., amber for 'lit'

            return [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  showCheckmark: false,
                  selected: on,
                  // same neutral bg on/off
                  backgroundColor: neutralBg,
                  selectedColor: neutralBg,
                  // thin amber outline when ON
                  side: BorderSide(
                    color: on
                        ? (accent ?? AppColors.blackShadow)
                        : Colors.transparent,
                  ),
                  label: _chipLabel(
                    leading: _bulbGlyph(
                        on), // amber outline (off) / outline+fill (on)
                    text: 'lit'.tr(),
                  ),
                  onSelected: (sel) {
                    setState(() {
                      _selection.toggles[def.key] = sel;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ];
          }).toList(),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: Text(widget.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: () => _loadData(bypassCache: true),
                  child: Padding(
                    padding: AppPaddings.symmHorizontalReg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.container),
                              boxShadow: AppShadows.md,
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.container),
                              child: ColoredBox(
                                color: AppColors.white,
                                child: CustomScrollView(
                                  key: PageStorageKey(
                                      'sport:${widget.sportType}'),
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  slivers: [
                                    SliverPersistentHeader(
                                      pinned: true,
                                      delegate: _PinnedHeaderDelegate(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            PanelHeader(
                                                'find_location_exercise'.tr()),
                                            Padding(
                                              padding:
                                                  AppPaddings.symmHorizontalReg,
                                              child: _SearchBar(
                                                controller: _searchController,
                                                isEmpty: _searchController
                                                    .text.isEmpty,
                                                onOpenMap: _openMapWithFiltered,
                                                onClear: () {
                                                  _searchController.clear();
                                                  setState(() {
                                                    _searchQuery = '';
                                                    _applyFilters();
                                                  });
                                                },
                                                onSubmitted: (_) {
                                                  setState(() {
                                                    _searchQuery =
                                                        _searchController.text;
                                                    _applyFilters();
                                                  });
                                                },
                                                onChanged: (value) {
                                                  if (_debounce?.isActive ??
                                                      false) {
                                                    _debounce!.cancel();
                                                  }
                                                  _debounce = Timer(
                                                      const Duration(
                                                          milliseconds: 300),
                                                      () {
                                                    if (!mounted) return;
                                                    setState(() {
                                                      _searchQuery = value;
                                                      _applyFilters();
                                                    });
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(
                                                height: AppHeights.reg),
                                            _buildFilterChips(),
                                            const SizedBox(
                                                height: AppHeights.small),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SliverPadding(
                                      padding: AppPaddings.symmHorizontalReg,
                                      sliver: _FieldsSliverList(
                                        filteredLocations: _filteredLocations,
                                        favoriteIds: _favoriteIds,
                                        formatDistance: _formatDistance,
                                        getDisplayName: _getDisplayName,
                                        characteristicsBuilder:
                                            _buildCharacteristicsRow,
                                        onToggleFavorite: _toggleFavorite,
                                        onDirections: _openDirections,
                                        onShare: _shareLocation,
                                        hapticsActions:
                                            ref.read(hapticsActionsProvider),
                                      ),
                                    ),
                                    const SliverToBoxAdapter(
                                      child: SizedBox(height: AppHeights.reg),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

//Sticky header delegate
class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _PinnedHeaderDelegate({required this.child});

  @override
  double get maxExtent => 200;
  @override
  double get minExtent => 200;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: overlapsContent ? 4 : 0,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

// --- Extracted widgets ---

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isEmpty;
  final void Function(String) onSubmitted;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenMap;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.isEmpty,
    required this.onSubmitted,
    required this.onChanged,
    required this.onOpenMap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: 'search_by_name_address'.tr(),
              filled: true,
              fillColor: AppColors.lightgrey,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: isEmpty
                  ? IconButton(
                      icon: const Icon(Icons.map), onPressed: onOpenMap)
                  : SizedBox(
                      width: 96,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: onClear,
                          ),
                          IconButton(
                            icon: const Icon(Icons.map),
                            onPressed: onOpenMap,
                          ),
                        ],
                      ),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.image),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _FieldsSliverList extends StatelessWidget {
  final List<Map<String, dynamic>> filteredLocations;
  final Set<String> favoriteIds;
  final String Function(double) formatDistance;
  final Future<String> Function(Map<String, dynamic>) getDisplayName;
  final Widget Function(Map<String, dynamic>) characteristicsBuilder;
  final Future<void> Function(String id) onToggleFavorite;
  final void Function(String lat, String lon) onDirections;
  final Future<void> Function(String name, String lat, String lon) onShare;
  final HapticsActions hapticsActions;

  const _FieldsSliverList({
    required this.filteredLocations,
    required this.favoriteIds,
    required this.formatDistance,
    required this.getDisplayName,
    required this.characteristicsBuilder,
    required this.onToggleFavorite,
    required this.onDirections,
    required this.onShare,
    required this.hapticsActions,
  });

  @override
  Widget build(BuildContext context) {
    if (filteredLocations.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: AppPaddings.allSuperBig,
          child: Center(
            child: Text(
              'no_fields_found'.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle,
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final field = filteredLocations[index];
          final lat = field['lat']?.toString() ?? '';
          final lon = field['lon']?.toString() ?? '';
          final distance =
              (field['distance'] as num?)?.toDouble() ?? double.infinity;

          return SportFieldCard(
            field: field,
            isFavorite: favoriteIds.contains('$lat,$lon'),
            distanceText: formatDistance(distance),
            getDisplayName: getDisplayName,
            characteristics: characteristicsBuilder(field),
            onToggleFavorite: () async {
              final id = '$lat,$lon';
              await onToggleFavorite(id);
              await hapticsActions.selectionClick();
            },
            onShare: () async {
              final name = await getDisplayName(field);
              await onShare(name, lat, lon);
            },
            onDirections: () => onDirections(lat, lon),
          );
        },
        childCount: filteredLocations.length,
      ),
    );
  }
}
