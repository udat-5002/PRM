namespace VaxStock.Api.DTOs;

public record LoginRequest(string Username, string Password);

public record LoginResponse(
    string Token,
    int UserId,
    string Username,
    string FullName,
    string Role,
    int? WarehouseId,
    string? WarehouseName
);

public record StockItemDto(
    int SegmentId,
    int WarehouseId,
    string WarehouseName,
    int LocationId,
    string LocationName,
    int VaccineId,
    string VaccineCode,
    string VaccineName,
    int BatchId,
    string BatchNo,
    DateTime ExpiresAt,
    string QualityStatus,
    int PhysicalQuantity,
    int ReservedQuantity,
    int AvailableQuantity
);

public record DashboardSummaryDto(
    int TotalVaccines,
    int TotalPhysicalVials,
    int TotalAvailableVials,
    int PendingInspectionVials,
    int QuarantinedVials,
    int NearExpiryBatchesCount,
    int ExpiredBatchesCount
);

public record FefoAllocationItem(
    int BatchId,
    string BatchNo,
    int LocationId,
    string LocationName,
    DateTime ExpiresAt,
    int AvailableQuantity,
    int AllocatedQuantity
);

public record FefoSuggestionResult(
    int VaccineId,
    string VaccineName,
    int RequestedQuantity,
    int TotalAllocatedQuantity,
    bool IsFullyFulfilled,
    string? WarningMessage,
    List<FefoAllocationItem> Allocations
);

public record CreateReceiptDetailRequest(
    int VaccineId,
    string BatchNo,
    DateTime? ManufacturedAt,
    DateTime ExpiresAt,
    int LocationId,
    int Quantity,
    decimal UnitPrice
);

public record CreateReceiptRequest(
    int WarehouseId,
    int SupplierId,
    int? TradeShipmentId,
    DateTime DocumentDate,
    string? Note,
    List<CreateReceiptDetailRequest> Details
);

public record CreateIssueDetailRequest(
    int VaccineId,
    int BatchId,
    int LocationId,
    int Quantity,
    decimal UnitPrice,
    int? FefoSuggestedBatchId,
    string? OverrideReason
);

public record CreateIssueRequest(
    int WarehouseId,
    int RecipientId,
    DateTime DocumentDate,
    DateTime? ExpectedDate,
    string? Note,
    List<CreateIssueDetailRequest> Details
);

public record QualityDecisionRequest(
    int BatchId,
    int? SegmentId,
    string NewStatus, // Released, Quarantined, Rejected
    string Reason,
    string? Note
);
