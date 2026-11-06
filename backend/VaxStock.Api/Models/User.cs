namespace VaxStock.Api.Models;

public static class UserRoles
{
    public const string Admin = "Admin";
    public const string WarehouseStaff = "WarehouseStaff";
    public const string QualityManager = "QualityManager";
}

public class User
{
    public int Id { get; set; }
    public required string Username { get; set; }
    public required string PasswordHash { get; set; }
    public required string FullName { get; set; }
    public required string Role { get; set; } // Admin, WarehouseStaff, QualityManager
    public int? WarehouseId { get; set; }     // Nhân viên thuộc kho nào
    public Warehouse? Warehouse { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
