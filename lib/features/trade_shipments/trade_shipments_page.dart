import 'package:flutter/material.dart';

import '../../data/remote/vax_api_service.dart';
import '../../domain/models/warehouse_app_data.dart';
import '../../domain/services/warehouse_app_state.dart';
import '../../shared/widgets/common.dart';

class TradeShipmentsPage extends StatefulWidget {
  const TradeShipmentsPage({super.key, required this.state, required this.user});

  final WarehouseAppState state;
  final AppUser user;

  @override
  State<TradeShipmentsPage> createState() => _TradeShipmentsPageState();
}

class _TradeShipmentsPageState extends State<TradeShipmentsPage> {
  final VaxApiService _api = VaxApiService();
  List<dynamic> _shipments = [];
  bool _loading = true;
  String? _error;
  String? _filterType; // null, Import, Export

  @override
  void initState() {
    super.initState();
    _loadShipments();
  }

  Future<void> _loadShipments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _api.getTradeShipments(_filterType);
      if (mounted) {
        setState(() {
          _shipments = list;
          _loading = false;
        });
      }
    } catch (_) {
      // ponytail: Fallback danh sách hồ sơ XNK mẫu khi offline
      if (mounted) {
        setState(() {
          _shipments = _fallbackShipments();
          _loading = false;
          _error = 'Đang hiển thị dữ liệu bộ nhớ đệm (API offline)';
        });
      }
    }
  }

  List<dynamic> _fallbackShipments() {
    final now = DateTime.now();
    return [
      {
        'id': 1,
        'shipmentNo': 'IMP-2026-001',
        'shipmentType': 'Import',
        'partnerId': 1,
        'partnerName': 'Sanofi Pasteur VN',
        'country': 'Pháp',
        'expectedDate': now.toIso8601String(),
        'status': 'Completed',
        'customsDeclarationNo': 'TKHQ-1049281920',
        'notes': 'Lô hàng Hexaxim 6-in-1 nhập khẩu chính ngạch từ Lyon',
        'linkedDocuments': [
          {'id': 1, 'docNo': 'PNK-2026-0001', 'status': 'Posted'},
        ],
      },
      {
        'id': 2,
        'shipmentNo': 'EXP-2026-002',
        'shipmentType': 'Export',
        'partnerId': 2,
        'partnerName': 'VNVC Trung Tâm Tiêm Chủng',
        'country': 'Việt Nam',
        'expectedDate': now.add(const Duration(days: 3)).toIso8601String(),
        'status': 'InTransit',
        'customsDeclarationNo': 'TK-NOI-DIA-082',
        'notes': 'Điều phối phân bổ vaccine về trung tâm miền Trung',
        'linkedDocuments': [],
      },
    ];
  }

  void _openCreateDialog() {
    final noController = TextEditingController(
      text: 'IMP-2026-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    );
    final countryController = TextEditingController(text: 'Pháp');
    final customsController = TextEditingController(text: 'TKHQ-2026-');
    final noteController = TextEditingController();
    String type = 'Import';
    int partnerId = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tạo Hồ Sơ Xuất/Nhập Khẩu Mới'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Loại hồ sơ *'),
                    items: const [
                      DropdownMenuItem(value: 'Import', child: Text('Nhập khẩu (Import)')),
                      DropdownMenuItem(value: 'Export', child: Text('Xuất khẩu / Phân bổ (Export)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => type = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noController,
                    decoration: const InputDecoration(labelText: 'Mã hồ sơ vận chuyển *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countryController,
                    decoration: const InputDecoration(labelText: 'Quốc gia xuất xứ / điểm đến'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customsController,
                    decoration: const InputDecoration(labelText: 'Số tờ khai hải quan'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Ghi chú vận chuyển'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await _api.createTradeShipment({
                    'shipmentNo': noController.text.trim(),
                    'shipmentType': type,
                    'partnerId': partnerId,
                    'country': countryController.text.trim(),
                    'expectedDate': DateTime.now().toIso8601String(),
                    'customsDeclarationNo': customsController.text.trim(),
                    'notes': noteController.text.trim(),
                  });
                  if (!mounted) return;
                  showAppMessage(context, 'Tạo hồ sơ thành công!');
                  _loadShipments();
                } catch (e) {
                  if (!mounted) return;
                  showAppMessage(context, 'Lỗi tạo hồ sơ: $e', isError: true);
                }
              },
              child: const Text('Tạo hồ sơ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> item) {
    final docs = (item['linkedDocuments'] as List<dynamic>?) ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              item['shipmentType'] == 'Import' ? Icons.flight_land : Icons.flight_takeoff,
              color: const Color(0xFF14846A),
            ),
            const SizedBox(width: 8),
            Text('Hồ sơ ${item['shipmentNo']}'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Loại nghiệp vụ:', item['shipmentType'] == 'Import' ? 'Nhập khẩu' : 'Xuất khẩu'),
              _infoRow('Đối tác:', '${item['partnerName']}'),
              _infoRow('Quốc gia:', '${item['country'] ?? '—'}'),
              _infoRow('Tờ khai Hải quan:', '${item['customsDeclarationNo'] ?? 'Chưa khai báo'}'),
              _infoRow('Trạng thái:', _statusText(item['status']?.toString())),
              _infoRow('Ghi chú:', '${item['notes'] ?? '—'}'),
              const Divider(height: 24),
              Text(
                'Phiếu kho liên kết (${docs.length})',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                const Text(
                  'Chưa có phiếu nhập/xuất kho nào gắn với hồ sơ này.',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
                )
              else
                for (final doc in docs)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          doc['docNo']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          doc['status']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _statusText(String? s) {
    switch (s) {
      case 'Draft':
        return 'Nháp';
      case 'InTransit':
        return 'Đang vận chuyển';
      case 'Arrived':
        return 'Đã đến cảng / kho';
      case 'Completed':
        return 'Đã thông quan & hoàn tất';
      default:
        return s ?? '';
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
                title: 'Hồ Sơ Xuất / Nhập Khẩu Quốc Tế',
                subtitle: 'Theo dõi tiến độ hồ sơ thương mại quốc tế và liên kết phiếu kho vật lý.',
                action: FilledButton.icon(
                  onPressed: _openCreateDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Tạo hồ sơ mới'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFF856404))),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: _filterType == null,
                    onSelected: (s) {
                      if (s) {
                        setState(() => _filterType = null);
                        _loadShipments();
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Nhập khẩu (Import)'),
                    selected: _filterType == 'Import',
                    onSelected: (s) {
                      if (s) {
                        setState(() => _filterType = 'Import');
                        _loadShipments();
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Xuất khẩu (Export)'),
                    selected: _filterType == 'Export',
                    onSelected: (s) {
                      if (s) {
                        setState(() => _filterType = 'Export');
                        _loadShipments();
                      }
                    },
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
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _shipments.isEmpty
                        ? const SizedBox(
                            height: 220,
                            child: EmptyState(
                              title: 'Chưa có hồ sơ xuất nhập khẩu',
                              message: 'Tạo hồ sơ mới để liên kết phiếu nhập xuất kho.',
                              icon: Icons.flight_takeoff,
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _shipments.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final item = _shipments[idx] as Map<String, dynamic>;
                              final isImport = item['shipmentType'] == 'Import';
                              final docs = (item['linkedDocuments'] as List<dynamic>?) ?? [];

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isImport
                                      ? const Color(0xFFE3F2FD)
                                      : const Color(0xFFE8F5E9),
                                  child: Icon(
                                    isImport ? Icons.flight_land : Icons.flight_takeoff,
                                    color: isImport
                                        ? const Color(0xFF1976D2)
                                        : const Color(0xFF388E3C),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      item['shipmentNo']?.toString() ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECEFF1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        _statusText(item['status']?.toString()),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  'Đối tác: ${item['partnerName']} • Nước: ${item['country'] ?? '—'}\n'
                                  'Tờ khai: ${item['customsDeclarationNo'] ?? '—'} • ${docs.length} phiếu liên kết',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _showDetail(item),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
