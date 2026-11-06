using Microsoft.EntityFrameworkCore;
using VaxStock.Api.Data;
using VaxStock.Api.DTOs;
using VaxStock.Api.Models;

namespace VaxStock.Api.Services;

public interface IInventoryService
{
    Task<FefoSuggestionResult> GetFefoAllocationAsync(int warehouseId, int vaccineId, int requestedQuantity);
    Task<InventoryDocument> CreateReceiptDraftAsync(CreateReceiptRequest req, int userId);
    Task<InventoryDocument> PostReceiptAsync(int documentId, int userId);
    Task<InventoryDocument> CreateIssueDraftAsync(CreateIssueRequest req, int userId);
    Task<InventoryDocument> CancelDocumentAsync(int documentId, int userId);
    Task<InventoryDocument> PostIssueAsync(int documentId, int userId);
    Task<QualityDecision> ApplyQualityDecisionAsync(QualityDecisionRequest req, int userId);
}

public class InventoryService : IInventoryService
{
    private readonly AppDbContext _context;

    public InventoryService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<FefoSuggestionResult> GetFefoAllocationAsync(int warehouseId, int vaccineId, int requestedQuantity)
    {
        var vaccine = await _context.Vaccines.FindAsync(vaccineId)
            ?? throw new InvalidOperationException($"Không tìm thấy vaccine Id {vaccineId}");

        var today = DateTime.UtcNow.Date;

        // Lấy tất cả phân đoạn kho thuộc kho này, cùng vaccine, đã giải phóng và chưa hết hạn
        var segments = await _context.StockSegments
            .Include(s => s.Batch)
            .Include(s => s.Location)
            .Where(s => s.WarehouseId == warehouseId &&
                        s.Batch!.VaccineId == vaccineId &&
                        s.QualityStatus == QualityStatuses.Released &&
                        s.Batch.ExpiresAt.Date > today &&
                        (s.Quantity - s.ReservedQuantity) > 0)
            .OrderBy(s => s.Batch!.ExpiresAt)      // FEFO: Hạn dùng gần nhất xếp trước
            .ThenBy(s => s.Batch!.CreatedAt)      // Lô nhập trước xếp trước
            .ThenBy(s => s.Id)
            .ToListAsync();

        var allocations = new List<FefoAllocationItem>();
        int remaining = requestedQuantity;

        foreach (var seg in segments)
        {
            if (remaining <= 0) break;

            int available = Math.Max(0, seg.Quantity - seg.ReservedQuantity);
            if (available <= 0) continue;

            int take = Math.Min(remaining, available);
            allocations.Add(new FefoAllocationItem(
                BatchId: seg.BatchId,
                BatchNo: seg.Batch!.BatchNo,
                LocationId: seg.LocationId,
                LocationName: seg.Location?.Name ?? $"Vị trí #{seg.LocationId}",
                ExpiresAt: seg.Batch.ExpiresAt,
                AvailableQuantity: available,
                AllocatedQuantity: take
            ));

            remaining -= take;
        }

        int totalAllocated = requestedQuantity - remaining;
        bool isFulfilled = remaining == 0;
        string? warning = isFulfilled ? null : $"Kho chỉ còn {totalAllocated} lọ đủ điều kiện xuất (thiếu {remaining} lọ).";

        return new FefoSuggestionResult(
            VaccineId: vaccine.Id,
            VaccineName: vaccine.Name,
            RequestedQuantity: requestedQuantity,
            TotalAllocatedQuantity: totalAllocated,
            IsFullyFulfilled: isFulfilled,
            WarningMessage: warning,
            Allocations: allocations
        );
    }

    public async Task<InventoryDocument> CreateReceiptDraftAsync(CreateReceiptRequest req, int userId)
    {
        var docNo = $"PN-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString()[..6].ToUpper()}";
        var doc = new InventoryDocument
        {
            DocNo = docNo,
            DocumentType = DocumentTypes.Receipt,
            Status = DocumentStatuses.Draft,
            WarehouseId = req.WarehouseId,
            PartnerId = req.SupplierId,
            TradeShipmentId = req.TradeShipmentId,
            DocumentDate = req.DocumentDate,
            Note = req.Note,
            CreatedByUserId = userId,
            CreatedAt = DateTime.UtcNow
        };

        foreach (var item in req.Details)
        {
            doc.Details.Add(new InventoryDocumentDetail
            {
                VaccineId = item.VaccineId,
                BatchNo = item.BatchNo.Trim(),
                ExpiresAt = item.ExpiresAt,
                LocationId = item.LocationId,
                Quantity = item.Quantity,
                UnitPrice = item.UnitPrice
            });
        }

        _context.InventoryDocuments.Add(doc);
        await _context.SaveChangesAsync();
        return doc;
    }

