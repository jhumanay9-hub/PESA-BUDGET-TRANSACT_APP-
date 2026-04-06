import 'dart:async';
import 'package:transaction_app/data/database_helper.dart';
import 'package:transaction_app/core/logger.dart';

/// ============================================================================
/// CATEGORY CACHE - Singleton for sharing categories across widgets
/// ============================================================================
/// This prevents redundant database queries by caching categories centrally.
/// Dashboard loads categories once, all widgets read from this cache.
/// FIX: Added isRefreshing lock to prevent stale reads during updates
/// ============================================================================
class CategoryCache {
  static final CategoryCache _instance = CategoryCache._internal();
  factory CategoryCache() => _instance;
  CategoryCache._internal();

  List<Map<String, dynamic>> _categories = [];
  DateTime? _cacheTime;
  final _cacheDuration = const Duration(minutes: 5);

  // FIX: Lock to prevent reads during refresh
  bool _isRefreshing = false;

  // Stream to notify widgets of category changes
  final _controller = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get categoriesStream => _controller.stream;

  /// Check if cache is valid
  bool get isValid =>
      !_isRefreshing &&
      _categories.isNotEmpty &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheDuration;

  /// Get cached categories (returns empty list if not loaded or refreshing)
  List<Map<String, dynamic>> get categories => List.unmodifiable(_categories);

  /// Check if cache is currently being refreshed
  bool get isRefreshing => _isRefreshing;

  /// Load categories from database (if not cached)
  Future<List<Map<String, dynamic>>> loadCategories() async {
    if (isValid) {
      AppLogger.logInfo(
          'CategoryCache: Using cached categories (${_categories.length} items)');
      return _categories;
    }

    // FIX: Wait if refresh is in progress
    if (_isRefreshing) {
      AppLogger.logInfo('CategoryCache: Refresh in progress, waiting...');
      await Future.delayed(const Duration(milliseconds: 100));
      if (isValid) return _categories;
    }

    try {
      final dbHelper = DatabaseHelper();
      _categories = await dbHelper.getAllCategoriesWithDetails();
      _cacheTime = DateTime.now();

      AppLogger.logInfo(
          'CategoryCache: Loaded ${_categories.length} categories from DB');
      _controller.add(_categories);

      return _categories;
    } catch (e) {
      AppLogger.logError('CategoryCache: Failed to load categories', e);
      return [];
    }
  }

  /// Force refresh categories (call after category is added/deleted)
  /// FIX: Atomic invalidation - clears cache completely before reloading
  Future<List<Map<String, dynamic>>> refreshCategories() async {
    // FIX: Set lock to prevent stale reads
    _isRefreshing = true;
    AppLogger.logInfo('CategoryCache: Starting atomic refresh...');

    try {
      // FIX: Clear cache FIRST to prevent any stale reads
      _categories = [];
      _cacheTime = null;

      final dbHelper = DatabaseHelper();
      _categories = await dbHelper.getAllCategoriesWithDetails();
      _cacheTime = DateTime.now();

      AppLogger.logInfo(
          'CategoryCache: Refreshed ${_categories.length} categories');
      _controller.add(_categories);

      return _categories;
    } catch (e) {
      AppLogger.logError('CategoryCache: Failed to refresh categories', e);
      return [];
    } finally {
      // FIX: Release lock
      _isRefreshing = false;
      AppLogger.logInfo('CategoryCache: Atomic refresh complete');
    }
  }

  /// Clear cache (call when data is stale)
  void clear() {
    _categories = [];
    _cacheTime = null;
    _isRefreshing = false;
    AppLogger.logInfo('CategoryCache: Cleared');
  }

  /// Dispose stream
  void dispose() {
    _controller.close();
  }
}
