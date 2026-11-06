namespace VaxStock.Api.Models;

public class QualityDecision
{
    public int Id { get; set; }
    public int BatchId { get; set; }
    public VaccineBatch? Batch { get; set; }
    public int? SegmentId { get; set; }
    public StockSegment? Segment { get; set; }

    public required string PreviousStatus { get; set; }
    public required string NewStatus { get; set; } // Released, Quarantined, Rejected
    public required string Reason { get; set; }
    public string? Note { get; set; }

    public int DecidedByUserId { get; set; }
    public User? DecidedByUser { get; set; }
    public DateTime DecidedAt { get; set; } = DateTime.UtcNow;
}

public static class ShipmentStatuses
{
    public const string Draft = "Draft";
    public const string InTransit = "InTransit";
    public const string Arrived = "Arrived";
    public const string Completed = "Completed";
    public const string Cancelled = "Cancelled";
}

public class TradeShipment
{
    public int Id { get; set; }
    public required string ShipmentNo { get; set; }
    public required string ShipmentType { get; set; } // Import (Nhập khẩu), Export (Xuất khẩu)
    public int PartnerId { get; set; }
    public Partner? Partner { get; set; }
    public string? Country { get; set; }
    public DateTime ExpectedDate { get; set; }
    public DateTime? ActualDate { get; set; }
    public string Status { get; set; } = ShipmentStatuses.Draft;
    public string? CustomsDeclarationNo { get; set; } // Tờ khai hải quan tham chiếu
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public List<InventoryDocument> LinkedDocuments { get; set; } = [];
}