    public async Task<InventoryDocument> PostReceiptAsync(int documentId, int userId)
    {
        var doc = await _context.InventoryDocuments
            .Include(d => d.Details)
            .FirstOrDefaultAsync(d => d.Id == documentId)
            ?? throw new InvalidOperationException("Không tìm thấy phiếu nhập");

        if (doc.Status == DocumentStatuses.Posted)
            throw new InvalidOperationException("Phiếu nhập đã được ghi sổ trước đó!");
        if (doc.Status == DocumentStatuses.Cancelled)
            throw new InvalidOperationException("Không thể ghi sổ phiếu đã bị hủy!");

        // Dùng transaction nguyên tử
        await using var tx = await _context.Database.BeginTransactionAsync();

        foreach (var detail in doc.Details)
        {
            // 1. Tìm hoặc tạo Batch
            var batch = await _context.VaccineBatches
                .FirstOrDefaultAsync(b => b.VaccineId == detail.VaccineId && b.BatchNo == detail.BatchNo);

            if (batch == null)
            {
                batch = new VaccineBatch
                {
                    VaccineId = detail.VaccineId,
                    BatchNo = detail.BatchNo,
                    ExpiresAt = detail.ExpiresAt,
                    CreatedAt = DateTime.UtcNow
                };
                _context.VaccineBatches.Add(batch);
                await _context.SaveChangesAsync();
            }
            detail.BatchId = batch.Id;

            // 2. Tìm hoặc tạo StockSegment (Mặc định hàng mới nhập ở trạng thái PendingInspection)
            var segment = await _context.StockSegments
                .FirstOrDefaultAsync(s => s.WarehouseId == doc.WarehouseId &&
                                         s.LocationId == detail.LocationId &&
                                         s.BatchId == batch.Id &&
                                         s.QualityStatus == QualityStatuses.PendingInspection);

            if (segment == null)
            {
                segment = new StockSegment
                {
                    WarehouseId = doc.WarehouseId,
                    LocationId = detail.LocationId,
                    BatchId = batch.Id,
                    QualityStatus = QualityStatuses.PendingInspection,
                    Quantity = detail.Quantity,
                    ReservedQuantity = 0,
                    LastUpdatedAt = DateTime.UtcNow
                };
                _context.StockSegments.Add(segment);
                await _context.SaveChangesAsync();
            }
            else
            {
                segment.Quantity += detail.Quantity;
                segment.LastUpdatedAt = DateTime.UtcNow;
            }

            // 3. Ghi StockMovement
            _context.StockMovements.Add(new StockMovement
            {
                MovementType = "Receipt",
                DocumentId = doc.Id,
                SegmentId = segment.Id,
                BatchId = batch.Id,
                WarehouseId = doc.WarehouseId,
                LocationId = detail.LocationId,
                QuantityChange = detail.Quantity,
                QualityStatus = QualityStatuses.PendingInspection,
                CreatedAt = DateTime.UtcNow,
                CreatedByUserId = userId,
                Note = $"Nhập kho theo phiếu {doc.DocNo}"
            });
        }

        doc.Status = DocumentStatuses.Posted;
        doc.PostedByUserId = userId;
        doc.PostedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        await tx.CommitAsync();

        return doc;
    }

