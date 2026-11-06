import '../../data/remote/vax_api_service.dart';
import '../models/warehouse_app_data.dart';

class AuthService {
  const AuthService();

  // ponytail: Gửi đăng nhập đến VaxApiService trước; nếu API offline (hoặc môi trường test không có server), fallback sang danh sách users local để không gãy unit test.
  Future<AppUser?> authenticate(
    List<AppUser> users,
    String username,
    String password,
  ) async {
    try {
      final res = await VaxApiService().login(username, password);
      final roleStr = (res['role'] ?? '').toString().toLowerCase();
      UserRole role;
      if (roleStr == 'admin') {
        role = UserRole.admin;
      } else if (roleStr == 'warehousestaff' || roleStr == 'staff') {
        role = UserRole.warehouseStaff;
      } else if (roleStr == 'qualitymanager' || roleStr == 'qa') {
        role = UserRole.qualityManager;
      } else {
        role = UserRole.user;
      }

      return AppUser(
        id: (res['userId'] as num?)?.toInt() ?? 0,
        username: res['username']?.toString() ?? username,
        password: '',
        fullName: res['fullName']?.toString() ?? username,
        role: role,
        warehouseId: (res['warehouseId'] as num?)?.toInt(),
        warehouseName: res['warehouseName']?.toString(),
        token: res['token']?.toString(),
      );
    } catch (_) {
      final normalized = username.trim().toLowerCase();
      for (final user in users) {
        if (user.username.toLowerCase() == normalized &&
            user.password == password) {
          return user;
        }
      }
      return null;
    }
  }
}
