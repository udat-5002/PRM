import '../models/warehouse_app_data.dart';
import 'domain_exception.dart';

class WarehousePermissionService {
  const WarehousePermissionService();

  bool canAccessWarehouse(
    AppUser user,
    int warehouseId,
    List<WarehouseUserAssignment> assignments,
  ) {
    if (user.role == UserRole.admin || user.role == UserRole.qualityManager) {
      return true;
    }
    if (user.warehouseId != null && user.warehouseId == warehouseId) {
      return true;
    }
    return assignments.any(
      (item) => item.userId == user.id && item.warehouseId == warehouseId,
    );
  }

  List<Warehouse> allowedWarehouses(
    AppUser user,
    List<Warehouse> warehouses,
    List<WarehouseUserAssignment> assignments,
  ) {
    if (user.role == UserRole.admin || user.role == UserRole.qualityManager) {
      return List.unmodifiable(warehouses);
    }
    final allowedIds = assignments
        .where((item) => item.userId == user.id)
        .map((item) => item.warehouseId)
        .toSet();
    if (user.warehouseId != null) {
      allowedIds.add(user.warehouseId!);
    }
    return warehouses
        .where((warehouse) => allowedIds.contains(warehouse.id))
        .toList();
  }

  void requireAccess(
    AppUser user,
    int warehouseId,
    List<WarehouseUserAssignment> assignments,
  ) {
    if (!canAccessWarehouse(user, warehouseId, assignments)) {
      throw const DomainException('Bạn không có quyền truy cập kho này.');
    }
  }

  void requireAdmin(AppUser user) {
    if (user.role != UserRole.admin) {
      throw const DomainException(
        'Chỉ quản trị viên mới được thực hiện thao tác này.',
      );
    }
  }
}
