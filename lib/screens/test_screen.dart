import 'package:flutter/material.dart';
import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:complaints_app/services/sync_service.dart';
import 'navbar.dart';

class SearchMetadata {
  final int nbHits;

  const SearchMetadata(this.nbHits);

  factory SearchMetadata.fromResponse(SearchResponse response) =>
      SearchMetadata(response.nbHits);
}

class Product {
  final String objectId;
  final String issueType;
  final String processedText;
  final String originalText;
  final String location;
  final DateTime timestamp;

  Product(
    this.objectId,
    this.issueType,
    this.processedText,
    this.originalText,
    this.location,
    this.timestamp,
  );

  static Product fromJson(Map<String, dynamic> json) {
    return Product(
      json['objectID'],
      json['issue_type'],
      json['processed_text'],
      json['original_text'],
      json['location'],
      DateTime.parse(json['timestamp']),
    );
  }
}

class HitsPage {
  const HitsPage(this.items, this.pageKey, this.nextPageKey);

  final List<Product> items;
  final int pageKey;
  final int? nextPageKey;

  factory HitsPage.fromResponse(SearchResponse response) {
    final items = response.hits.map(Product.fromJson).toList();
    final isLastPage = response.page >= response.nbPages;
    final nextPageKey = isLastPage ? null : response.page + 1;
    return HitsPage(items, response.page, nextPageKey);
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final _productsSearcher = HitsSearcher(
    applicationID: dotenv.env['algolia-app-id'] ?? '',
    apiKey: dotenv.env['algolia-api'] ?? '',
    indexName: 'Gram_Sewa',
  );
  final _searchTextController = TextEditingController();

  Stream<SearchMetadata> get _searchMetadata =>
      _productsSearcher.responses.map(SearchMetadata.fromResponse);

  final PagingController<int, Product> _pagingController = PagingController(
    firstPageKey: 0,
  );
  Stream<HitsPage> get _searchPage =>
      _productsSearcher.responses.map(HitsPage.fromResponse);

  Widget _hits(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final errorColor = Theme.of(context).colorScheme.error;

    return PagedListView<int, Product>(
      pagingController: _pagingController,
      builderDelegate: PagedChildBuilderDelegate<Product>(
        noItemsFoundIndicatorBuilder:
            (_) => const Center(child: Text('No complaints found')),
        itemBuilder:
            (_, item, __) => GestureDetector(
              onTap: () async {
                try {
                  final doc =
                      await FirebaseFirestore.instance
                          .collection('complaints')
                          .doc(item.objectId)
                          .get();

                  if (doc.exists) {
                    Navigator.pushNamed(
                      context,
                      '/open_complaint',
                      arguments: {
                        'complaintData': doc.data(),
                        'complaintId': doc.id,
                      },
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Complaint not found')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          isDarkMode
                              ? Colors.black12
                              : Colors.grey.withOpacity(0.1),
                      blurRadius: 5,
                      spreadRadius: 2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.issueType,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: errorColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.processedText,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Original: ${item.originalText}',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.location,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${item.timestamp.toLocal()}'.split(' ')[0],
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 12,
                          ),
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

  final _filterState = FilterState();

  late final _facetList = _productsSearcher.buildFacetList(
    filterState: _filterState,
    attribute: '_tags',
  );

  Widget _filters(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filters'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<SelectableItem<Facet>>>(
        stream: _facetList.facets,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }
          final selectableFacets = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: selectableFacets.length,
            itemBuilder: (_, index) {
              final selectableFacet = selectableFacets[index];
              return CheckboxListTile(
                value: selectableFacet.isSelected,
                activeColor: primaryColor,
                title: Text(
                  "${selectableFacet.item.value} (${selectableFacet.item.count})",
                ),
                onChanged: (_) {
                  _facetList.toggle(selectableFacet.item.value);
                },
              );
            },
          );
        },
      ),
    );
  }

  final GlobalKey<ScaffoldState> _mainScaffoldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _searchTextController.addListener(
      () => _productsSearcher.applyState(
        (state) => state.copyWith(query: _searchTextController.text, page: 0),
      ),
    );
    _searchPage
        .listen((page) {
          if (page.pageKey == 0) {
            _pagingController.refresh();
          }
          _pagingController.appendPage(page.items, page.nextPageKey);
        })
        .onError((error) => _pagingController.error = error);
    _pagingController.addPageRequestListener(
      (pageKey) => _productsSearcher.applyState(
        (state) => state.copyWith(page: pageKey),
      ),
    );
    _productsSearcher.connectFilterState(_filterState);
    _filterState.filters.listen((_) => _pagingController.refresh());
  }

  @override
  void dispose() {
    _searchTextController.dispose();
    _productsSearcher.dispose();
    _pagingController.dispose();
    _filterState.dispose();
    _facetList.dispose();
    super.dispose();
  }

  final AlgoliaSyncService _syncService = AlgoliaSyncService(
    algoliaAppId: dotenv.env['algolia-app-id'] ?? '',
    algoliaApiKey: dotenv.env['algolia-write-api'] ?? '',
    algoliaIndexName: 'Gram_Sewa',
  );

  Future<void> _syncComplaints() async {
    final result = await _syncService.syncComplaintsToAlgolia();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));

    // Reload the screen after syncing
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const TestScreen()),
    );
  }

  Widget buildLoadingScreen() {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryColor, primaryColor.withOpacity(0.8)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 20),
              Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      key: _mainScaffoldKey,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          toolbarHeight: 80,
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () => _mainScaffoldKey.currentState?.openEndDrawer(),
              icon: Icon(
                Icons.filter_list_sharp,
                color: theme.colorScheme.onBackground,
              ),
              tooltip: 'Filters',
            ),
            IconButton(
              onPressed: _syncComplaints,
              icon: Icon(Icons.sync, color: theme.colorScheme.onBackground),
              tooltip: 'Sync',
            ),
          ],
          title: const Text(
            "SEARCH EXPERIENCES",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              fontSize: 24,
            ),
          ),
        ),
      ),
      drawer: NavBar(),
      endDrawer: Drawer(child: _filters(context)),
      body: Center(
        child: Column(
          children: <Widget>[
            Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        isDarkMode
                            ? Colors.black12
                            : Colors.grey.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchTextController,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: 'Poppins',
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search by keyword, location, or tag...',
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontFamily: 'Poppins',
                  ),
                  prefixIcon: Icon(Icons.search, color: primaryColor),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 8,
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
              ),
            ),
            StreamBuilder<SearchMetadata>(
              stream: _searchMetadata,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '${snapshot.data!.nbHits} results',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontFamily: 'Poppins',
                    ),
                  ),
                );
              },
            ),
            Expanded(child: _hits(context)),
          ],
        ),
      ),
    );
  }
}
