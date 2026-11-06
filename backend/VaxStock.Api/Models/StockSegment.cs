namespace VaxStock.Api.Models;

public static class QualityStatuses
{
    public const string PendingInspection = "PendingInspection"; // Mới nhập, chờ kiểm tra
    public const string Released = "Released";                   // Đạt chất lượng, được phép xuất
    public const string Quarantined = "Quarantined";             // Cách ly do nghi ngờ / sự cố nhiệt độ
    public const string Rejected = "Rejected";                   // Không đạt, chuẩn bị hủy/trả
}

public class StockSegment
{
    public int Id { get; set; }
    public int WarehouseId { get; set; }
    public Warehouse? Warehouse { get; set; }
    public int LocationId { get; set; }
    public StorageLocation? Location { get; set; }
    public int BatchId { get; set; }
    public VaccineBatch? Batch { get; set; }

    public string QualityStatus { get; set; } = QualityStatuses.PendingInspection;
    public int Quantity { get; set; } = 0;         // Tồn vật lý thực tế (lọ)
    public int ReservedQuantity { get; set; } = 0; // Hàng giữ bởi phiếu xuất nháp (lọ)

    public DateTime LastUpdatedAt { get; set; } = DateTime.UtcNow;

    // Helper tính khả dụng
    public int GetAvailableQuantity(DateTime atDate)
    {
        if (QualityStatus != QualityStatuses.Released) return 0;
        if (Batch != null && Batch.ExpiresAt.Date <= atDate.Date) return 0;
        return Math.Max(0, Quantity - ReservedQuantity);
    }
}

public class StockMovement
{
    public int Id { get; set; }
    public required string MovementType { get; set; } // Receipt, Issue, Quarantine, Release, Disposal
    public int? DocumentId { get; set; }
    public int SegmentId { get; set; }
    public StockSegment? Segment { get; set; }
    public int BatchId { get; set; }
    public VaccineBatch? Batch { get; set; }
    public int WarehouseId { get; set; }
    public int LocationId { get; set; }
    public int QuantityChange { get; set; } // Dương nếu tăng, âm nếu giảm
    public required string QualityStatus { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public int CreatedByUserId { get; set; }
    public User? CreatedByUser { get; set; }
    public string? Note { get; set; }
}