    public async Task<InventoryDocument> CreateIssueDraftAsync(CreateIssueRequest req, int userId)
    {
        await using var tx = await _context.Database.BeginTransactionAsync();

        var docNo = $"PX-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString()[..6].ToUpper()}";
        var doc = new InventoryDocument
        {
            DocNo = docNo,
            DocumentType = DocumentTypes.Issue,
            Status = DocumentStatuses.Draft,
            WarehouseId = req.WarehouseId,
            PartnerId = req.RecipientId,
            DocumentDate = req.DocumentDate,
            ExpectedDate = req.ExpectedDate,
            Note = req.Note,
            CreatedByUserId = userId,
            CreatedAt = DateTime.UtcNow
        };

        var today = DateTime.UtcNow.Date;

        foreach (var item in req.Details)
        {
            var batch = await _context.VaccineBatches.FindAsync(item.BatchId)
                ?? throw new InvalidOperationException($"Lô Id {item.BatchId} không tồn tại");

            // Tìm segment
            var segment = await _context.StockSegments
                .FirstOrDefaultAsync(s => s.WarehouseId == req.WarehouseId &&
                                         s.LocationId == item.LocationId &&
                                         s.BatchId == item.BatchId &&
                                         s.QualityStatus == QualityStatuses.Released)
                ?? throw new InvalidOperationException($"Lô {batch.BatchNo} tại vị trí này chưa được giải phóng chất lượng hoặc không có tồn!");

            if (batch.ExpiresAt.Date <= today)
                throw new InvalidOperationException($"Lô {batch.BatchNo} đã hết hạn sử dụng! Không thể xuất.");

            int available = segment.Quantity - segment.ReservedQuantity;
            if (available < item.Quantity)
                throw new InvalidOperationException($"Lô {batch.BatchNo} chỉ còn {available} lọ khả dụng, không đủ xuất {item.Quantity} lọ!");

            // Giữ hàng (Reservation)
            segment.ReservedQuantity += item.Quantity;
            segment.LastUpdatedAt = DateTime.UtcNow;

            doc.Details.Add(new InventoryDocumentDetail
            {
                VaccineId = item.VaccineId,
                BatchId = item.BatchId,
                BatchNo = batch.BatchNo,
                ExpiresAt = batch.ExpiresAt,
                LocationId = item.LocationId,
                Quantity = item.Quantity,
                UnitPrice = item.UnitPrice,
                FEFOSuggestedBatchId = item.FefoSuggestedBatchId,
                OverrideReason = item.OverrideReason
            });
        }

        _context.InventoryDocuments.Add(doc);
        await _context.SaveChangesAsync();
        await tx.CommitAsync();

        return doc;
    }

    public async Task<InventoryDocument> CancelDocumentAsync(int documentId, int userId)
    {
        await using var tx = await _context.Database.BeginTransactionAsync();

        var doc = await _context.InventoryDocuments
            .Include(d => d.Details)
            .FirstOrDefaultAsync(d => d.Id == documentId)
            ?? throw new InvalidOperationException("Không tìm thấy phiếu");

        if (doc.Status != DocumentStatuses.Draft)
            throw new InvalidOperationException("Chỉ phiếu nháp mới được phép hủy");

        // Nếu là phiếu xuất nháp -> giải phóng số lượng đang giữ (ReservedQuantity)
        if (doc.DocumentType == DocumentTypes.Issue)
        {
            foreach (var detail in doc.Details)
            {
                if (!detail.BatchId.HasValue) continue;
                var segment = await _context.StockSegments
                    .FirstOrDefaultAsync(s => s.WarehouseId == doc.WarehouseId &&
                                             s.LocationId == detail.LocationId &&
                                             s.BatchId == detail.BatchId.Value &&
                                             s.QualityStatus == QualityStatuses.Released);

                if (segment != null)
                {
                    segment.ReservedQuantity = Math.Max(0, segment.ReservedQuantity - detail.Quantity);
                    segment.LastUpdatedAt = DateTime.UtcNow;
                }
            }
        }

        doc.Status = DocumentStatuses.Cancelled;
        await _context.SaveChangesAsync();
        await tx.CommitAsync();

        return doc;
    }

    public async Task<InventoryDocument> PostIssueAsync(int documentId, int userId)
    {
        await using var tx = await _context.Database.BeginTransactionAsync();

        var doc = await _context.InventoryDocuments
            .Include(d => d.Details)
            .FirstOrDefaultAsync(d => d.Id == documentId)
            ?? throw new InvalidOperationException("Không tìm thấy phiếu xuất");

        if (doc.Status == DocumentStatuses.Posted)
            throw new InvalidOperationException("Phiếu xuất này đã được ghi sổ trước đó!");
        if (doc.Status == DocumentStatuses.Cancelled)
            throw new InvalidOperationException("Phiếu xuất đã bị hủy!");

        var today = DateTime.UtcNow.Date;

        foreach (var detail in doc.Details)
        {
            if (!detail.BatchId.HasValue)
                throw new InvalidOperationException("Chi tiết phiếu xuất thiếu thông tin Lô");

            var batch = await _context.VaccineBatches.FindAsync(detail.BatchId.Value)
                ?? throw new InvalidOperationException($"Không tìm thấy lô Id {detail.BatchId.Value}");

            if (batch.ExpiresAt.Date <= today)
                throw new InvalidOperationException($"Lô {batch.BatchNo} đã hết hạn sử dụng trước khi Post! Chặn xuất.");

            var segment = await _context.StockSegments
                .FirstOrDefaultAsync(s => s.WarehouseId == doc.WarehouseId &&
                                         s.LocationId == detail.LocationId &&
                                         s.BatchId == detail.BatchId.Value &&
                                         s.QualityStatus == QualityStatuses.Released)
                ?? throw new InvalidOperationException($"Lô {batch.BatchNo} không còn ở trạng thái Released hoặc đã bị chuyển vùng!");

            if (segment.Quantity < detail.Quantity)
                throw new InvalidOperationException($"Lô {batch.BatchNo} tồn thực tế không đủ ({segment.Quantity} < {detail.Quantity})");

            // Trừ tồn vật lý và giải phóng giữ hàng trong cùng giao dịch
            segment.Quantity -= detail.Quantity;
            segment.ReservedQuantity = Math.Max(0, segment.ReservedQuantity - detail.Quantity);
            segment.LastUpdatedAt = DateTime.UtcNow;

            // Ghi nhận biến động kho
            _context.StockMovements.Add(new StockMovement
            {
                MovementType = "Issue",
                DocumentId = doc.Id,
                SegmentId = segment.Id,
                BatchId = batch.Id,
                WarehouseId = doc.WarehouseId,
                LocationId = detail.LocationId,
                QuantityChange = -detail.Quantity,
                QualityStatus = QualityStatuses.Released,
                CreatedAt = DateTime.UtcNow,
                CreatedByUserId = userId,
                Note = $"Xuất kho theo phiếu {doc.DocNo}"
            });
        }

        doc.Status = DocumentStatuses.Posted;
        doc.PostedByUserId = userId;
        doc.PostedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        await tx.CommitAsync();

        return doc;
    }

