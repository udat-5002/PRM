import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/data/local/local_data_store.dart';
import 'package:warehouse/domain/models/warehouse_app_data.dart';
import 'package:warehouse/domain/services/warehouse_app_state.dart';
import 'package:warehouse/features/batches/batch_list_page.dart';
import 'package:warehouse/features/inventory/inventory_page.dart';
import 'package:warehouse/features/quality/quality_page.dart';
import 'package:warehouse/features/trade_shipments/trade_shipments_page.dart';

class _FakeStore implements LocalDataStore {
  String? json;
  @override
  Future<String?> loadJson() async => json;
  @override
  Future<void> saveJson(String value) async => json = value;
}

void main() {
  test('AppUser parses backend role and warehouse metadata correctly', () {
    final staffJson = {
      'id': 2,
      'username': 'staff_kho1',
      'password': '',
      'fullName': 'Nguyễn Văn Kho',
      'role': 'WarehouseStaff',
      'warehouseId': 1,
      'warehouseName': 'Kho Trung Tâm Hà Nội',
      'token': 'mock-jwt-token',
    };

    final user = AppUser.fromJson(staffJson);
    expect(user.role, UserRole.warehouseStaff);
    expect(user.warehouseId, 1);
    expect(user.warehouseName, 'Kho Trung Tâm Hà Nội');
    expect(user.token, 'mock-jwt-token');

    final qaJson = {
      'id': 3,
      'username': 'qa_manager',
      'password': '',
      'fullName': 'Trần Thị QA',
      'role': 'QualityManager',
    };
    final qaUser = AppUser.fromJson(qaJson);
    expect(qaUser.role, UserRole.qualityManager);
  });

  testWidgets('BatchListPage renders batch search, filter chips and table', (tester) async {
    final store = _FakeStore();
    final state = await WarehouseAppState.create(store: store);
    const user = AppUser(
      id: 1,
      username: 'admin',
      password: '',
      fullName: 'Admin',
      role: UserRole.admin,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatchListPage(state: state, user: user),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quản lý Lô Vaccine & Hạn Dùng'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Còn hạn'), findsOneWidget);
    expect(find.text('Cận hạn (<60 ngày)'), findsOneWidget);
    expect(find.text('Đã hết hạn'), findsOneWidget);
  });

  testWidgets('QualityPage renders pending inspection and decision tabs', (tester) async {
    final store = _FakeStore();
    final state = await WarehouseAppState.create(store: store);
    const user = AppUser(
      id: 3,
      username: 'qa_manager',
      password: '',
      fullName: 'QA Manager',
      role: UserRole.qualityManager,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QualityPage(state: state, user: user),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kiểm Định & Quản Lý Chất Lượng QA'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
  });

  testWidgets('TradeShipmentsPage renders shipment filters and list', (tester) async {
    final store = _FakeStore();
    final state = await WarehouseAppState.create(store: store);
    const user = AppUser(
      id: 1,
      username: 'admin',
      password: '',
      fullName: 'Admin',
      role: UserRole.admin,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TradeShipmentsPage(state: state, user: user),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hồ Sơ Xuất / Nhập Khẩu Quốc Tế'), findsOneWidget);
    expect(find.text('Tạo hồ sơ mới'), findsOneWidget);
    expect(find.text('Nhập khẩu (Import)'), findsOneWidget);
    expect(find.text('Xuất khẩu (Export)'), findsOneWidget);
  });

  testWidgets('InventoryPage supports batch mode toggle', (tester) async {
    final store = _FakeStore();
    final state = await WarehouseAppState.create(store: store);
    const user = AppUser(
      id: 1,
      username: 'admin',
      password: '',
      fullName: 'Admin',
      role: UserRole.admin,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InventoryPage(state: state, user: user),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tồn kho hiện tại'), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsWidgets);
  });

  test('staff_kho1 and qa_manager can access allowed warehouses without session error', () async {
    final store = _FakeStore();
    final state = await WarehouseAppState.create(store: store);

    // Test staff
    expect(await state.login('staff_kho1', 'staff123'), isTrue);
    final staff = state.currentUser!;
    expect(staff.role, UserRole.warehouseStaff);
    final staffWhs = state.getAllowedWarehouses(staff);
    expect(staffWhs, isNotEmpty);

    // Test QA
    expect(await state.login('qa_manager', 'qa123'), isTrue);
    final qa = state.currentUser!;
    expect(qa.role, UserRole.qualityManager);
    final qaWhs = state.getAllowedWarehouses(qa);
    expect(qaWhs, isNotEmpty);
  });
}
