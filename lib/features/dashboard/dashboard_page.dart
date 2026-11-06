import 'package:flutter/material.dart';

import '../../data/remote/vax_api_service.dart';
import '../../domain/models/warehouse_app_data.dart';
import '../../domain/services/warehouse_app_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/common.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.state, required this.user});

  final WarehouseAppState state;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final warehouses = state.getAllowedWarehouses(user);
    final receipts = state.visibleReceipts(user);
    final issues = state.visibleIssues(user);
    final inventory = state.currentInventory(user);
    final metrics = <_MetricData>[
      _MetricData(
        'Kho được phân quyền',
        warehouses.length.toString(),
        Icons.warehouse_outlined,
        const Color(0xFF2873C8),
      ),
      _MetricData(
        'Sản phẩm',
        state.data.products.length.toString(),
        Icons.inventory_2_outlined,
        const Color(0xFF6B58C8),
      ),
      _MetricData(
        'Phiếu nhập nháp',
        receipts
            .where((doc) => doc.status == DocumentStatus.draft)
            .length
            .toString(),
        Icons.move_to_inbox_outlined,
        const Color(0xFFC28316),
      ),
      _MetricData(
        'Phiếu nhập đã Post',
        receipts
            .where((doc) => doc.status == DocumentStatus.posted)
            .length
            .toString(),
        Icons.inventory_outlined,
        const Color(0xFF14846A),
      ),
      _MetricData(
        'Phiếu xuất nháp',
        issues
            .where((doc) => doc.status == DocumentStatus.draft)
            .length
            .toString(),
        Icons.pending_actions_outlined,
        const Color(0xFFC28316),
      ),
      _MetricData(
        'Phiếu xuất đã Post',
        issues
            .where((doc) => doc.status == DocumentStatus.posted)
            .length
            .toString(),
        Icons.outbox_outlined,
        const Color(0xFF14846A),
      ),
      _MetricData(
        'Tồn thực tế',
        formatQuantity(
          inventory.fold<double>(0, (sum, row) => sum + row.onHand),
        ),
        Icons.inventory_2_rounded,
        const Color(0xFF2873C8),
      ),
      _MetricData(
        'Đang giữ',
        formatQuantity(
          inventory.fold<double>(0, (sum, row) => sum + row.reserved),
        ),
        Icons.lock_clock_outlined,
        const Color(0xFFC28316),
      ),
      _MetricData(
        'Khả dụng',
        formatQuantity(
          inventory.fold<double>(0, (sum, row) => sum + row.available),
        ),
        Icons.check_circle_outline,
        const Color(0xFF14846A),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1250
            ? 3
            : constraints.maxWidth >= 690
            ? 2
            : 1;
        final spacing = 14.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                title: 'Xin chào, ${user.fullName.split(' ').first}',
                subtitle: 'Tổng quan chuỗi cung ứng vaccine & kho bảo quản lạnh.',
              ),
              const SizedBox(height: 18),
              FutureBuilder<Map<String, dynamic>>(
                future: VaxApiService().getDashboardSummary(user.warehouseId),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (data == null) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: Color(0xFF15803D)),
                            const SizedBox(width: 8),
                            Text(
                              'Chỉ số VaxStock Cold-Chain & FEFO (Backend Trực Tuyến)',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: const Color(0xFF15803D),
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 14,
                          runSpacing: 10,
                          children: [
                            _vaxKpiBadge(
                              'Tổng vaccine',
                              '${data['totalVaccines']} loại',
                              const Color(0xFF0F766E),
                              const Color(0xFFCCFBF1),
                            ),
                            _vaxKpiBadge(
                              'Lọ tồn vật lý',
                              '${data['totalPhysicalVials']} lọ',
                              const Color(0xFF1D4ED8),
                              const Color(0xFFDBEAFE),
                            ),
                            _vaxKpiBadge(
                              'Khả dụng xuất FEFO',
                              '${data['totalAvailableVials']} lọ',
                              const Color(0xFF15803D),
                              const Color(0xFFDCFCE7),
                            ),
                            _vaxKpiBadge(
                              'Chờ QA duyệt',
                              '${data['pendingInspectionVials']} lọ',
                              const Color(0xFFB45309),
                              const Color(0xFFFEF3C7),
                            ),
                            _vaxKpiBadge(
                              'Đang cách ly',
                              '${data['quarantinedVials']} lọ',
                              const Color(0xFFB91C1C),
                              const Color(0xFFFEE2E2),
                            ),
                            _vaxKpiBadge(
                              'Lô cận date (<60d)',
                              '${data['nearExpiryBatchesCount']} lô',
                              const Color(0xFFC2410C),
                              const Color(0xFFFFEDD5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B7A72), Color(0xFF145B76)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bức tranh tồn kho',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${formatQuantity(inventory.fold<double>(0, (sum, row) => sum + row.available))} đơn vị hàng đang khả dụng',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Số liệu được tính trực tiếp từ các phiếu đã Post và phiếu xuất nháp.',
                            style: TextStyle(color: Color(0xFFD6EFEB)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.query_stats_rounded,
                      color: Colors.white70,
                      size: 42,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      width: width,
                      child: _MetricCard(metric: metric),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE7ECF2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kho trong phạm vi của bạn',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      for (final warehouse in warehouses)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.warehouse_outlined),
                          ),
                          title: Text(warehouse.name),
                          subtitle: Text(
                            warehouse.note.isEmpty
                                ? 'Được phép truy cập'
                                : warehouse.note,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      if (warehouses.isEmpty)
                        const EmptyState(title: 'Chưa được phân quyền kho'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _vaxKpiBadge(
    String label,
    String value,
    Color textCol,
    Color bgCol,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textCol.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textCol,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: metric.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(metric.icon, color: metric.color, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metric.value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
