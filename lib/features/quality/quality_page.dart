import 'package:flutter/material.dart';

import '../../data/remote/vax_api_service.dart';
import '../../domain/models/warehouse_app_data.dart';
import '../../domain/services/warehouse_app_state.dart';
import '../../shared/widgets/common.dart';

class QualityPage extends StatefulWidget {
  const QualityPage({super.key, required this.state, required this.user});

  final WarehouseAppState state;
  final AppUser user;

  @override
  State<QualityPage> createState() => _QualityPageState();
}

class _QualityPageState extends State<QualityPage> with SingleTickerProviderStateMixin {
  final VaxApiService _api = VaxApiService();
  late TabController _tabController;

  List<dynamic> _pendingList = [];
  List<dynamic> _decisionsList = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pending = await _api.getPendingQuality(widget.user.warehouseId);
      final decisions = await _api.getQualityDecisions();
      if (mounted) {
        setState(() {
          _pendingList = pending;
          _decisionsList = decisions;
          _loading = false;
        });
      }
    } catch (_) {
      // ponytail: Fallback mẫu khi server API chưa online
      if (mounted) {
        setState(() {
          _pendingList = _fallbackPending();
          _decisionsList = _fallbackDecisions();
          _loading = false;
          _error = 'Đang hiển thị dữ liệu bộ nhớ đệm (API offline)';
        });
      }
    }
  }

  List<dynamic> _fallbackPending() {
    final now = DateTime.now();
    return [
      {
        'segmentId': 3,
        'batchId': 3,
        'warehouseId': 1,
        'warehouseName': 'Kho Trung Tâm Hà Nội',
        'locationName': 'Phòng lạnh 01',
        'vaccineName': 'Vaxigrip Tetra',
        'batchNo': 'VAX-2026B',
        'qualityStatus': 'PendingInspection',
        'quantity': 300,
        'expiresAt': now.add(const Duration(days: 180)).toIso8601String(),
        'referenceDoc': 'GPLH-2026-FR-112',
      },
      {
        'segmentId': 4,
        'batchId': 4,
        'warehouseId': 1,
        'warehouseName': 'Kho Trung Tâm Hà Nội',
        'locationName': 'Phòng lạnh 01',
        'vaccineName': 'Vaxigrip Tetra',
        'batchNo': 'VAX-2026C-TEMP',
        'qualityStatus': 'Quarantined',
        'quantity': 200,
        'expiresAt': now.add(const Duration(days: 150)).toIso8601String(),
        'referenceDoc': 'GPLH-2026-FR-115',
      },
    ];
  }

  List<dynamic> _fallbackDecisions() {
    return [
      {
        'id': 1,
        'batchNo': 'VAX-2026C-TEMP',
        'vaccineName': 'Vaxigrip Tetra',
        'previousStatus': 'PendingInspection',
        'newStatus': 'Quarantined',
        'reason': 'Nhiệt độ cảm biến vượt ngưỡng 9.2°C trong 45 phút lúc vận chuyển',
        'decidedBy': 'qa_manager',
        'decidedAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
    ];
  }

  void _openDecisionDialog(Map<String, dynamic> item, String actionType) {
    final reasonController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String title;
    Color buttonColor;
    String newStatus;

    if (actionType == 'release') {
      title = 'Giải Phóng (Released) Lô ${item['batchNo']}';
      buttonColor = const Color(0xFF14846A);
      newStatus = 'Released';
      reasonController.text = 'Kiểm định cảm quan, hồ sơ nhiệt độ đạt yêu cầu xuất kho';
    } else if (actionType == 'quarantine') {
      title = 'Cách Ly (Quarantined) Lô ${item['batchNo']}';
      buttonColor = const Color(0xFFE65100);
      newStatus = 'Quarantined';
      reasonController.text = 'Nghi ngờ sự cố nhiệt độ bảo quản trong kho';
    } else {
      title = 'Từ Chối (Rejected) Lô ${item['batchNo']}';
      buttonColor = const Color(0xFFC62828);
      newStatus = 'Rejected';
      reasonController.text = 'Hàng hỏng vỡ / vi phạm chỉ thị đông băng';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vaccine: ${item['vaccineName']}'),
                Text('Kho: ${item['warehouseName']} - ${item['locationName']}'),
                Text('Số lượng: ${item['quantity']} lọ'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Lý do quyết định *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Vui lòng nhập lý do' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú thêm',
                    border: OutlineInputBorder(),
                  ),
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
            style: FilledButton.styleFrom(backgroundColor: buttonColor),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();

              try {
                await _api.applyQualityDecision(
                  batchId: item['batchId'] as int,
                  segmentId: item['segmentId'] as int?,
                  newStatus: newStatus,
                  reason: reasonController.text.trim(),
                  note: noteController.text.trim(),
                );
                if (!mounted) return;
                showAppMessage(context, 'Cập nhật quyết định chất lượng thành công!');
                _loadData();
              } catch (e) {
                if (!mounted) return;
                showAppMessage(context, 'Lỗi cập nhật chất lượng: $e', isError: true);
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 780;
        return Padding(
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                title: 'Kiểm Định & Quản Lý Chất Lượng QA',
                subtitle: 'Kiểm soát hàng chờ giải phóng, áp dụng cách ly và bảo vệ chuỗi lạnh.',
                action: IconButton.filledTonal(
                  tooltip: 'Tải lại',
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF856404)),
                ),
              ],
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.pending_actions_rounded),
                    text: 'Hàng Chờ Duyệt / Cách Ly (${_pendingList.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.history_edu_rounded),
                    text: 'Nhật Ký Quyết Định QA (${_decisionsList.length})',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPendingTab(compact),
                    _buildDecisionsTab(compact),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingTab(bool compact) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_pendingList.isEmpty) {
      return const EmptyState(
        title: 'Không có lô hàng cần kiểm định',
        message: 'Tất cả các lô hàng đều đã được giải phóng hoặc chưa có đợt nhập mới.',
        icon: Icons.check_circle_outline,
      );
    }

    return ListView.separated(
      itemCount: _pendingList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final item = _pendingList[idx] as Map<String, dynamic>;
        final isQuarantined = item['qualityStatus'] == 'Quarantined';

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isQuarantined ? const Color(0xFFFFCC80) : const Color(0xFFE7ECF2),
              width: isQuarantined ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Lô: ${item['batchNo']}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    _statusBadge(item['qualityStatus']?.toString()),
                    const Spacer(),
                    Text(
                      '${item['quantity']} lọ',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${item['vaccineName']} • Vị trí: ${item['warehouseName']} (${item['locationName']})',
                  style: const TextStyle(color: Colors.black87),
                ),
                Text(
                  'Hồ sơ / Giấy phép: ${item['referenceDoc'] ?? 'Chưa có'}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const Divider(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF14846A),
                      ),
                      onPressed: () => _openDecisionDialog(item, 'release'),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Giải phóng (Cho phép xuất)'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE65100),
                        side: const BorderSide(color: Color(0xFFE65100)),
                      ),
                      onPressed: () => _openDecisionDialog(item, 'quarantine'),
                      icon: const Icon(Icons.warning_amber_rounded, size: 18),
                      label: const Text('Cách ly lô hàng'),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                      ),
                      onPressed: () => _openDecisionDialog(item, 'reject'),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Từ chối / Hủy'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDecisionsTab(bool compact) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_decisionsList.isEmpty) {
      return const EmptyState(
        title: 'Chưa có nhật ký quyết định QA',
        message: 'Lịch sử giải phóng và cách ly hàng sẽ được lưu tại đây.',
        icon: Icons.history,
      );
    }

    return ListView.separated(
      itemCount: _decisionsList.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final d = _decisionsList[idx] as Map<String, dynamic>;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: d['newStatus'] == 'Released'
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFFEBEE),
            child: Icon(
              d['newStatus'] == 'Released'
                  ? Icons.check
                  : Icons.shield_outlined,
              color: d['newStatus'] == 'Released'
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFC62828),
            ),
          ),
          title: Text(
            'Lô ${d['batchNo']}: ${d['previousStatus']} ➔ ${d['newStatus']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Lý do: ${d['reason']}\nNgười duyệt: ${d['decidedBy']} • ${_formatIso(d['decidedAt']?.toString())}',
          ),
          isThreeLine: true,
        );
      },
    );
  }

  Widget _statusBadge(String? status) {
    if (status == 'PendingInspection') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Chờ kiểm định',
          style: TextStyle(color: Color(0xFF1565C0), fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }
    if (status == 'Quarantined') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Đang cách ly',
          style: TextStyle(color: Color(0xFFE65100), fontSize: 11, fontWeight: FontWeight.bold),
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
        status ?? '',
        style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatIso(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
