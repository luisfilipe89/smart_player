import 'dart:async';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:move_young/models/event_model.dart';
import 'package:move_young/services/load_events_from_json.dart';
import 'package:move_young/theme/_theme.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  Set<String> _favoriteTitles = {};
  final TextEditingController _searchController = TextEditingController();

  List<Event> allEvents = [];
  List<Event> filteredEvents = [];

  String _searchQuery = '';
  bool _showRecurring = true;
  bool _showOneTime = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    loadEvents();
    _loadFavorites();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // --------------------------------------------
  // Data + prefs
  // --------------------------------------------
  Future<void> loadEvents() async {
    final loaded = await loadEventsFromJson();
    if (!mounted) return;

    setState(() {
      allEvents = loaded;
      _applyFilters();
    });

    // Preload a few images for smoother first paint
    for (var event in allEvents.take(5)) {
      if (event.imageUrl?.isNotEmpty ?? false) {
        precacheImage(CachedNetworkImageProvider(event.imageUrl!), context);
      }
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteTitles = prefs.getStringList('favoriteEvents')?.toSet() ?? {};
    });
  }

  Future<void> _toggleFavorite(String title) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteTitles.contains(title)) {
        _favoriteTitles.remove(title);
      } else {
        _favoriteTitles.add(title);
      }
      prefs.setStringList('favoriteEvents', _favoriteTitles.toList());
    });
  }

  // --------------------------------------------
  // Filters + search
  // --------------------------------------------
  void _applyFilters() {
    final events = allEvents.where((event) {
      final queryMatch =
          event.title.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!queryMatch) return false;

      final isRecurring = event.isRecurring;
      if (isRecurring && !_showRecurring) return false;
      if (!isRecurring && !_showOneTime) return false;

      return true;
    }).toList();

    setState(() => filteredEvents = events);

    // Preload visible filtered images
    for (var event in events.take(10)) {
      if (event.imageUrl?.isNotEmpty ?? false) {
        precacheImage(CachedNetworkImageProvider(event.imageUrl!), context);
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
        _applyFilters();
      });
    });
  }

  // --------------------------------------------
  // Actions
  // --------------------------------------------
  Future<void> _shareEvent(Event event) async {
    final String text = (event.url?.isNotEmpty ?? false)
        ? '${event.title}\n${event.url!}'
        : event.title;
    await Share.share(text);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('could_not_open'.tr())),
      );
    }
  }

  Future<void> _openDirections(BuildContext context, String location) async {
    final query = Uri.encodeComponent(location);
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('could_not_open_google_maps'.tr())),
          );
        }
      });
    }
  }

  // --------------------------------------------
  // UI helpers
  // --------------------------------------------
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'search_events'.tr(),
        filled: true,
        fillColor: AppColors.lightgrey,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: (_searchQuery.isEmpty)
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _applyFilters();
                  });
                },
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.image),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: _onSearchChanged,
    );
  }

  Widget _buildFilterChipsRow() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: AppPaddings.symmHorizontalReg,
      child: ChipTheme(
        data: theme.chipTheme.copyWith(
          backgroundColor: AppColors.superlightgrey,
          selectedColor: AppColors.superlightgrey,
          disabledColor: AppColors.superlightgrey,
          labelStyle: AppTextStyles.small.copyWith(color: AppColors.blackText),
          secondaryLabelStyle:
              AppTextStyles.small.copyWith(color: AppColors.blackText),
          side: const BorderSide(color: Colors.transparent),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: const StadiumBorder(),
        ),
        child: Row(
          children: [
            // Recurring
            Padding(
              padding: AppPaddings.rightSmall,
              child: FilterChip(
                showCheckmark: false,
                selected: _showRecurring,
                avatar: Icon(
                  _showRecurring ? Icons.repeat : Icons.repeat_on_outlined,
                  color: _showRecurring ? AppColors.amber : AppColors.grey,
                  size: 18,
                ),
                label: Text(
                  'recurring'.tr(),
                  style:
                      AppTextStyles.small.copyWith(color: AppColors.blackText),
                ),
                onSelected: (selected) {
                  setState(() {
                    _showRecurring = selected;
                    _applyFilters();
                  });
                },
              ),
            ),

            // One-time
            Padding(
              padding: AppPaddings.rightSmall,
              child: FilterChip(
                showCheckmark: false,
                selected: _showOneTime,
                avatar: Icon(
                  _showOneTime ? Icons.event_available : Icons.event_note,
                  color: _showOneTime ? AppColors.amber : AppColors.grey,
                  size: 18,
                ),
                label: Text(
                  'one_time'.tr(),
                  style:
                      AppTextStyles.small.copyWith(color: AppColors.blackText),
                ),
                onSelected: (selected) {
                  setState(() {
                    _showOneTime = selected;
                    _applyFilters();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: AppColors.grey,
      highlightColor: AppColors.white,
      child: Container(
        height: AppHeights.image,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
      ),
    );
  }

  Widget _buildImageOrPlaceholder(String? url) {
    if (url?.isNotEmpty ?? false) {
      return CachedNetworkImage(
        imageUrl: url!,
        height: AppHeights.image,
        width: double.infinity,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 300),
        fadeInCurve: Curves.easeInOut,
        placeholder: (_, __) => _buildShimmerPlaceholder(),
        errorWidget: (_, __, ___) => Container(
          height: AppHeights.image,
          color: AppColors.lightgrey,
          child: const Icon(Icons.broken_image),
        ),
      );
    }
    return Container(
      height: AppHeights.image,
      decoration: BoxDecoration(
        color: AppColors.grey,
        borderRadius: BorderRadius.circular(AppRadius.image),
      ),
      child: const Center(child: Icon(Icons.image_not_supported)),
    );
  }

  Widget _metaRow(IconData icon, String text, {bool muted = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.darkgrey),
        const SizedBox(width: AppWidths.small),
        Expanded(
          child: Text(
            text,
            style: muted ? AppTextStyles.smallMuted : AppTextStyles.small,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(Event event) {
    return Container(
      margin: AppPaddings.topBottom,
      padding: AppPaddings.allMedium,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.image),
            child: _buildImageOrPlaceholder(event.imageUrl),
          ),
          const SizedBox(height: AppHeights.reg),
          Text(
            event.title,
            style: AppTextStyles.cardTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppHeights.reg),
          _metaRow(Icons.access_time, event.dateTime),
          const SizedBox(height: AppHeights.small),
          _metaRow(Icons.location_on, event.location),
          const SizedBox(height: AppHeights.small),
          _metaRow(Icons.group, event.targetGroup),
          const SizedBox(height: AppHeights.small),
          _metaRow(Icons.euro, event.cost.replaceAll('€', '').trim(),
              muted: true),
          const SizedBox(height: AppHeights.big),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'favorite'.tr(),
                icon: Icon(
                  _favoriteTitles.contains(event.title)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                color: _favoriteTitles.contains(event.title)
                    ? AppColors.red
                    : AppColors.blackIcon,
                onPressed: () => _toggleFavorite(event.title),
              ),
              IconButton(
                tooltip: 'share'.tr(),
                icon: const Icon(Icons.share),
                onPressed: () => _shareEvent(event),
              ),
              IconButton(
                tooltip: 'directions'.tr(),
                icon: const Icon(Icons.directions),
                onPressed: () => _openDirections(context, event.location),
              ),
              if (event.url != null && event.url!.trim().isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _openUrl(event.url!.trim()),
                  icon: const Icon(Icons.open_in_new),
                  label: Text('to_enroll'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.white,
                    padding: AppPaddings.symmSmall,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.smallCard),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------
  // Layout
  // --------------------------------------------
  Widget _buildScrollContent() {
    return RefreshIndicator(
      onRefresh: loadEvents,
      child: CustomScrollView(
        key: const PageStorageKey('agenda'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // Pinned header (headline + search + chips)
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedHeaderDelegate(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PanelHeader('find_your_next_sport_event'.tr()),
                  Padding(
                    padding: AppPaddings.symmHorizontalReg,
                    child: _buildSearchField(),
                  ),
                  const SizedBox(height: AppHeights.reg),
                  _buildFilterChipsRow(),
                  const SizedBox(height: AppHeights.small),
                ],
              ),
            ),
          ),

          // Content
          if (filteredEvents.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: AppPaddings.allSuperBig,
                child: Center(
                  child: Text(
                    'no_events_found'.tr(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.cardTitle,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: AppPaddings.symmHorizontalReg,
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildEventCard(filteredEvents[index]),
                  childCount: filteredEvents.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppHeights.reg),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('agenda'.tr()),
      ),
      body: Padding(
        padding: AppPaddings.symmHorizontalReg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.container),
                  boxShadow: AppShadows.md,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.container),
                  child: _buildScrollContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------
// Same pinned header behavior as sport screen
// --------------------------------------------
class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _PinnedHeaderDelegate({required this.child});

  @override
  double get maxExtent => 200; // match sport screen
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
