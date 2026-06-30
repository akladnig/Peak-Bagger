import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/widgets/popup_shell.dart';
import '../models/map_search_result.dart';
import '../theme.dart';
import 'map_search_results_list.dart';

class MapSearchPopup extends StatelessWidget {
  const MapSearchPopup({
    required this.focusNode,
    required this.searchResults,
    required this.searchQuery,
    required this.onChanged,
    required this.onClose,
    required this.onSelectResult,
    super.key,
  });

  final FocusNode focusNode;
  final List<MapSearchResult> searchResults;
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final ValueChanged<MapSearchResult> onSelectResult;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 480,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: PopupShell(
          key: const Key('map-search-popup'),
          title: const Text('Search'),
          onClose: onClose,
          closeButtonKey: const Key('map-search-close'),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('map-search-input'),
                focusNode: focusNode,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  isDense: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onChanged: onChanged,
              ),
              const SizedBox(height: PopupUIConstants.actionSpacing),
              thinDivider,
              if (searchQuery.isNotEmpty || searchResults.isNotEmpty) ...[
                const SizedBox(height: PopupUIConstants.actionSpacing),
                Text('Results', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: PopupUIConstants.headerSpacing),
                SizedBox(
                  height: 320,
                  child: MapSearchResultsList(
                    searchResults: searchResults,
                    searchQuery: searchQuery,
                    onSelectResult: onSelectResult,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
