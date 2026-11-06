using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using VaxStock.Api.Data;
using VaxStock.Api.DTOs;
using VaxStock.Api.Models;
using VaxStock.Api.Services;

namespace VaxStock.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class QualityController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IInventoryService _inventoryService;

    public QualityController(AppDbContext context, IInventoryService inventoryService)
    {
        _context = context;
        _inventoryService = inventoryService;
    }

    private int GetCurrentUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return int.TryParse(idStr, out int id) ? id : 1;
    }

    [HttpGet("pending")]
    public async Task<IActionResult> GetPendingSegments([FromQuery] int? warehouseId)
    {
        var query = _context.StockSegments
            .Include(s => s.Warehouse)
            .Include(s => s.Location)
            .Include(s => s.Batch!)
                .ThenInclude(b => b.Vaccine)
            .Where(s => s.QualityStatus == QualityStatuses.PendingInspection && s.Quantity > 0);

        if (warehouseId.HasValue)
        {
            query = query.Where(s => s.WarehouseId == warehouseId.Value);
        }

        var list = await query
            .OrderBy(s => s.LastUpdatedAt)
            .Select(s => new
            {
                s.Id,
                s.WarehouseId,
                WarehouseName = s.Warehouse != null ? s.Warehouse.Name : "",
                s.LocationId,
                LocationName = s.Location != null ? s.Location.Name : "",
                s.BatchId,
                BatchNo = s.Batch != null ? s.Batch.BatchNo : "",
                VaccineName = s.Batch != null && s.Batch.Vaccine != null ? s.Batch.Vaccine.Name : "",
                ExpiresAt = s.Batch != null ? s.Batch.ExpiresAt : DateTime.MinValue,
                s.Quantity,
                s.QualityStatus,
                s.LastUpdatedAt
            })
            .ToListAsync();

        return Ok(list);
    }

    [HttpGet("decisions")]
    public async Task<IActionResult> GetDecisions([FromQuery] int? batchId)
    {
        var query = _context.QualityDecisions
            .Include(d => d.Batch!)
                .ThenInclude(b => b.Vaccine)
            .Include(d => d.DecidedByUser)
            .AsQueryable();

        if (batchId.HasValue)
        {
            query = query.Where(d => d.BatchId == batchId.Value);
        }

        var list = await query
            .OrderByDescending(d => d.DecidedAt)
            .Select(d => new
            {
                d.Id,
                d.BatchId,
                BatchNo = d.Batch != null ? d.Batch.BatchNo : "",
                VaccineName = d.Batch != null && d.Batch.Vaccine != null ? d.Batch.Vaccine.Name : "",
                d.SegmentId,
                d.PreviousStatus,
                d.NewStatus,
                d.Reason,
                d.Note,
                d.DecidedAt,
                DecidedByName = d.DecidedByUser != null ? d.DecidedByUser.FullName : ""
            })
            .ToListAsync();

        return Ok(list);
    }

    [HttpPost("decision")]
    [Authorize(Roles = $"{UserRoles.QualityManager},{UserRoles.Admin}")]
    public async Task<IActionResult> ApplyDecision([FromBody] QualityDecisionRequest req)
    {
        try
        {
            var userId = GetCurrentUserId();
            var decision = await _inventoryService.ApplyQualityDecisionAsync(req, userId);
            return Ok(new
            {
                message = $"Đã cập nhật trạng thái chất lượng sang {req.NewStatus} thành công",
                decisionId = decision.Id
            });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
