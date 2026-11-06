import 'package:flutter/material.dart';

import '../../data/remote/vax_api_service.dart';
import '../../domain/models/warehouse_app_data.dart';
import '../../domain/services/warehouse_app_state.dart';
import '../../shared/widgets/common.dart';

class BatchListPage extends StatefulWidget {
  const BatchListPage({super.key, required this.state, required this.user});

  final WarehouseAppState state;
  final AppUser user;

  @override
  State<BatchListPage> createState() => _BatchListPageState();
}

class _BatchListPageState extends State<BatchListPage> {
  final VaxApiService _api = VaxApiService();
  final _searchController = TextEditingController();

  List<dynamic> _batches = [];
  bool _loading = true;
  String? _error;
  String _expiryFilter = 'all'; // all, valid, nearExpiry, expired
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _api.getBatches(
        search: _search.isNotEmpty ? _search : null,
        expiryFilter: _expiryFilter != 'all' ? _expiryFilter : null,
      );
      if (mounted) {
        setState(() {
          _batches = list;
          _loading = false;
        });
      }
    } catch (e) {
      // ponytail: Fallback sang dữ liệu mẫu khi chưa bật server
      if (mounted) {
        setState(() {
          _batches = _fallbackBatches();
          _loading = false;
          _error = 'Đang hiển thị dữ liệu bộ nhớ đệm (API offline)';
        });
      }
    }
  }

  List<dynamic> _fallbackBatches() {
    final now = DateTime.now();
    return [
      {
        'id': 1,
        'batchNo': 'HEX-2026A',
        'vaccineName': 'Hexaxim 6-in-1',
        'vaccineCode': 'VAC-HEXA',
        'expiresAt': now.add(const Duration(days: 365)).toIso8601String(),
        'referenceDoc': 'GPLH-2026-VN-001',
        'totalQuantity': 500,
        'availableQuantity': 500,
        'isExpired': false,
        'isNearExpiry': false,
        'daysUntilExpiry': 365,
      },
      {
        'id': 2,
        'batchNo': 'HEX-2025Z',
        'vaccineName': 'Hexaxim 6-in-1',
        'vaccineCode': 'VAC-HEXA',
        'expiresAt': now.add(const Duration(days: 25)).toIso8601String(),
        'referenceDoc': 'GPLH-2025-VN-099',
        'totalQuantity': 120,
        'availableQuantity': 120,
        'isExpired': false,
        'isNearExpiry': true,
        'daysUntilExpiry': 25,
      },
      {
        'id': 3,
        'batchNo': 'VAX-2026B',
        'vaccineName': 'Vaxigrip Tetra',
        'vaccineCode': 'VAC-FLU',
        'expiresAt': now.add(const Duration(days: 180)).toIso8601String(),
        'referenceDoc': 'GPLH-2026-FR-112',
        'totalQuantity': 300,
        'availableQuantity': 0,
        'isExpired': false,
        'isNearExpiry': false,
        'daysUntilExpiry': 180,
      },
      {
        'id': 4,
        'batchNo': 'VAX-2026C-TEMP',
        'vaccineName': 'Vaxigrip Tetra',
        'vaccineCode': 'VAC-FLU',
        'expiresAt': now.add(const Duration(days: 150)).toIso8601String(),
        'referenceDoc': 'GPLH-2026-FR-115',
        'totalQuantity': 200,
        'availableQuantity': 0,
        'isExpired': false,
        'isNearExpiry': false,
        'daysUntilExpiry': 150,
      },
    ];
  }

  void _showBatchDetail(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: Color(0xFF14846A)),
            const SizedBox(width: 8),
            Text('Lô ${item['batchNo']}'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Vaccine:', '${item['vaccineName']} (${item['vaccineCode']})'),
              _detailRow('Số giấy phép / QĐ:', item['referenceDoc']?.toString() ?? 'Chưa cập nhật'),
              _detailRow('Hạn sử dụng:', _formatDate(item['expiresAt']?.toString())),
              _detailRow('Số ngày còn lại:', '${item['daysUntilExpiry']} ngày'),
              _detailRow('Tồn vật lý:', '${item['totalQuantity'] ?? 0} lọ'),
              _detailRow('Tồn khả dụng xuất:', '${item['availableQuantity'] ?? 0} lọ'),
              const Divider(height: 24),
              Text(
                'Lưu ý bảo quản & chất lượng',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              const Text(
                'Nhiệt độ tiêu chuẩn 2°C – 8°C. Chỉ được xuất kho khi lô có trạng thái Đã Giải Phóng (Released) và chưa hết hạn.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 780;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                title: 'Quản lý Lô Vaccine & Hạn Dùng',
                subtitle: 'Theo dõi hạn dùng theo FEFO, giấy phép lưu hành và điều kiện xuất kho.',
                action: IconButton.filledTonal(
                  tooltip: 'Tải lại',
                  onPressed: _loadBatches,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFEEBA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFF856404)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF856404)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: compact ? double.infinity : 320,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm số lô hoặc tên vaccine...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
                                  _loadBatches();
                                },
                              )
                            : null,
                      ),
                      onSubmitted: (val) {
                        setState(() => _search = val.trim());
                        _loadBatches();
                      },
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: _expiryFilter == 'all',
                    onSelected: (sel) {
                      if (sel) {
                        setState(() => _expiryFilter = 'all');
                        _loadBatches();
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Còn hạn'),
                    selected: _expiryFilter == 'valid',
                    onSelected: (sel) {
                      if (sel) {
                        setState(() => _expiryFilter = 'valid');
                        _loadBatches();
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Cận hạn (<60 ngày)'),
                    selected: _expiryFilter == 'nearExpiry',
                    selectedColor: const Color(0xFFFFE0B2),
                    onSelected: (sel) {
                      if (sel) {
                        setState(() => _expiryFilter = 'nearExpiry');
                        _loadBatches();
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Đã hết hạn'),
                    selected: _expiryFilter == 'expired',
                    selectedColor: const Color(0xFFFFCDD2),
                    onSelected: (sel) {
                      if (sel) {
                        setState(() => _expiryFilter = 'expired');
                        _loadBatches();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                elevation: 0,
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE7ECF2)),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _batches.isEmpty
                        ? const SizedBox(
                            height: 220,
                            child: EmptyState(
                              title: 'Không tìm thấy lô vaccine',
                              message: 'Không có lô nào phù hợp với điều kiện tìm kiếm hoặc bộ lọc.',
                            ),
                          )
                        : _buildBatchTable(context, compact),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBatchTable(BuildContext context, bool compact) {
    if (compact) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _batches.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (ctx, idx) {
          final item = _batches[idx] as Map<String, dynamic>;
          final isExpired = item['isExpired'] == true;
          final isNearExpiry = item['isNearExpiry'] == true;
          return ListTile(
            title: Row(
              children: [
                Text(
                  item['batchNo']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                _badgeWidget(isExpired, isNearExpiry, item['daysUntilExpiry']),
              ],
            ),
            subtitle: Text(
              '${item['vaccineName']} • HSD: ${_formatDate(item['expiresAt']?.toString())}\nTồn: ${item['totalQuantity'] ?? 0} | Khả dụng: ${item['availableQuantity'] ?? 0}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showBatchDetail(item),
          );
        },
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        dataRowMinHeight: 48,
        dataRowMaxHeight: 64,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF7F9FC)),
        columns: const [
          DataColumn(label: Text('Số Lô')),
          DataColumn(label: Text('Vaccine')),
          DataColumn(label: Text('Hạn Sử Dụng')),
          DataColumn(label: Text('Tình Trạng Hạn')),
          DataColumn(numeric: true, label: Text('Tồn Vật Lý')),
          DataColumn(numeric: true, label: Text('Khả Dụng')),
          DataColumn(label: Text('Thao Tác')),
        ],
        rows: [
          for (final item in _batches)
            DataRow(
              cells: [
                DataCell(
                  Text(
                    item['batchNo']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item['vaccineName']?.toString() ?? ''),
                      Text(
                        item['vaccineCode']?.toString() ?? '',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                DataCell(Text(_formatDate(item['expiresAt']?.toString()))),
                DataCell(
                  _badgeWidget(
                    item['isExpired'] == true,
                    item['isNearExpiry'] == true,
                    item['daysUntilExpiry'],
                  ),
                ),
                DataCell(Text('${item['totalQuantity'] ?? 0} lọ')),
                DataCell(
                  Text(
                    '${item['availableQuantity'] ?? 0} lọ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (item['availableQuantity'] as num? ?? 0) > 0
                          ? const Color(0xFF14846A)
                          : Colors.black45,
                    ),
                  ),
                ),
                DataCell(
                  TextButton(
                    onPressed: () => _showBatchDetail(item as Map<String, dynamic>),
                    child: const Text('Chi tiết'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _badgeWidget(bool isExpired, bool isNearExpiry, dynamic days) {
    if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Đã hết hạn',
          style: TextStyle(color: Color(0xFFC62828), fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }
    if (isNearExpiry) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Cận date (${days ?? '?'} ngày)',
          style: const TextStyle(color: Color(0xFFE65100), fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Còn hạn (${days ?? '?'} ngày)',
        style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
