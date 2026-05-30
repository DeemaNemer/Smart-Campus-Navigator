import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_colors.dart';
import '../../models/search_result.dart';
import '../../providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchCategory {
  final String id;
  final String label;
  final IconData icon;

  const _SearchCategory(this.id, this.label, this.icon);
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  static const _categories = [
    _SearchCategory('classroom', 'Classrooms', Icons.co_present_outlined),
    _SearchCategory('lab', 'Labs', Icons.computer_outlined),
    _SearchCategory('office', 'Offices', Icons.work_outline),
    _SearchCategory('bathroom', 'Bathrooms', Icons.wc_outlined),
    _SearchCategory('professor', 'Professors', Icons.person_search_outlined),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _runSearch() {
    final category = ref.read(searchProvider).category;
    ref.read(searchProvider.notifier).search(
          _controller.text,
          category: category,
        );
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  void _selectCategory(String? category) {
    _debounce?.cancel();
    ref.read(searchProvider.notifier).selectCategory(category);
    setState(() {});
    _runSearch();
  }

  Future<void> _openCategoryPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final current = ref.read(searchProvider).category;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Results',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: current == null
                        ? AppColors.accent.withValues(alpha: 0.2)
                        : AppColors.primaryLight,
                    child: Icon(
                      Icons.all_inclusive,
                      color: current == null
                          ? AppColors.accentDark
                          : AppColors.primary,
                    ),
                  ),
                  title: Text(
                    'All Results',
                    style: TextStyle(
                      fontWeight:
                          current == null ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  trailing: current == null
                      ? const Icon(Icons.check_circle, color: AppColors.accent)
                      : null,
                  onTap: () => Navigator.pop(context, '__all__'),
                ),
                ..._categories.map((category) {
                  final isSelected = current == category.id;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? AppColors.accent.withValues(alpha: 0.2)
                          : AppColors.primaryLight,
                      child: Icon(
                        category.icon,
                        color: isSelected
                            ? AppColors.accentDark
                            : AppColors.primary,
                      ),
                    ),
                    title: Text(
                      category.label,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: AppColors.accent)
                        : null,
                    onTap: () => Navigator.pop(context, category.id),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected == '__all__') {
      _selectCategory(null);
    } else if (selected != null) {
      _selectCategory(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            _buildSearchBar(state.category),
            _buildSectionTitle(state),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(String? selectedCategory) {
    final enabled = selectedCategory != null;
    final category = selectedCategory == null
        ? null
        : _categories.firstWhere((category) => category.id == selectedCategory);
    final categoryLabel = category?.label.toLowerCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _controller,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: enabled
              ? 'Search in $categoryLabel or leave empty to browse'
              : 'Search anything on campus',
          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    _runSearch();
                    setState(() {});
                  },
                ),
              IconButton(
                tooltip: 'Choose category',
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      category?.icon ?? Icons.tune,
                      color: enabled ? AppColors.accentDark : AppColors.primary,
                    ),
                    if (enabled)
                      const Positioned(
                        right: -2,
                        top: -2,
                        child: Icon(
                          Icons.check_circle,
                          size: 10,
                          color: AppColors.accent,
                        ),
                      ),
                  ],
                ),
                onPressed: _openCategoryPicker,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(SearchState state) {
    final category = state.category;
    if (state.query.trim().isEmpty && category == null) {
      return const SizedBox.shrink();
    }

    final label = category == null
        ? 'results'
        : _categories.firstWhere((c) => c.id == category).label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        state.isLoading
            ? 'Searching...'
            : '${state.results.length} $label found',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBody(SearchState state) {
    if (state.query.trim().isEmpty && state.category == null) {
      return _buildStartSearching();
    }

    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.error != null) return _buildErrorState(state.error!);

    if (state.results.isEmpty) return _buildNoResults();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _ResultCard(result: state.results[index]);
      },
    );
  }

  Widget _buildStartSearching() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: AppColors.primaryLight),
            SizedBox(height: 16),
            Text(
              'Search anything on campus',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Use the filter button only when you want fewer results.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: AppColors.textLight),
          SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Try a room number, name, or another category.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _runSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SearchResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isRoom = result.type == SearchResultType.room;
    final icon = isRoom ? _roomIcon(result.room!.type) : Icons.person;
    final iconColor = isRoom ? AppColors.primary : AppColors.accent;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (result.type == SearchResultType.room) {
            context.push('/room', extra: result.room);
          } else {
            context.push('/professor', extra: result.professor);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      result.displaySubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  IconData _roomIcon(String type) {
    switch (type) {
      case 'lab':
        return Icons.computer_outlined;
      case 'office':
        return Icons.work_outline;
      case 'bathroom':
        return Icons.wc_outlined;
      default:
        return Icons.meeting_room_outlined;
    }
  }
}
