import 'dart:async';
import 'package:flutter/material.dart';
import 'package:move_young/services/haptics_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:move_young/services/overpass_service.dart';
import 'package:move_young/screens/maps/gmaps_screen.dart';
import 'package:move_young/widgets_navigation/reverse_geocoding.dart';
import 'package:move_young/widgets_sports/sport_field_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/config/_config.dart';
import 'package:move_young/theme/_theme.dart';

class GenericSportScreen extends StatefulWidget {
  final String title;
  final String sportType;

  const GenericSportScreen({
    super.key,
    required this.title,
    required this.sportType,
  });

  @override
  State<GenericSportScreen> createState() => _GenericSportScreenState();
}

class _GenericSportScreenState extends State<GenericSportScreen>
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
    _searchController.addListener(() => setState(() {}));
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

  Future<void> _loadData({bool bypassCache = false}) async {
    try {
      final permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'location_permission_required'.tr();
          _isLoading = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.best),
      );
      _userPosition = pos;

      final locations = await OverpassService.fetchFields(
        areaName: "'s-Hertogenbosch",
        sportType: widget.sportType,
        bypassCache: bypassCache,
      );

      for (var loc in locations) {
        final lat = loc['lat'];
        final lon = loc['lon'];

        final distance = _calculateDistance(lat, lon);
        loc['distance'] = distance.isFinite ? distance : double.infinity;

        //Distance calc
        if (loc['name'] != null && loc['name'].toString().trim().isNotEmpty) {
          loc['displayName'] = loc['name'];
        } else {
          final key = '$lat,$lon';
          if (_locationCache.containsKey(key)) {
            loc['displayName'] = _locationCache[key];
          } else {
            final streetName = await getNearestStreetName(lat, lon);
            _locationCache[key] = streetName;
            loc['displayName'] = streetName;
          }
        }
        if (!mounted) return;
      }

      locations.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));

      if (!mounted) return;
      setState(() {
        _allLocations = locations;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'loading_error'.tr();
        _isLoading = false;
      });
      debugPrint('Error in _loadData: $e');
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

  double _calculateDistance(double? lat, double? lon) {
    if (_userPosition == null || lat == null || lon == null) {
      return double.infinity;
    }
    return Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      lat,
      lon,
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
    if (loc['name'] != null && loc['name'].toString().trim().isNotEmpty) {
      return loc['name'];
    }

    final lat = loc['lat'];
    final lon = loc['lon'];
    final key = '$lat,$lon';

    if (_locationCache.containsKey(key)) {
      return _locationCache[key]!;
    }

    final streetName = await getNearestStreetName(lat, lon);
    _locationCache[key] = streetName;
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
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          _searchController,
                                                      textInputAction:
                                                          TextInputAction
                                                              .search,
                                                      onSubmitted: (_) {
                                                        setState(() {
                                                          _searchQuery =
                                                              _searchController
                                                                  .text;
                                                          _applyFilters();
                                                        });
                                                      },
                                                      decoration:
                                                          InputDecoration(
                                                        hintText:
                                                            'search_by_name_address'
                                                                .tr(),
                                                        filled: true,
                                                        fillColor:
                                                            AppColors.lightgrey,
                                                        prefixIcon: const Icon(
                                                            Icons.search),
                                                        suffixIcon:
                                                            (_searchController
                                                                    .text
                                                                    .isEmpty)
                                                                ? IconButton(
                                                                    icon: const Icon(
                                                                        Icons
                                                                            .map),
                                                                    onPressed:
                                                                        _openMapWithFiltered,
                                                                  )
                                                                : SizedBox(
                                                                    width: 96,
                                                                    child: Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .end,
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        IconButton(
                                                                          icon:
                                                                              const Icon(Icons.clear),
                                                                          onPressed:
                                                                              () {
                                                                            _searchController.clear();
                                                                            setState(() {
                                                                              _searchQuery = '';
                                                                              _applyFilters();
                                                                            });
                                                                          },
                                                                        ),
                                                                        IconButton(
                                                                          icon:
                                                                              const Icon(Icons.map),
                                                                          onPressed:
                                                                              _openMapWithFiltered,
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      AppRadius
                                                                          .image),
                                                          borderSide:
                                                              BorderSide.none,
                                                        ),
                                                      ),
                                                      onChanged: (value) {
                                                        if (_debounce
                                                                ?.isActive ??
                                                            false) {
                                                          _debounce!.cancel();
                                                        }
                                                        _debounce = Timer(
                                                            const Duration(
                                                                milliseconds:
                                                                    300), () {
                                                          if (!mounted) return;
                                                          setState(() {
                                                            _searchQuery =
                                                                value;
                                                            _applyFilters();
                                                          });
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
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
                                      sliver: _filteredLocations.isEmpty
                                          ? SliverToBoxAdapter(
                                              child: Padding(
                                                padding:
                                                    AppPaddings.allSuperBig,
                                                child: Center(
                                                  child: Text(
                                                    'no_fields_found'.tr(),
                                                    textAlign: TextAlign.center,
                                                    style:
                                                        AppTextStyles.cardTitle,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : SliverList(
                                              delegate:
                                                  SliverChildBuilderDelegate(
                                                (context, index) {
                                                  final field =
                                                      _filteredLocations[index];
                                                  final lat = field['lat']
                                                          ?.toString() ??
                                                      '';
                                                  final lon = field['lon']
                                                          ?.toString() ??
                                                      '';
                                                  final distance =
                                                      (field['distance']
                                                                  as num?)
                                                              ?.toDouble() ??
                                                          double.infinity;

                                                  return SportFieldCard(
                                                    field: field,
                                                    isFavorite: _favoriteIds
                                                        .contains('$lat,$lon'),
                                                    distanceText:
                                                        _formatDistance(
                                                            distance),
                                                    getDisplayName:
                                                        _getDisplayName,
                                                    characteristics:
                                                        _buildCharacteristicsRow(
                                                            field),
                                                    onToggleFavorite: () async {
                                                      final id = '$lat,$lon';
                                                      await _toggleFavorite(id);
                                                      HapticsService
                                                          .selectionClick();
                                                    },
                                                    onShare: () async {
                                                      final name =
                                                          await _getDisplayName(
                                                              field);
                                                      _shareLocation(
                                                          name, lat, lon);
                                                    },
                                                    onDirections: () =>
                                                        _openDirections(
                                                            lat, lon),
                                                  );
                                                },
                                                childCount:
                                                    _filteredLocations.length,
                                              ),
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
