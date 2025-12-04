import 'dart:async';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/agenda/models/event_model.dart';
import 'package:move_young/features/agenda/services/events_provider.dart';
import 'package:move_young/features/agenda/services/cached_events_provider.dart';
import 'package:move_young/features/agenda/utils/age_group_parser.dart';
import 'package:move_young/features/agenda/utils/cost_parser.dart';
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
  final TextEditingController _searchController = TextEditingController();

  List<Event> allEvents = [];
  List<Event> filteredEvents = [];

  String _searchQuery = '';
  AgeGroup? _selectedAgeGroup;
  bool? _isRecurringFilter; // null = all, true = recurring, false = one-time
  CostType? _selectedCostType;
  Timer? _debounce;
  bool _didInit = false;
  _LoadState _loadState = _LoadState.idle;
  final Map<String, GlobalKey> _itemKeys = {};
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToEvent = false;

  @override
  void initState() {
    super.initState();
    NumberedLogger.d(
        'AgendaScreen initState called, highlightEventTitle: ${widget.highlightEventTitle}');
    // Schedule scroll to highlighted event after first frame (similar to games screen)
    if (widget.highlightEventTitle != null) {
      NumberedLogger.d(
          'AgendaScreen initState: Scheduling scroll to: ${widget.highlightEventTitle}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NumberedLogger.d(
            'AgendaScreen initState: PostFrameCallback executing, calling _scrollToHighlightedEvent');
        _scrollToHighlightedEvent();
      });
    } else {
      NumberedLogger.d(
          'AgendaScreen initState: No highlightEventTitle, skipping scroll');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      final currentLang = context.locale.languageCode;

      // Check if events are already cached
      final cachedEventsAsync = ref.read(cachedEventsProvider(currentLang));

      if (cachedEventsAsync.hasValue &&
          cachedEventsAsync.valueOrNull?.isNotEmpty == true) {
        // Events are cached - use them immediately without loading state
        final cachedEvents = cachedEventsAsync.value!;
        NumberedLogger.d(
            'AgendaScreen: Using cached events (${cachedEvents.length} events)');
        setState(() {
          allEvents = cachedEvents;
          _loadState =
              _LoadState.success; // Set directly to success, skip loading
          _applyFilters();
        });

        // Scroll to highlighted event if needed
        if (widget.highlightEventTitle != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToHighlightedEvent();
            });
          });
        }
      } else {
        // No cache available - load events normally (will show loading)
        NumberedLogger.d('AgendaScreen: No cached events, loading...');
        loadEvents();
      }
    }
  }

  @override
  void didUpdateWidget(AgendaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    NumberedLogger.d(
        'AgendaScreen didUpdateWidget: old=${oldWidget.highlightEventTitle}, new=${widget.highlightEventTitle}');
    // Reset scroll flag if highlightEventTitle changed
    if (widget.highlightEventTitle != oldWidget.highlightEventTitle) {
      _hasScrolledToEvent = false;
    }
    // If highlightEventTitle changed from a value to null, scroll to top
    if (oldWidget.highlightEventTitle != null &&
        widget.highlightEventTitle == null &&
        _scrollController.hasClients) {
      NumberedLogger.d(
          'AgendaScreen didUpdateWidget: highlightEventTitle cleared, scrolling to top');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
    // If highlightEventTitle changed to a new value and events are already loaded, scroll to it
    if (widget.highlightEventTitle != null &&
        widget.highlightEventTitle != oldWidget.highlightEventTitle &&
        filteredEvents.isNotEmpty) {
      NumberedLogger.d(
          'AgendaScreen didUpdateWidget: Scheduling scroll to: ${widget.highlightEventTitle}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NumberedLogger.d(
              'AgendaScreen didUpdateWidget: PostFrameCallback executing, calling _scrollToHighlightedEvent');
          _scrollToHighlightedEvent();
        });
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    // Clear keys to prevent duplicate key errors when screen is replaced
    _itemKeys.clear();
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

      // Invalidate cache to update it with fresh data
      ref.invalidate(cachedEventsProvider(currentLang));

      setState(() {
        allEvents = loaded;
        _loadState = _LoadState.success;
        _applyFilters();
      });

      // Scroll to highlighted event after loading - wait for list to be built
      if (widget.highlightEventTitle != null) {
        NumberedLogger.d(
            'AgendaScreen loadEvents: Scheduling scroll to: ${widget.highlightEventTitle}');
        // Use multiple nested callbacks to ensure CustomScrollView is fully built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              NumberedLogger.d(
                  'AgendaScreen loadEvents: PostFrameCallback executing, calling _scrollToHighlightedEvent');
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

  // --------------------------------------------
  // Filters + search
  // --------------------------------------------
  void _applyFilters() {
    final events = allEvents.where((event) {
      // Search filter
      final queryMatch =
          event.title.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!queryMatch) return false;

      // Age group filter
      if (_selectedAgeGroup != null) {
        final matchesAge = AgeGroupParser.matchesAgeGroup(
          event.targetGroup,
          _selectedAgeGroup,
        );
        if (!matchesAge) return false;
      }

      // Recurring filter
      if (_isRecurringFilter != null) {
        if (event.isRecurring != _isRecurringFilter) return false;
      }

      // Cost filter
      if (_selectedCostType != null) {
        final matchesCost = CostParser.matchesCostType(
          event.cost,
          _selectedCostType,
        );
        if (!matchesCost) return false;
      }

      return true;
    }).toList();

    // Pre-create keys for all filtered events to ensure they exist when we try to scroll
    for (final event in events) {
      _itemKeys.putIfAbsent(event.title, () => GlobalKey());
    }

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
    if (widget.highlightEventTitle == null || !mounted || _hasScrolledToEvent) {
      if (widget.highlightEventTitle == null) {
        NumberedLogger.d(
            '_scrollToHighlightedEvent: highlightEventTitle is null');
      } else if (_hasScrolledToEvent) {
        NumberedLogger.d(
            '_scrollToHighlightedEvent: Already scrolled, skipping');
      }
      return;
    }

    NumberedLogger.d(
        '_scrollToHighlightedEvent: attempt $attempts, looking for: ${widget.highlightEventTitle}');
    NumberedLogger.d(
        '_scrollToHighlightedEvent: filteredEvents count: ${filteredEvents.length}, allEvents count: ${allEvents.length}');

    // Check if the highlighted event is in the filtered list
    final eventIndex = filteredEvents.indexWhere(
      (event) => event.title == widget.highlightEventTitle,
    );
    final eventExists = eventIndex >= 0;

    if (eventExists) {
      NumberedLogger.d(
          '_scrollToHighlightedEvent: event found at index $eventIndex in filteredEvents');
    } else {
      NumberedLogger.d(
          '_scrollToHighlightedEvent: event NOT found in filteredEvents');
      // Log first few event titles for debugging
      if (filteredEvents.isNotEmpty) {
        NumberedLogger.d(
            '_scrollToHighlightedEvent: first 3 event titles: ${filteredEvents.take(3).map((e) => e.title).toList()}');
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
    NumberedLogger.d(
        '_scrollToHighlightedEvent: key exists: ${key != null}, key: $key');

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
    NumberedLogger.d(
        '_scrollToHighlightedEvent: context exists: ${ctx != null}, context: $ctx');

    if (ctx != null && mounted) {
      try {
        NumberedLogger.d(
            '_scrollToHighlightedEvent: attempting Scrollable.ensureVisible...');
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.15,
        );
        NumberedLogger.d(
            'Successfully scrolled to event: ${widget.highlightEventTitle}');
        _hasScrolledToEvent = true; // Mark as scrolled to prevent retries
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
      // Context not available yet - item hasn't been rendered (not visible)
      // Try scrolling to approximate position first to make it visible
      if (eventExists && (attempts == 0 || attempts == 1)) {
        // Estimate scroll position: header height (~240) + approximate item height (~300) * index
        final estimatedItemHeight =
            300.0; // Approximate height of each event card
        final headerHeight = 240.0; // Height of pinned header
        final estimatedScrollPosition =
            headerHeight + (eventIndex * estimatedItemHeight);

        NumberedLogger.d(
            '_scrollToHighlightedEvent: context null, scrolling to estimated position: $estimatedScrollPosition (index: $eventIndex)');

        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            estimatedScrollPosition.clamp(
                0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }

      // Retry with more attempts to wait for item to be rendered after scrolling
      NumberedLogger.d(
          '_scrollToHighlightedEvent: context is null or not mounted, retrying... (attempts: $attempts)');
      if (attempts < 20) {
        // Wait a bit longer for the item to render after scrolling
        Future.delayed(Duration(milliseconds: attempts < 3 ? 150 : 200), () {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToHighlightedEvent(attempts: attempts + 1);
            });
          }
        });
      } else {
        NumberedLogger.w(
            '_scrollToHighlightedEvent: giving up after $attempts attempts');
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
    // Normalize URL - handle relative URLs from scraper
    String normalized = url.trim();
    if (normalized.startsWith('//')) {
      normalized = 'https:$normalized';
    } else if (normalized.startsWith('/')) {
      normalized = 'https://www.aanbod.s-port.nl$normalized';
    } else if (!normalized.startsWith('http')) {
      normalized = 'https://www.aanbod.s-port.nl/$normalized';
    }

    final uri = Uri.parse(normalized);
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
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Open filters',
                button: true,
                child: IconButton(
                  icon: Stack(
                    children: [
                      const Icon(Icons.tune),
                      if (_getActiveFilterCount() > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${_getActiveFilterCount()}',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: () => _showFilterBottomSheet(),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                Semantics(
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
            ],
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

  bool _hasActiveFilters() {
    return _selectedAgeGroup != null ||
        _isRecurringFilter != null ||
        _selectedCostType != null;
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedAgeGroup != null) count++;
    if (_isRecurringFilter != null) count++;
    if (_selectedCostType != null) count++;
    return count;
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        selectedAgeGroup: _selectedAgeGroup,
        isRecurringFilter: _isRecurringFilter,
        selectedCostType: _selectedCostType,
        onApply: (ageGroup, isRecurring, costType) {
          setState(() {
            _selectedAgeGroup = ageGroup;
            _isRecurringFilter = isRecurring;
            _selectedCostType = costType;
            _applyFilters();
          });
        },
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
    // Key should already be created in _applyFilters
    // Only get it, don't create it here to avoid duplicates
    final key = _itemKeys[event.title];
    final widgetKey = key ?? ValueKey('event_${event.title}');

    if (key == null) {
      // This shouldn't happen if _applyFilters ran, but if it does, use ValueKey as fallback
      // Don't create a GlobalKey here to avoid duplicates
      NumberedLogger.w(
          '_buildEventCard: Key missing for event: ${event.title}, using ValueKey fallback');
    }

    return KeyedSubtree(
      key: widgetKey,
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
        controller: _scrollController,
        key: const PageStorageKey('agenda'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // Pinned header (headline + search + filters)
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
                      if (_searchQuery.isNotEmpty || _selectedAgeGroup != null)
                        Text(
                          'empty_state_adjust_search_filters'.tr(),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMuted,
                        ),
                      if (_searchQuery.isNotEmpty || _hasActiveFilters()) ...[
                        const SizedBox(height: AppHeights.reg),
                        Semantics(
                          label: 'Clear filters',
                          button: true,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _selectedAgeGroup = null;
                                _isRecurringFilter = null;
                                _selectedCostType = null;
                                _searchController.clear();
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
              padding: const EdgeInsets.only(
                top: 12, // Match bottom margin between cards (from AppPaddings.topBottom)
                left: 16, // From AppPaddings.symmHorizontalReg
                right: 16, // From AppPaddings.symmHorizontalReg
              ),
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
      128; // PanelHeader (~58px) + Search field (~56px) + spacing (~14px buffer)
  @override
  double get minExtent => 128;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: overlapsContent ? 4 : 0,
      child: ClipRect(
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

// --------------------------------------------
// Filter Bottom Sheet
// --------------------------------------------
class _FilterBottomSheet extends StatefulWidget {
  final AgeGroup? selectedAgeGroup;
  final bool? isRecurringFilter;
  final CostType? selectedCostType;
  final void Function(AgeGroup?, bool?, CostType?) onApply;

  const _FilterBottomSheet({
    required this.selectedAgeGroup,
    required this.isRecurringFilter,
    required this.selectedCostType,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late AgeGroup? _selectedAgeGroup;
  late bool? _isRecurringFilter;
  late CostType? _selectedCostType;

  @override
  void initState() {
    super.initState();
    _selectedAgeGroup = widget.selectedAgeGroup;
    _isRecurringFilter = widget.isRecurringFilter;
    _selectedCostType = widget.selectedCostType;
  }

  String _getAgeGroupLabel(AgeGroup ageGroup) {
    switch (ageGroup) {
      case AgeGroup.all:
        return 'age_group_all'.tr();
      case AgeGroup.toddlers:
        return 'age_group_toddlers'.tr();
      case AgeGroup.kids:
        return 'age_group_kids'.tr();
      case AgeGroup.youth:
        return 'age_group_youth'.tr();
      case AgeGroup.young:
        return 'age_group_young'.tr();
      case AgeGroup.adult:
        return 'age_group_adult'.tr();
      case AgeGroup.senior:
        return 'age_group_senior'.tr();
      case AgeGroup.seniorPlus:
        return 'age_group_senior_plus'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: AppPaddings.allReg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Text(
                'filters'.tr(),
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: AppHeights.reg),

              // Age Group Filter
              Text(
                'age_group'.tr(),
                style: AppTextStyles.cardTitle,
              ),
              const SizedBox(height: AppHeights.small),
              Wrap(
                spacing: AppWidths.small,
                runSpacing: AppHeights.small,
                children: [
                  for (final ageGroup in AgeGroup.values)
                    FilterChip(
                      label: Text(_getAgeGroupLabel(ageGroup)),
                      selected: _selectedAgeGroup == ageGroup,
                      onSelected: (selected) {
                        setState(() {
                          _selectedAgeGroup = selected ? ageGroup : null;
                        });
                      },
                      selectedColor: AppColors.blue.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.blue,
                    ),
                ],
              ),
              const SizedBox(height: AppHeights.reg),

              // Recurring Filter
              Text(
                'event_type'.tr(),
                style: AppTextStyles.cardTitle,
              ),
              const SizedBox(height: AppHeights.small),
              Wrap(
                spacing: AppWidths.small,
                runSpacing: AppHeights.small,
                children: [
                  FilterChip(
                    label: Text('recurring_events'.tr()),
                    selected: _isRecurringFilter == true,
                    onSelected: (selected) {
                      setState(() {
                        _isRecurringFilter = selected ? true : null;
                      });
                    },
                    selectedColor: AppColors.blue.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.blue,
                  ),
                  FilterChip(
                    label: Text('one_time_events'.tr()),
                    selected: _isRecurringFilter == false,
                    onSelected: (selected) {
                      setState(() {
                        _isRecurringFilter = selected ? false : null;
                      });
                    },
                    selectedColor: AppColors.blue.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.blue,
                  ),
                ],
              ),
              const SizedBox(height: AppHeights.reg),

              // Cost Filter
              Text(
                'cost'.tr(),
                style: AppTextStyles.cardTitle,
              ),
              const SizedBox(height: AppHeights.small),
              Wrap(
                spacing: AppWidths.small,
                runSpacing: AppHeights.small,
                children: [
                  FilterChip(
                    label: Text('free'.tr()),
                    selected: _selectedCostType == CostType.free,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCostType = selected ? CostType.free : null;
                      });
                    },
                    selectedColor: AppColors.blue.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.blue,
                  ),
                  FilterChip(
                    label: Text('paid'.tr()),
                    selected: _selectedCostType == CostType.paid,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCostType = selected ? CostType.paid : null;
                      });
                    },
                    selectedColor: AppColors.blue.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.blue,
                  ),
                ],
              ),
              const SizedBox(height: AppHeights.reg),

              // Apply Button
              ElevatedButton(
                onPressed: () {
                  widget.onApply(
                    _selectedAgeGroup,
                    _isRecurringFilter,
                    _selectedCostType,
                  );
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.white,
                  padding: AppPaddings.symmReg,
                ),
                child: Text('apply_filters'.tr()),
              ),
              const SizedBox(height: AppHeights.small),
            ],
          ),
        ),
      ),
    );
  }
}
