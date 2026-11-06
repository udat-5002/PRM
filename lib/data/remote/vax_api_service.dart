import 'api_client.dart';

class VaxApiService {
  final ApiClient _client = ApiClient();

  // 1. Auth
  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _client.post('/api/auth/login', {
      'username': username,
      'password': password,
    });
    final map = Map<String, dynamic>.from(res as Map);
    _client.setToken(map['token'] as String?);
    return map;
  }

  void logout() {
    _client.setToken(null);
  }

  // 2. Master Data
  Future<List<dynamic>> getWarehouses() async {
    final res = await _client.get('/api/masterdata/warehouses');
    return res as List<dynamic>;
  }

  Future<List<dynamic>> getLocations(int warehouseId) async {
    final res = await _client.get('/api/masterdata/warehouses/$warehouseId/locations');
    return res as List<dynamic>;
  }

  Future<List<dynamic>> getPartners([String? type]) async {
    final res = await _client.get(
      '/api/masterdata/partners',
      type != null ? {'type': type} : null,
    );
    return res as List<dynamic>;
  }

  Future<List<dynamic>> getVaccines() async {
    final res = await _client.get('/api/masterdata/vaccines');
    return res as List<dynamic>;
  }

  // 3. Batches
  Future<List<dynamic>> getBatches({
    int? vaccineId,
    String? search,
    String? expiryFilter,
  }) async {
    final query = <String, dynamic>{};
    if (vaccineId != null) query['vaccineId'] = vaccineId;
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (expiryFilter != null) query['expiryFilter'] = expiryFilter;

    final res = await _client.get('/api/batches', query);
    return res as List<dynamic>;
  }

  Future<Map<String, dynamic>> getBatchDetail(int id) async {
    final res = await _client.get('/api/batches/$id');
    return Map<String, dynamic>.from(res as Map);
  }

  // 4. Inventory & Dashboard
  Future<List<dynamic>> getStock({
    int? warehouseId,
    int? vaccineId,
    String? qualityStatus,
    String? search,
  }) async {
    final query = <String, dynamic>{};
    if (warehouseId != null) query['warehouseId'] = warehouseId;
    if (vaccineId != null) query['vaccineId'] = vaccineId;
    if (qualityStatus != null) query['qualityStatus'] = qualityStatus;
    if (search != null && search.isNotEmpty) query['search'] = search;

    final res = await _client.get('/api/inventory/stock', query);
    return res as List<dynamic>;
  }

  Future<Map<String, dynamic>> getDashboardSummary([int? warehouseId]) async {
    final query = warehouseId != null ? {'warehouseId': warehouseId} : null;
    final res = await _client.get('/api/inventory/dashboard', query);
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> getFefoSuggestion({
    required int warehouseId,
    required int vaccineId,
    required int quantity,
  }) async {
    final res = await _client.get('/api/inventory/fefo-suggestion', {
      'warehouseId': warehouseId,
      'vaccineId': vaccineId,
      'quantity': quantity,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<dynamic>> getMovements([int? warehouseId]) async {
    final query = warehouseId != null ? {'warehouseId': warehouseId} : null;
    final res = await _client.get('/api/inventory/movements', query);
    return res as List<dynamic>;
  }

  // 5. Documents (Receipt / Issue)
  Future<List<dynamic>> getDocuments({
    String? type,
    String? status,
    int? warehouseId,
  }) async {
    final query = <String, dynamic>{};
    if (type != null) query['type'] = type;
    if (status != null) query['status'] = status;
    if (warehouseId != null) query['warehouseId'] = warehouseId;

    final res = await _client.get('/api/documents', query);
    return res as List<dynamic>;
  }

  Future<Map<String, dynamic>> getDocumentById(int id) async {
    final res = await _client.get('/api/documents/$id');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> createReceipt(Map<String, dynamic> data) async {
    final res = await _client.post('/api/documents/receipt', data);
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> postReceipt(int id) async {
    final res = await _client.post('/api/documents/receipt/$id/post', {});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> createIssue(Map<String, dynamic> data) async {
    final res = await _client.post('/api/documents/issue', data);
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> postIssue(int id) async {
    final res = await _client.post('/api/documents/issue/$id/post', {});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> cancelDocument(int id) async {
    final res = await _client.post('/api/documents/$id/cancel', {});
    return Map<String, dynamic>.from(res as Map);
  }

  // 6. Quality
  Future<List<dynamic>> getPendingQuality([int? warehouseId]) async {
    final query = warehouseId != null ? {'warehouseId': warehouseId} : null;
    final res = await _client.get('/api/quality/pending', query);
    return res as List<dynamic>;
  }

  Future<List<dynamic>> getQualityDecisions([int? batchId]) async {
    final query = batchId != null ? {'batchId': batchId} : null;
    final res = await _client.get('/api/quality/decisions', query);
    return res as List<dynamic>;
  }

  Future<Map<String, dynamic>> applyQualityDecision({
    required int batchId,
    int? segmentId,
    required String newStatus,
    required String reason,
    String? note,
  }) async {
    final res = await _client.post('/api/quality/decision', {
      'batchId': batchId,
      'segmentId': segmentId,
      'newStatus': newStatus,
      'reason': reason,
      'note': note,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  // 7. Trade Shipments (XNK)
  Future<List<dynamic>> getTradeShipments([String? type]) async {
    final query = type != null ? {'type': type} : null;
    final res = await _client.get('/api/tradeshipments', query);
    return res as List<dynamic>;
  }

  Future<Map<String, dynamic>> getTradeShipmentById(int id) async {
    final res = await _client.get('/api/tradeshipments/$id');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> createTradeShipment(Map<String, dynamic> data) async {
    final res = await _client.post('/api/tradeshipments', data);
    return Map<String, dynamic>.from(res as Map);
  }
}
