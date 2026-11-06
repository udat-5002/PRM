using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VaxStock.Api.Data;
using VaxStock.Api.DTOs;
using VaxStock.Api.Models;
using VaxStock.Api.Services;

namespace VaxStock.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class InventoryController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IInventoryService _inventoryService;

    public InventoryController(AppDbContext context, IInventoryService inventoryService)
    {
        _context = context;
        _inventoryService = inventoryService;
    }

    [HttpGet("stock")]
    public async Task<IActionResult> GetStock(
        [FromQuery] int? warehouseId,
        [FromQuery] int? vaccineId,
        [FromQuery] string? qualityStatus,
        [FromQuery] string? search)
    {
        var query = _context.StockSegments
            .Include(s => s.Warehouse)
            .Include(s => s.Location)
            .Include(s => s.Batch!)
                .ThenInclude(b => b.Vaccine)
            .Where(s => s.Quantity > 0 || s.ReservedQuantity > 0);

        if (warehouseId.HasValue)
        {
            query = query.Where(s => s.WarehouseId == warehouseId.Value);
        }

        if (vaccineId.HasValue)
        {
            query = query.Where(s => s.Batch!.VaccineId == vaccineId.Value);
        }

        if (!string.IsNullOrEmpty(qualityStatus))
        {
            query = query.Where(s => s.QualityStatus == qualityStatus);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(seg =>
                seg.Batch!.BatchNo.ToLower().Contains(s) ||
                seg.Batch.Vaccine!.Name.ToLower().Contains(s) ||
                seg.Batch.Vaccine.Code.ToLower().Contains(s));
        }

        var today = DateTime.UtcNow.Date;
        var list = await query
            .OrderBy(s => s.Batch!.ExpiresAt)
            .Select(s => new StockItemDto(
                s.Id,
                s.WarehouseId,
                s.Warehouse != null ? s.Warehouse.Name : "",
                s.LocationId,
                s.Location != null ? s.Location.Name : "",
                s.Batch!.VaccineId,
                s.Batch.Vaccine != null ? s.Batch.Vaccine.Code : "",
                s.Batch.Vaccine != null ? s.Batch.Vaccine.Name : "",
                s.BatchId,
                s.Batch.BatchNo,
                s.Batch.ExpiresAt,
                s.QualityStatus,
                s.Quantity,
                s.ReservedQuantity,
                s.QualityStatus == QualityStatuses.Released && s.Batch.ExpiresAt.Date > today
                    ? Math.Max(0, s.Quantity - s.ReservedQuantity) : 0
            ))
            .ToListAsync();

        return Ok(list);
    }

    [HttpGet("dashboard")]
    public async Task<IActionResult> GetDashboardSummary([FromQuery] int? warehouseId)
    {
        var today = DateTime.UtcNow.Date;
        var nearDate = today.AddDays(60);

        var segQuery = _context.StockSegments.Include(s => s.Batch).AsQueryable();
        if (warehouseId.HasValue)
        {
            segQuery = segQuery.Where(s => s.WarehouseId == warehouseId.Value);
        }

        var segments = await segQuery.ToListAsync();

        int totalVaccines = await _context.Vaccines.CountAsync(v => v.IsActive);
        int totalPhysical = segments.Sum(s => s.Quantity);

        int totalAvailable = segments
            .Where(s => s.QualityStatus == QualityStatuses.Released && s.Batch != null && s.Batch.ExpiresAt.Date > today)
            .Sum(s => Math.Max(0, s.Quantity - s.ReservedQuantity));

        int pendingQA = segments
            .Where(s => s.QualityStatus == QualityStatuses.PendingInspection)
            .Sum(s => s.Quantity);

        int quarantined = segments
            .Where(s => s.QualityStatus == QualityStatuses.Quarantined)
            .Sum(s => s.Quantity);

        // Batches count
        var batchQuery = _context.VaccineBatches.AsQueryable();
        var batches = await batchQuery.ToListAsync();
        int nearExpiryCount = batches.Count(b => b.ExpiresAt.Date > today && b.ExpiresAt.Date <= nearDate);
        int expiredCount = batches.Count(b => b.ExpiresAt.Date <= today);

        return Ok(new DashboardSummaryDto(
            TotalVaccines: totalVaccines,
            TotalPhysicalVials: totalPhysical,
            TotalAvailableVials: totalAvailable,
            PendingInspectionVials: pendingQA,
            QuarantinedVials: quarantined,
            NearExpiryBatchesCount: nearExpiryCount,
            ExpiredBatchesCount: expiredCount
        ));
    }

    [HttpGet("fefo-suggestion")]
    public async Task<IActionResult> GetFefoSuggestion(
        [FromQuery] int warehouseId,
        [FromQuery] int vaccineId,
        [FromQuery] int quantity)
    {
        if (quantity <= 0) return BadRequest("Số lượng phải lớn hơn 0");

        try
        {
            var result = await _inventoryService.GetFefoAllocationAsync(warehouseId, vaccineId, quantity);
            return Ok(result);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("movements")]
    public async Task<IActionResult> GetMovements([FromQuery] int? warehouseId, [FromQuery] int? limit = 100)
    {
        var query = _context.StockMovements
            .Include(m => m.Batch)
                .ThenInclude(b => b!.Vaccine)
            .Include(m => m.CreatedByUser)
            .AsQueryable();

        if (warehouseId.HasValue)
        {
            query = query.Where(m => m.WarehouseId == warehouseId.Value);
        }

        var list = await query
            .OrderByDescending(m => m.CreatedAt)
            .Take(limit ?? 100)
            .Select(m => new
            {
                m.Id,
                m.MovementType,
                m.DocumentId,
                m.BatchId,
                BatchNo = m.Batch != null ? m.Batch.BatchNo : "",
                VaccineName = m.Batch != null && m.Batch.Vaccine != null ? m.Batch.Vaccine.Name : "",
                m.QuantityChange,
                m.QualityStatus,
                m.CreatedAt,
                CreatedBy = m.CreatedByUser != null ? m.CreatedByUser.FullName : "",
                m.Note
            })
            .ToListAsync();

        return Ok(list);
    }
}
