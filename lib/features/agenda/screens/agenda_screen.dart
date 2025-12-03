import 'dart:async';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:move_young/services/cache/favorites_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/agenda/models/event_model.dart';
import 'package:move_young/features/agenda/services/events_provider.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/widgets/app_back_button.dart';
import 'package:move_young/widgets/error_retry_widget.dart';
import 'package:move_young/widgets/cached_data_indicator.dart';
import 'package:move_young/utils/logger.dart';

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key, this.highlightEventTitle});

  final String? highlightEventTitle;

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

enum _LoadState { idle, loading, success, error }

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  Set<String> _favoriteTitles = {};
  final TextEditingController _searchController = TextEditingController();

  List<Event> allEvents = [];
  List<Event> filteredEvents = [];

  String _searchQuery = '';
  bool _showRecurring = true;
  bool _showOneTime = true;
  Timer? _debounce;
  bool _didInit = false;
  _LoadState _loadState = _LoadState.idle;
  final Map<String, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    // Schedule scroll to highlighted event after first frame (similar to games screen)
    if (widget.highlightEventTitle != null) {
      NumberedLogger.d('AgendaScreen initState with highlightEventTitle: ${widget.highlightEventTitle}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToHighlightedEvent();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      loadEvents();
      _loadFavorites();
    }
  }
  
  @override
  void didUpdateWidget(AgendaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If highlightEventTitle changed and events are already loaded, scroll to it
    if (widget.highlightEventTitle != null &&
        widget.highlightEventTitle != oldWidget.highlightEventTitle &&
        filteredEvents.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToHighlightedEvent();
        });
      });
    }
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
    if (!mounted) return;
    setState(() {
      _loadState = _LoadState.loading;
    });

    try {
      final currentLang = context.locale.languageCode;
      final eventsService = ref.read(eventsServiceProvider);
      final loaded = await eventsService.loadEvents(lang: currentLang);
      if (!mounted) return;

      setState(() {
        allEvents = loaded;
        _loadState = _LoadState.success;
        _applyFilters();
      });
      
      // Scroll to highlighted event after loading - wait for list to be built
      if (widget.highlightEventTitle != null) {
        // Use multiple nested callbacks to ensure CustomScrollView is fully built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToHighlightedEvent();
            });
          });
        });
      }
    } catch (e, stack) {
      NumberedLogger.e('Error loading events: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _loadState = _LoadState.error;
      });
    }

    // Preload a few images for smoother first paint (optimized with parallel loading)
    final imageUrls = allEvents
        .take(5)
        .where((event) => event.imageUrl?.isNotEmpty ?? false)
        .map((event) {
          // Normalize URLs
          String normalized = event.imageUrl!;
          if (normalized.startsWith('//')) {
            normalized = 'https:$normalized';
          } else if (normalized.startsWith('/')) {
            normalized = 'https://www.aanbod.s-port.nl$normalized';
          } else if (!normalized.startsWith('http')) {
            normalized = 'https://www.aanbod.s-port.nl/$normalized';
          }
          return normalized;
        })
        .where((url) => !url.startsWith('assets/'))
        .toList();

    // Preload in parallel with limited concurrency to avoid blocking UI
    // Do not await to ensure pull-to-refresh completes quickly
    if (imageUrls.isNotEmpty && mounted) {
      // ignore: unawaited_futures
      Future(() async {
        // Limit concurrent preloads to avoid memory issues
        final futures = <Future>[];
        for (int i = 0; i < imageUrls.length && i < 5 && mounted; i++) {
          final url = imageUrls[i];
          if (url.isNotEmpty) {
            futures.add(
              precacheImage(
                CachedNetworkImageProvider(
                  url,
                  cacheManager: DefaultCacheManager(),
                  headers: const {
                    'User-Agent':
                        'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36',
                    'Accept':
                        'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
                    'Referer': 'https://www.aanbod.s-port.nl/',
                  },
                ),
                context,
              ).timeout(const Duration(seconds: 5)).catchError((_) {
                // Ignore errors - images will still load in cards individually
              }),
            );
          }
        }
        // Wait for all preloads in parallel
        try {
          await Future.wait(futures);
        } catch (_) {
          // Ignore errors - images will still load in cards individually
        }
      }).catchError((_) {});
    }
  }

  Future<void> _loadFavorites() async {
    final favoritesService = ref.read(favoritesServiceProvider);
    if (favoritesService == null) return;
    final favorites = await favoritesService.getFavorites();
    setState(() {
      _favoriteTitles = favorites;
    });
  }

  Future<void> _toggleFavorite(String title) async {
    final favoritesService = ref.read(favoritesServiceProvider);
    if (favoritesService == null) return;
    await favoritesService.toggleFavorite(title);
    setState(() {
      if (_favoriteTitles.contains(title)) {
        _favoriteTitles.remove(title);
      } else {
        _favoriteTitles.add(title);
      }
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

    setState(() {
      filteredEvents = events;
    });
    
    // Scroll to highlighted event after filtering if needed
    if (widget.highlightEventTitle != null && events.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToHighlightedEvent();
        });
      });
    }
    // Note: Image preloading removed from filter changes to avoid unnecessary network requests
    // Images are preloaded only on initial load in loadEvents() method
  }
  
  void _scrollToHighlightedEvent({int attempts = 0}) {
    if (widget.highlightEventTitle == null || !mounted) {
      if (widget.highlightEventTitle == null) {
        NumberedLogger.d('_scrollToHighlightedEvent: highlightEventTitle is null');
      }
      return;
    }
    
    NumberedLogger.d('_scrollToHighlightedEvent: attempt $attempts, looking for: ${widget.highlightEventTitle}');
    NumberedLogger.d('_scrollToHighlightedEvent: filteredEvents count: ${filteredEvents.length}, allEvents count: ${allEvents.length}');
    
    // Check if the highlighted event is in the filtered list
    final eventIndex = filteredEvents.indexWhere(
      (event) => event.title == widget.highlightEventTitle,
    );
    final eventExists = eventIndex >= 0;
    
    if (eventExists) {
      NumberedLogger.d('_scrollToHighlightedEvent: event found at index $eventIndex in filteredEvents');
    } else {
      NumberedLogger.d('_scrollToHighlightedEvent: event NOT found in filteredEvents');
      // Log first few event titles for debugging
      if (filteredEvents.isNotEmpty) {
        NumberedLogger.d('_scrollToHighlightedEvent: first 3 event titles: ${filteredEvents.take(3).map((e) => e.title).toList()}');
      }
    }
    if (!eventExists) {
      // If event not found, check if events are still loading
      if (_loadState == _LoadState.loading) {
        // Still loading, wait and retry
        if (attempts < 15) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _scrollToHighlightedEvent(attempts: attempts + 1);
            }
          });
        }
        return;
      }
      // Events loaded but event not in filtered list - might be filtered out
      // Try to find it in allEvents to see if it exists
      final existsInAll = allEvents.any(
        (event) => event.title == widget.highlightEventTitle,
      );
      if (existsInAll) {
        // Event exists but is filtered out - clear filters and retry
        setState(() {
          _searchQuery = '';
          _searchController.clear();
          _showRecurring = true;
          _showOneTime = true;
          _applyFilters();
        });
        if (attempts < 5) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToHighlightedEvent(attempts: attempts + 1);
            });
          });
        }
        return;
      }
      // Event doesn't exist at all, give up after a few more attempts
      if (attempts < 5) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _scrollToHighlightedEvent(attempts: attempts + 1);
          }
        });
      }
      return;
    }
    
    final key = _itemKeys[widget.highlightEventTitle!];
    NumberedLogger.d('_scrollToHighlightedEvent: key exists: ${key != null}, key: $key');
    
    if (key == null) {
      // Key not created yet, retry (keys are created lazily in _buildEventCard)
      NumberedLogger.d('_scrollToHighlightedEvent: key is null, retrying...');
      if (attempts < 15) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToHighlightedEvent(attempts: attempts + 1);
        });
      }
      return;
    }
    
    final ctx = key.currentContext;
    NumberedLogger.d('_scrollToHighlightedEvent: context exists: ${ctx != null}, context: $ctx');
    
    if (ctx != null && mounted) {
      try {
        NumberedLogger.d('_scrollToHighlightedEvent: attempting Scrollable.ensureVisible...');
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.15,
        );
        NumberedLogger.d('Successfully scrolled to event: ${widget.highlightEventTitle}');
        return;
      } catch (e, stack) {
        // If scroll fails, retry
        NumberedLogger.w('Scroll to event failed: $e\n$stack');
        if (attempts < 10) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToHighlightedEvent(attempts: attempts + 1);
          });
        }
      }
    } else {
      // Context not available yet, retry with more attempts
      NumberedLogger.d('_scrollToHighlightedEvent: context is null or not mounted, retrying... (attempts: $attempts)');
      if (attempts < 15) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToHighlightedEvent(attempts: attempts + 1);
        });
      } else {
        NumberedLogger.w('_scrollToHighlightedEvent: giving up after $attempts attempts');
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
    return Semantics(
      label: 'Search events',
      hint: 'Enter event name to search',
      textField: true,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'search_events'.tr(),
          filled: true,
          fillColor: AppColors.lightgrey,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: (_searchQuery.isEmpty)
              ? null
              : Semantics(
                  label: 'Clear search',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _applyFilters();
                      });
                    },
                  ),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.image),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: _onSearchChanged,
      ),
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
              child: Semantics(
                label: _showRecurring
                    ? 'Hide recurring events'
                    : 'Show recurring events',
                button: true,
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
                    style: AppTextStyles.small
                        .copyWith(color: AppColors.blackText),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _showRecurring = selected;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ),

            // One-time
            Padding(
              padding: AppPaddings.rightSmall,
              child: Semantics(
                label: _showOneTime
                    ? 'Hide one-time events'
                    : 'Show one-time events',
                button: true,
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
                    style: AppTextStyles.small
                        .copyWith(color: AppColors.blackText),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _showOneTime = selected;
                      _applyFilters();
                    });
                  },
                ),
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
      // Check if it's a local asset path
      if (url!.startsWith('assets/')) {
        return Container(
          width: double.infinity,
          height: AppHeights.image,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.image),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.image),
            child: Image.asset(
              url,
              width: double.infinity,
              height: AppHeights.image,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: AppHeights.image,
                color: AppColors.lightgrey,
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
        );
      } else {
        // It's a network URL, use CachedNetworkImage for optimized loading
        // Normalize potential relative URLs from source site
        String normalized = url;
        if (normalized.startsWith('//')) {
          normalized = 'https:$normalized';
        } else if (normalized.startsWith('/')) {
          normalized = 'https://www.aanbod.s-port.nl$normalized';
        } else if (!normalized.startsWith('http')) {
          normalized = 'https://www.aanbod.s-port.nl/$normalized';
        }

        return CachedNetworkImage(
          imageUrl: normalized,
          width: double.infinity,
          height: AppHeights.image,
          fit: BoxFit.cover,
          httpHeaders: const {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
            'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
            'Referer': 'https://www.aanbod.s-port.nl/',
            'Accept-Language': 'en-US,en;q=0.9,nl;q=0.8',
            'Cookie': 'locale=en',
          },
          placeholder: (context, url) => _buildShimmerPlaceholder(),
          errorWidget: (context, url, error) {
            NumberedLogger.w('[Agenda] Image failed: $normalized err: $error');
            return Container(
              height: AppHeights.image,
              color: AppColors.lightgrey,
              child: const Icon(Icons.broken_image),
            );
          },
          memCacheWidth: 800, // Optimize memory usage
          memCacheHeight: 600,
          fadeInDuration: const Duration(milliseconds: 200),
          fadeOutDuration: const Duration(milliseconds: 100),
        );
      }
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
    // Use putIfAbsent to ensure key is created only once, like games screen
    final key = _itemKeys.putIfAbsent(event.title, () => GlobalKey());
    
    return KeyedSubtree(
      key: key,
      child: Container(
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
              Semantics(
                label: _favoriteTitles.contains(event.title)
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                button: true,
                child: IconButton(
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
              ),
              Semantics(
                label: 'Share event',
                button: true,
                child: IconButton(
                  tooltip: 'share'.tr(),
                  icon: const Icon(Icons.share),
                  onPressed: () => _shareEvent(event),
                ),
              ),
              Semantics(
                label: 'Get directions to ${event.location}',
                button: true,
                child: IconButton(
                  tooltip: 'directions'.tr(),
                  icon: const Icon(Icons.directions),
                  onPressed: () => _openDirections(context, event.location),
                ),
              ),
              if (event.url != null && event.url!.trim().isNotEmpty)
                Semantics(
                  label: 'Enroll in event',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: () => _openUrl(event.url!.trim()),
                    icon: const Icon(Icons.open_in_new),
                    label: Text('to_enroll'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: AppColors.white,
                      padding: AppPaddings.symmSmall,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.smallCard),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
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
          if (_loadState == _LoadState.loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: AppPaddings.allSuperBig,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppHeights.reg),
                      Text(
                        'refreshing_events'.tr(),
                        style: AppTextStyles.bodyMuted,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_loadState == _LoadState.error)
            SliverToBoxAdapter(
              child: ErrorRetryWidget(
                message: 'events_load_failed'.tr(),
                onRetry: loadEvents,
                icon: Icons.error_outline,
              ),
            )
          else if (filteredEvents.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: AppPaddings.allSuperBig,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.event_busy,
                        size: 64,
                        color: AppColors.grey,
                      ),
                      const SizedBox(height: AppHeights.reg),
                      Text(
                        'no_events_found'.tr(),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.cardTitle,
                      ),
                      const SizedBox(height: AppHeights.small),
                      if (_searchQuery.isNotEmpty ||
                          !_showRecurring ||
                          !_showOneTime)
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'empty_state_adjust_search_filters'.tr()
                              : 'empty_state_adjust_filters'.tr(),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMuted,
                        ),
                      if (_searchQuery.isNotEmpty ||
                          !_showRecurring ||
                          !_showOneTime) ...[
                        const SizedBox(height: AppHeights.reg),
                        Semantics(
                          label: 'Clear all filters and search',
                          button: true,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                                _showRecurring = true;
                                _showOneTime = true;
                                _applyFilters();
                              });
                            },
                            icon: const Icon(Icons.clear_all),
                            label: Text('clear_filters'.tr()),
                          ),
                        ),
                      ],
                    ],
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
        leading: Semantics(
          label: 'Back to home',
          button: true,
          child: const AppBackButton(goHome: true),
        ),
        title: Semantics(
          header: true,
          child: Text('agenda'.tr()),
        ),
      ),
      body: CachedDataIndicator(
        child: Padding(
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
  double get maxExtent =>
      240; // increased to prevent overflow on smaller screens
  @override
  double get minExtent => 240;

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
