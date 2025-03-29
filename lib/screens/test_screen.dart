import 'package:flutter/material.dart';
import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:complaints_app/services/sync_service.dart'; // Adjust the import path


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

  Product(this.objectId, this.issueType, this.processedText, this.originalText, this.location, this.timestamp);

  static Product fromJson(Map<String, dynamic> json) {
    return Product(
      json['objectID'], // Assuming ObjectId is stored as a string
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

  final PagingController<int, Product> _pagingController =
      PagingController(firstPageKey: 0);
  Stream<HitsPage> get _searchPage =>
      _productsSearcher.responses.map(HitsPage.fromResponse);

  Widget _hits(BuildContext context) => PagedListView<int, Product>(
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<Product>(
          noItemsFoundIndicatorBuilder: (_) => const Center(
            child: Text('No complaints found'),
          ),
          itemBuilder: (_, item, __) => GestureDetector(
          onTap: () async {
            try {
              final doc = await FirebaseFirestore.instance
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.redAccent,
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
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.location,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                      Text(
                        '${item.timestamp.toLocal()}'.split(' ')[0],
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
final _filterState = FilterState();
	

late final _facetList = _productsSearcher.buildFacetList(
  filterState: _filterState,
  attribute: '_tags',
);
Widget _filters(BuildContext context) => Scaffold(
  appBar: AppBar(
    title: const Text('Filters'),
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
                title: Text(
                    "${selectableFacet.item.value} (${selectableFacet.item.count})"),
                onChanged: (_) {
                  _facetList.toggle(selectableFacet.item.value);
                },
              );
            });
      }),
);
final GlobalKey<ScaffoldState> _mainScaffoldKey = GlobalKey();

 @override
void initState() {
  super.initState();
  _searchTextController.addListener(
    () => _productsSearcher.applyState(
      (state) => state.copyWith(
        query: _searchTextController.text,
        page: 0,
      ),
    ),
  );
  _searchPage.listen((page) {
    if (page.pageKey == 0) {
      _pagingController.refresh();
    }
    _pagingController.appendPage(page.items, page.nextPageKey);
  }).onError((error) => _pagingController.error = error);
  _pagingController.addPageRequestListener(
    (pageKey) => _productsSearcher.applyState(
        (state) => state.copyWith(
          page: pageKey,
        )
    )
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );

    // Reload the screen after syncing
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const TestScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _mainScaffoldKey,
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          IconButton(
            onPressed: () => _mainScaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.filter_list_sharp),
          ),
          IconButton(
            onPressed: _syncComplaints,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: _filters(context),
      ),
          body: Center(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 44,
              child: TextField(
                controller: _searchTextController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter a search term',
                  prefixIcon: Icon(Icons.search),
                ),
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
                  child: Text('${snapshot.data!.nbHits} hits'),
                );
              },
            ),
            Expanded(
              child: _hits(context),
            )
          ],
        ),
      ),
    );
  }
}
