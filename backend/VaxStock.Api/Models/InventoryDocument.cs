namespace VaxStock.Api.Models;

public static class DocumentTypes
{
    public const string Receipt = "Receipt"; // Nhập kho
    public const string Issue = "Issue";     // Xuất kho
}

public static class DocumentStatuses
{
    public const string Draft = "Draft";         // Phiếu nháp (phiếu xuất nháp sẽ giữ hàng)
    public const string Posted = "Posted";       // Đã ghi sổ, trừ/cộng tồn kho vật lý
    public const string Cancelled = "Cancelled"; // Đã hủy (giải phóng giữ hàng nếu có)
}

public class InventoryDocument
{
    public int Id { get; set; }
    public required string DocNo { get; set; }
    public required string DocumentType { get; set; } // Receipt, Issue
    public string Status { get; set; } = DocumentStatuses.Draft;

    public int WarehouseId { get; set; }
    public Warehouse? Warehouse { get; set; }

    public int PartnerId { get; set; } // Nhà cung cấp hoặc Đơn vị nhận
    public Partner? Partner { get; set; }

    public int? TradeShipmentId { get; set; }
    public TradeShipment? TradeShipment { get; set; }

    public DateTime DocumentDate { get; set; } = DateTime.UtcNow;
    public DateTime? ExpectedDate { get; set; }

    public string? Note { get; set; }

    public int CreatedByUserId { get; set; }
    public User? CreatedByUser { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public int? PostedByUserId { get; set; }
    public User? PostedByUser { get; set; }
    public DateTime? PostedAt { get; set; }

    public List<InventoryDocumentDetail> Details { get; set; } = [];
}

public class InventoryDocumentDetail
{
    public int Id { get; set; }
    public int DocumentId { get; set; }
    public InventoryDocument? Document { get; set; }

    public int VaccineId { get; set; }
    public Vaccine? Vaccine { get; set; }

    public int? BatchId { get; set; }
    public VaccineBatch? Batch { get; set; }

    public required string BatchNo { get; set; }
    public DateTime ExpiresAt { get; set; }

    public int LocationId { get; set; }
    public StorageLocation? Location { get; set; }

    public int Quantity { get; set; } // Số lượng lọ
    public decimal UnitPrice { get; set; } = 0;

    // Phục vụ FEFO xuất kho
    public int? FEFOSuggestedBatchId { get; set; }
    public string? OverrideReason { get; set; } // Lý do chọn lô khác nếu không dùng lô gợi ý
}