    public async Task<QualityDecision> ApplyQualityDecisionAsync(QualityDecisionRequest req, int userId)
    {
        await using var tx = await _context.Database.BeginTransactionAsync();

        var batch = await _context.VaccineBatches.FindAsync(req.BatchId)
            ?? throw new InvalidOperationException("Không tìm thấy lô vắc xin");

        // Tìm các segment cần đổi trạng thái chất lượng
        IQueryable<StockSegment> query = _context.StockSegments.Where(s => s.BatchId == req.BatchId);
        if (req.SegmentId.HasValue)
        {
            query = query.Where(s => s.Id == req.SegmentId.Value);
        }

        var targetSegments = await query.ToListAsync();
        if (targetSegments.Count == 0)
            throw new InvalidOperationException("Không tìm thấy phân đoạn tồn kho tương ứng");

        string prevStatus = targetSegments[0].QualityStatus;

        foreach (var seg in targetSegments)
        {
            if (seg.QualityStatus == req.NewStatus) continue;

            // Nếu chuyển từ Released sang Quarantined/Rejected mà đang có phiếu nháp giữ hàng:
            // Cảnh báo hoặc giải phóng giữ hàng để ngăn xuất nhầm
            if (req.NewStatus != QualityStatuses.Released && seg.ReservedQuantity > 0)
            {
                // Giữ nguyên số lượng Reserved để kiểm tra khi Post issue sẽ bị chặn
            }

            // Gộp hoặc cập nhật segment
            // Tìm xem đã có segment cùng (Warehouse, Location, Batch, NewStatus) chưa
            var existingNewSegment = await _context.StockSegments
                .FirstOrDefaultAsync(s => s.WarehouseId == seg.WarehouseId &&
                                         s.LocationId == seg.LocationId &&
                                         s.BatchId == seg.BatchId &&
                                         s.QualityStatus == req.NewStatus &&
                                         s.Id != seg.Id);

            if (existingNewSegment != null)
            {
                existingNewSegment.Quantity += seg.Quantity;
                existingNewSegment.ReservedQuantity += seg.ReservedQuantity;
                existingNewSegment.LastUpdatedAt = DateTime.UtcNow;
                _context.StockSegments.Remove(seg);
            }
            else
            {
                seg.QualityStatus = req.NewStatus;
                seg.LastUpdatedAt = DateTime.UtcNow;
            }

            // Ghi movement Audit
            _context.StockMovements.Add(new StockMovement
            {
                MovementType = "QualityChange",
                SegmentId = existingNewSegment?.Id ?? seg.Id,
                BatchId = batch.Id,
                WarehouseId = seg.WarehouseId,
                LocationId = seg.LocationId,
                QuantityChange = 0,
                QualityStatus = req.NewStatus,
                CreatedAt = DateTime.UtcNow,
                CreatedByUserId = userId,
                Note = $"Đổi trạng thái chất lượng từ {prevStatus} -> {req.NewStatus}: {req.Reason}"
            });
        }

        var decision = new QualityDecision
        {
            BatchId = req.BatchId,
            SegmentId = req.SegmentId,
            PreviousStatus = prevStatus,
            NewStatus = req.NewStatus,
            Reason = req.Reason,
            Note = req.Note,
            DecidedByUserId = userId,
            DecidedAt = DateTime.UtcNow
        };

        _context.QualityDecisions.Add(decision);
        await _context.SaveChangesAsync();
        await tx.CommitAsync();

        return decision;
    }
}
