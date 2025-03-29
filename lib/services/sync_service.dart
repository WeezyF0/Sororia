import 'package:algolia_client_search/algolia_client_search.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AlgoliaSyncService {
  final SearchClient _algoliaClient;
  final FirebaseFirestore _firestore;
  final String _algoliaIndexName;
  
  AlgoliaSyncService({
    required String algoliaAppId,
    required String algoliaApiKey,
    required String algoliaIndexName,
    FirebaseFirestore? firestore,
  }) : _algoliaClient = SearchClient(appId: algoliaAppId, apiKey: algoliaApiKey),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _algoliaIndexName = algoliaIndexName;

  /// Syncs unqueried complaints from Firebase to Algolia
  Future<SyncResult> syncComplaintsToAlgolia() async {
    try {
      // Get reference to Firestore "complaints" collection
      final complaintsRef = _firestore.collection('complaints');

      // Query for complaints where 'queried' is false
      final querySnapshot = await complaintsRef
          .where('queried', isEqualTo: false)
          .get();

      // Prepare batch requests for Algolia
      final List<BatchRequest> batchRequests = [];

      // Process each complaint
      for (var doc in querySnapshot.docs) {
        final complaintData = doc.data();
        final complaintId = doc.id;
        
        print('Processing complaint: $complaintId');

        // Create Algolia object directly from complaint data
        // Split issue_type string into tags array
        List<String> tags = [];
        if (complaintData['issue_type'] != null) {
          tags = (complaintData['issue_type'] as String)
              .split(',')
              .map((tag) => tag.trim())
              .toList();
        }

        // Add to batch requests
        batchRequests.add(
          BatchRequest(
            action: Action.fromJson('addObject'),
            body: {
              'objectID': complaintId,
              ...complaintData,
              '_tags': tags,
            },
          ),
        );

        // Update the complaint in Firebase to mark it as queried
        await complaintsRef.doc(complaintId).update({'queried': true});
      }

      // If there are complaints to add to Algolia
      if (batchRequests.isNotEmpty) {
        // Send batch to Algolia
        final response = await _algoliaClient.batch(
          indexName: _algoliaIndexName,
          batchWriteParams: BatchWriteParams(
            requests: batchRequests,
          ),
        );
        
        return SyncResult(
          success: true,
          syncedCount: batchRequests.length,
          message: 'Successfully synced ${batchRequests.length} complaints to Algolia',
          response: response,
        );
      } else {
        return SyncResult(
          success: true,
          syncedCount: 0,
          message: 'No complaints found with queried=false',
        );
      }
    } catch (e) {
      return SyncResult(
        success: false,
        syncedCount: 0,
        message: 'Error syncing complaints to Algolia: ${e.toString()}',
        error: e,
      );
    }
  }
  
  /// Manually sync a specific complaint to Algolia
  Future<SyncResult> syncSpecificComplaint(String complaintId) async {
    try {
      final complaintsRef = _firestore.collection('complaints');
      final docSnapshot = await complaintsRef.doc(complaintId).get();
      
      if (!docSnapshot.exists) {
        return SyncResult(
          success: false,
          syncedCount: 0,
          message: 'Complaint with ID $complaintId not found',
        );
      }
      
      final complaintData = docSnapshot.data()!;
      
      // Create Algolia object
      List<String> tags = [];
      if (complaintData['issue_type'] != null) {
        tags = (complaintData['issue_type'] as String)
            .split(',')
            .map((tag) => tag.trim())
            .toList();
      }
      
      final response = await _algoliaClient.batch(
        indexName: _algoliaIndexName,
        batchWriteParams: BatchWriteParams(
          requests: [
            BatchRequest(
              action: Action.fromJson('addObject'),
              body: {
                'objectID': complaintId,
                ...complaintData,
                '_tags': tags,
              },
            ),
          ],
        ),
      );
      
      // Mark as queried in Firebase
      await complaintsRef.doc(complaintId).update({'queried': true});
      
      return SyncResult(
        success: true,
        syncedCount: 1,
        message: 'Successfully synced complaint $complaintId to Algolia',
        response: response,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        syncedCount: 0,
        message: 'Error syncing complaint to Algolia: ${e.toString()}',
        error: e,
      );
    }
  }
}

/// Result object for sync operations
class SyncResult {
  final bool success;
  final int syncedCount;
  final String message;
  final dynamic response;
  final dynamic error;
  
  SyncResult({
    required this.success,
    required this.syncedCount,
    required this.message,
    this.response,
    this.error,
  });
  
  @override
  String toString() {
    return 'SyncResult(success: $success, syncedCount: $syncedCount, message: $message)';
  }
}