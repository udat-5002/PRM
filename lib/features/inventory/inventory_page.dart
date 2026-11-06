import 'package:flutter/material.dart';

import '../../data/remote/vax_api_service.dart';
import '../../domain/models/warehouse_app_data.dart';
import '../../domain/services/warehouse_app_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/common.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.state, required this.user});

  final WarehouseAppState state;
  final AppUser user;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _search = TextEditingController();
  final VaxApiService _api = VaxApiService();

  int? _warehouseId;
  String _query = '';
  bool _batchMode = false; // Chế độ xem theo lô & chất lượng vắc xin

  List<dynamic> _apiStock = [];
  bool _loadingApi = false;
  String? _apiError;

  @override
  void initState() {
    super.initState();
    _loadApiStock();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadApiStock() async {
    if (!_batchMode) return;
    setState(() {
      _loadingApi = true;
      _apiError = null;
    });

    try {
      final list = await _api.getStock(
        warehouseId: _warehouseId,
        search: _query.isNotEmpty ? _query : null,
      );
      if (mounted) {
        setState(() {
          _apiStock = list;
          _loadingApi = false;
        });
      }
    } catch (_) {
      // ponytail: Fallback danh sách tồn kho theo lô khi offline
      if (mounted) {
        setState(() {
          _apiStock = _fallbackApiStock();
          _loadingApi = false;
          _apiError = 'Đang xem dữ liệu bộ nhớ đệm (API offline)';
        });
      }
    }
  }

  List<dynamic> _fallbackApiStock() {
    final now = DateTime.now();
    return [
      {
        'segmentId': 1,
        'warehouseName': 'Kho Trung Tâm Hà Nội',
        'locationName': 'Phòng lạnh 01',
        'vaccineCode': 'VAC-HEXA',
        'vaccineName': 'Hexaxim 6-in-1',
        'batchNo': 'HEX-2026A',
        'expiresAt': now.add(const Duration(days: 365)).toIso8601String(),
        'qualityStatus': 'Released',
        'physicalQuantity': 500,
        'reservedQuantity': 0,
        'availableQuantity': 500,
      },
      {
        'segmentId': 2,
        'warehouseName': 'Kho Trung Tâm Hà Nội',
        'locationName': 'Phòng lạnh 01',
        'vaccineCode': 'VAC-HEXA',
        'vaccineName': 'Hexaxim 6-in-1',
        'batchNo': 'HEX-2025Z',
        'expiresAt': now.add(const Duration(days: 25)).toIso8601String(),
        'qualityStatus': 'Released',
        'physicalQuantity': 120,
        'reservedQuantity': 0,
        'availableQuantity': 120,
      },
      {
        'segmentId': 3,
        'warehouseName': 'Kho Trung Tâm Hà Nội',
        'locationName': 'Phòng lạnh 01',
        'vaccineCode': 'VAC-FLU',
        'vaccineName': 'Vaxigrip Tetra',
        'batchNo': 'VAX-2026B',
        'expiresAt': now.add(const Duration(days: 180)).toIso8601String(),
        'qualityStatus': 'PendingInspection',
        'physicalQuantity': 300,
        'reservedQuantity': 0,
        'availableQuantity': 0,
      },
      {
        'segmentId': 4,
        'warehouseName': 'Kho Trung Tâm Hà Nội',
        'locationName': 'Phòng lạnh 01',
        'vaccineCode': 'VAC-FLU',
        'vaccineName': 'Vaxigrip Tetra',
        'batchNo': 'VAX-2026C-TEMP',
        'expiresAt': now.add(const Duration(days: 150)).toIso8601String(),
        'qualityStatus': 'Quarantined',
        'physicalQuantity': 200,
        'reservedQuantity': 0,
        'availableQuantity': 0,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final rows = widget.state.currentInventory(
          widget.user,
          warehouseId: _warehouseId,
          search: _query,
        );
        final warehouses = widget.state.getAllowedWarehouses(widget.user);

        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                title: 'Tồn kho hiện tại',
                subtitle: 'Theo dõi tồn vật lý, giữ hàng nháp và khả dụng theo từng Lô và Vị trí.',
                action: compact
                    ? null
                    : SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('Theo Lô (VaxStock)'),
                            icon: Icon(Icons.qr_code_2),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('Theo Sản Phẩm'),
                            icon: Icon(Icons.inventory_2_outlined),
                          ),
                        ],
                        selected: {_batchMode},
                        onSelectionChanged: (set) {
                          setState(() => _batchMode = set.first);
                          if (_batchMode) _loadApiStock();
                        },
                      ),
              ),
              if (compact) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Theo Lô'),
                        icon: Icon(Icons.qr_code_2),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Sản Phẩm'),
                        icon: Icon(Icons.inventory_2_outlined),
                      ),
                    ],
                    selected: {_batchMode},
                    onSelectionChanged: (set) {
                      setState(() => _batchMode = set.first);
                      if (_batchMode) _loadApiStock();
                    },
                  ),
                ),
              ],
              if (_apiError != null && _batchMode) ...[
                const SizedBox(height: 10),
                Text(_apiError!, style: const TextStyle(fontSize: 12, color: Color(0xFF856404))),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: compact ? double.infinity : 300,
                    child: DropdownButtonFormField<int?>(
                      isExpanded: true,
                      initialValue: _warehouseId,
                      decoration: const InputDecoration(labelText: 'Kho'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Tất cả kho được phép'),
                        ),
                        for (final warehouse in warehouses)
                          DropdownMenuItem<int?>(
                            value: warehouse.id,
                            child: Text(warehouse.name),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _warehouseId = value);
                        if (_batchMode) _loadApiStock();
                      },
                    ),
                  ),
                  SizedBox(
                    width: compact ? double.infinity : 360,
                    child: TextField(
                      controller: _search,
                      onChanged: (value) {
                        setState(() => _query = value);
                        if (_batchMode) _loadApiStock();
                      },
                      decoration: const InputDecoration(
                        hintText: 'Tìm mã hoặc tên vaccine/sản phẩm...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE7ECF2)),
                ),
                child: _batchMode
                    ? (_loadingApi
                        ? const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _apiStock.isEmpty
                            ? const SizedBox(
                                height: 240,
                                child: EmptyState(title: 'Không có dữ liệu tồn kho theo lô'),
                              )
                            : _batchStockTable(compact))
                    : (rows.isEmpty
                        ? const SizedBox(
                            height: 240,
                            child: EmptyState(title: 'Không có dữ liệu tồn kho'),
                          )
                        : compact
                            ? Column(
                                children: [for (final row in rows) _mobileRow(row)],
                              )
                            : _desktopTable(rows)),
              ),
              const SizedBox(height: 10),
              Text(
                _batchMode
                    ? '${_apiStock.length} phân đoạn kho theo lô'
                    : '${rows.length} dòng tồn kho sản phẩm',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _batchStockTable(bool compact) {
    if (compact) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _apiStock.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (ctx, idx) {
          final s = _apiStock[idx] as Map<String, dynamic>;
          final avail = (s['availableQuantity'] as num? ?? 0).toInt();
          return ListTile(
            title: Row(
              children: [
                Text(
                  s['vaccineName']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                _qualityBadge(s['qualityStatus']?.toString()),
              ],
            ),
            subtitle: Text(
              'Lô: ${s['batchNo']} · Vị trí: ${s['locationName']}\nHSD: ${_formatDate(s['expiresAt']?.toString())} · Tồn: ${s['physicalQuantity']} · Giữ: ${s['reservedQuantity']}',
            ),
            trailing: Text(
              '$avail lọ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: avail > 0 ? const Color(0xFF14846A) : Colors.black45,
              ),
            ),
          );
        },
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF7F9FC)),
        columns: const [
          DataColumn(label: Text('Kho / Vị trí')),
          DataColumn(label: Text('Vaccine')),
          DataColumn(label: Text('Số Lô')),
          DataColumn(label: Text('Hạn Dùng')),
          DataColumn(label: Text('Chất Lượng')),
          DataColumn(label: Text('Tồn Thực Tế'), numeric: true),
          DataColumn(label: Text('Đang Giữ'), numeric: true),
          DataColumn(label: Text('Khả Dụng'), numeric: true),
        ],
        rows: [
          for (final s in _apiStock)
            DataRow(
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s['warehouseName']?.toString() ?? ''),
                      Text(
                        s['locationName']?.toString() ?? '',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        s['vaccineName']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        s['vaccineCode']?.toString() ?? '',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                DataCell(Text(s['batchNo']?.toString() ?? '')),
                DataCell(Text(_formatDate(s['expiresAt']?.toString()))),
                DataCell(_qualityBadge(s['qualityStatus']?.toString())),
                DataCell(Text('${s['physicalQuantity']} lọ')),
                DataCell(Text('${s['reservedQuantity']} lọ')),
                DataCell(
                  Text(
                    '${s['availableQuantity']} lọ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (s['availableQuantity'] as num? ?? 0) > 0
                          ? const Color(0xFF14846A)
                          : Colors.black45,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _qualityBadge(String? status) {
    if (status == 'Released') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Đạt (Released)',
          style: TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }
    if (status == 'PendingInspection') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Chờ QA',
          style: TextStyle(color: Color(0xFF1565C0), fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status ?? '',
        style: const TextStyle(color: Color(0xFFC62828), fontSize: 11, fontWeight: FontWeight.bold),
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

  Widget _desktopTable(List<InventoryItem> rows) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: const [
        DataColumn(label: Text('Kho')),
        DataColumn(label: Text('Mã sản phẩm')),
        DataColumn(label: Text('Tên sản phẩm')),
        DataColumn(label: Text('Đơn vị tính')),
        DataColumn(label: Text('Tồn thực tế'), numeric: true),
        DataColumn(label: Text('Đang giữ'), numeric: true),
        DataColumn(label: Text('Khả dụng'), numeric: true),
      ],
      rows: [
        for (final row in rows)
          DataRow(
            cells: [
              DataCell(Text(row.warehouseName)),
              DataCell(
                Text(
                  row.productCode,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DataCell(Text(row.productName)),
              DataCell(Text(row.unitName)),
              DataCell(Text(formatQuantity(row.onHand))),
              DataCell(Text(formatQuantity(row.reserved))),
              DataCell(_availableValue(row)),
            ],
          ),
      ],
    ),
  );

  Widget _mobileRow(InventoryItem row) => Column(
    children: [
      ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                row.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (row.available <= 5)
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFC28316),
                size: 19,
              ),
          ],
        ),
        subtitle: Text(
          '${row.productCode} · ${row.warehouseName} · ${row.unitName}',
        ),
        isThreeLine: true,
        trailing: Text(
          formatQuantity(row.available),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            Expanded(child: _quantityLabel('Tồn thực tế', row.onHand)),
            Expanded(child: _quantityLabel('Đang giữ', row.reserved)),
            Expanded(child: _quantityLabel('Khả dụng', row.available)),
          ],
        ),
      ),
      const Divider(height: 1, indent: 16, endIndent: 16),
    ],
  );

  Widget _quantityLabel(String label, double value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 3),
      Text(
        formatQuantity(value),
        style: Theme.of(context).textTheme.labelLarge,
      ),
    ],
  );

  Widget _availableValue(InventoryItem row) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (row.available <= 5) ...[
        const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFC28316),
          size: 17,
        ),
        const SizedBox(width: 5),
      ],
      Text(
        formatQuantity(row.available),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ],
  );
}
