import 'package:flutter/material.dart';

/// Generic pagination helper for managing paginated data loading
class PaginationHelper<T> {
  final int pageSize;
  final int loadMoreThreshold;
  final Future<List<T>> Function(int page, int pageSize) loadData;
  final bool Function(T item)? filter;

  List<T> _allItems = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMoreData = true;
  String? _error;
  final ValueNotifier<PaginationState<T>> _stateNotifier =
      ValueNotifier(PaginationState<T>(
    items: [],
    isLoading: false,
    hasMoreData: true,
    error: null,
    currentPage: 0,
    totalItems: 0,
  ));

  PaginationHelper({
    required this.loadData,
    this.pageSize = 30,
    this.loadMoreThreshold = 5,
    this.filter,
  });

  /// Get all currently loaded items
  List<T> get items => _allItems;

  /// Check if currently loading
  bool get isLoading => _isLoading;

  /// Check if there's more data to load
  bool get hasMoreData => _hasMoreData;

  /// Get current error if any
  String? get error => _error;

  /// Get current page number
  int get currentPage => _currentPage;

  /// Get total number of loaded items
  int get totalItems => _allItems.length;

  /// Initialize pagination and load first page
  Future<void> initialize() async {
    await loadFirstPage();
  }

  /// Load the first page of data
  Future<void> loadFirstPage() async {
    if (_isLoading) return;

    _currentPage = 0;
    _allItems.clear();
    _hasMoreData = true;
    _error = null;

    await _loadPage(0);
  }

  /// Load the next page of data
  Future<void> loadNextPage() async {
    if (_isLoading || !_hasMoreData) return;

    await _loadPage(_currentPage + 1);
  }

  /// Load a specific page
  Future<void> _loadPage(int page) async {
    _isLoading = true;
    _error = null;

    try {
      final newItems = await loadData(page, pageSize);

      if (page == 0) {
        _allItems = newItems;
      } else {
        _allItems.addAll(newItems);
      }

      _currentPage = page;
      _hasMoreData = newItems.length == pageSize;

      // Apply filter if provided
      if (filter != null) {
        _allItems = _allItems.where(filter!).toList();
      }
    } catch (e) {
      _error = e.toString();
      if (page == 0) {
        _allItems.clear();
      }
    } finally {
      _isLoading = false;
      _updateState();
    }
  }

  /// Refresh all data
  Future<void> refresh() async {
    await loadFirstPage();
  }

  /// Check if should load more data based on scroll position
  bool shouldLoadMore(int visibleItemIndex) {
    return !_isLoading &&
        _hasMoreData &&
        visibleItemIndex >= (_allItems.length - loadMoreThreshold);
  }

  /// Add an item to the current list (useful for optimistic updates)
  void addItem(T item) {
    _allItems.add(item);
  }

  /// Remove an item from the current list
  void removeItem(T item) {
    _allItems.remove(item);
  }

  /// Update an item in the current list
  void updateItem(T oldItem, T newItem) {
    final index = _allItems.indexOf(oldItem);
    if (index != -1) {
      _allItems[index] = newItem;
    }
  }

  /// Clear all data
  void clear() {
    _allItems.clear();
    _currentPage = 0;
    _isLoading = false;
    _hasMoreData = true;
    _error = null;
    _updateState();
  }

  /// Get pagination state for UI
  ValueNotifier<PaginationState<T>> get state => _stateNotifier;

  /// Update the state notifier
  void _updateState() {
    _stateNotifier.value = PaginationState(
      items: _allItems,
      isLoading: _isLoading,
      hasMoreData: _hasMoreData,
      error: _error,
      currentPage: _currentPage,
      totalItems: _allItems.length,
    );
  }
}

/// Pagination state for UI consumption
class PaginationState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMoreData;
  final String? error;
  final int currentPage;
  final int totalItems;

  const PaginationState({
    required this.items,
    required this.isLoading,
    required this.hasMoreData,
    this.error,
    required this.currentPage,
    required this.totalItems,
  });

  /// Check if this is the initial loading state
  bool get isInitialLoading => isLoading && currentPage == 0 && items.isEmpty;

  /// Check if this is loading more data
  bool get isLoadingMore => isLoading && currentPage > 0;

  /// Check if there's an error and no data
  bool get hasErrorAndNoData => error != null && items.isEmpty;

  /// Check if there's an error but some data exists
  bool get hasErrorWithData => error != null && items.isNotEmpty;
}

/// Scroll controller that automatically loads more data when scrolling
class PaginationScrollController extends ScrollController {
  final PaginationHelper paginationHelper;
  final VoidCallback? onLoadMore;

  PaginationScrollController({
    required this.paginationHelper,
    this.onLoadMore,
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  }) {
    addListener(_onScroll);
  }

  void _onScroll() {
    if (position.pixels >= position.maxScrollExtent - 200) {
      if (paginationHelper.shouldLoadMore(paginationHelper.totalItems)) {
        paginationHelper.loadNextPage();
        onLoadMore?.call();
      }
    }
  }

  @override
  void dispose() {
    removeListener(_onScroll);
    super.dispose();
  }
}

/// Widget that shows pagination loading states
class PaginationLoadingWidget extends StatelessWidget {
  final PaginationState state;
  final Widget Function(List items) itemBuilder;
  final Widget? emptyWidget;
  final Widget? errorWidget;
  final Widget? loadingWidget;
  final Widget? loadMoreWidget;

  const PaginationLoadingWidget({
    super.key,
    required this.state,
    required this.itemBuilder,
    this.emptyWidget,
    this.errorWidget,
    this.loadingWidget,
    this.loadMoreWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Show error state
    if (state.hasErrorAndNoData) {
      return errorWidget ?? _buildDefaultErrorWidget();
    }

    // Show initial loading
    if (state.isInitialLoading) {
      return loadingWidget ?? _buildDefaultLoadingWidget();
    }

    // Show empty state
    if (state.items.isEmpty) {
      return emptyWidget ?? _buildDefaultEmptyWidget();
    }

    // Show items with load more indicator
    return Column(
      children: [
        Expanded(child: itemBuilder(state.items)),
        if (state.isLoadingMore)
          loadMoreWidget ?? _buildDefaultLoadMoreWidget(),
        if (state.hasErrorWithData) _buildErrorBanner(),
      ],
    );
  }

  Widget _buildDefaultErrorWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Failed to load data'),
        ],
      ),
    );
  }

  Widget _buildDefaultLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildDefaultEmptyWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No data available'),
        ],
      ),
    );
  }

  Widget _buildDefaultLoadMoreWidget() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.red[50],
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Failed to load more data',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
