using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VaxStock.Api.Data;
using VaxStock.Api.Models;

namespace VaxStock.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class BatchesController : ControllerBase
{
    private readonly AppDbContext _context;

    public BatchesController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<IActionResult> GetBatches(
        [FromQuery] int? vaccineId,
        [FromQuery] string? search,
        [FromQuery] string? expiryFilter) // all, valid, nearExpiry, expired
    {
        var query = _context.VaccineBatches
            .Include(b => b.Vaccine)
            .AsQueryable();

        if (vaccineId.HasValue)
        {
            query = query.Where(b => b.VaccineId == vaccineId.Value);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(b => b.BatchNo.ToLower().Contains(s) || (b.Vaccine != null && b.Vaccine.Name.ToLower().Contains(s)));
        }

        var today = DateTime.UtcNow.Date;
        if (expiryFilter == "expired")
        {
            query = query.Where(b => b.ExpiresAt.Date <= today);
        }
        else if (expiryFilter == "nearExpiry")
        {
            var nearDate = today.AddDays(60);
            query = query.Where(b => b.ExpiresAt.Date > today && b.ExpiresAt.Date <= nearDate);
        }
        else if (expiryFilter == "valid")
        {
            query = query.Where(b => b.ExpiresAt.Date > today);
        }

        var list = await query
            .OrderBy(b => b.ExpiresAt)
            .Select(b => new
            {
                b.Id,
                b.VaccineId,
                VaccineCode = b.Vaccine != null ? b.Vaccine.Code : "",
                VaccineName = b.Vaccine != null ? b.Vaccine.Name : "",
                b.BatchNo,
                b.ManufacturedAt,
                b.ExpiresAt,
                b.ReferenceDoc,
                DaysUntilExpiry = (int)(b.ExpiresAt.Date - today).TotalDays,
                IsExpired = b.ExpiresAt.Date <= today
            })
            .ToListAsync();

        return Ok(list);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetBatchDetail(int id)
    {
        var batch = await _context.VaccineBatches
            .Include(b => b.Vaccine)
            .FirstOrDefaultAsync(b => b.Id == id);

        if (batch == null) return NotFound();

        // Lấy danh sách tồn kho theo vị trí của lô này
        var segments = await _context.StockSegments
            .Include(s => s.Warehouse)
            .Include(s => s.Location)
            .Where(s => s.BatchId == id)
            .Select(s => new
            {
                s.Id,
                s.WarehouseId,
                WarehouseName = s.Warehouse != null ? s.Warehouse.Name : "",
                s.LocationId,
                LocationName = s.Location != null ? s.Location.Name : "",
                s.QualityStatus,
                s.Quantity,
                s.ReservedQuantity,
                AvailableQuantity = s.QualityStatus == QualityStatuses.Released && batch.ExpiresAt.Date > DateTime.UtcNow.Date
                    ? Math.Max(0, s.Quantity - s.ReservedQuantity) : 0
            })
            .ToListAsync();

        // Lịch sử biến động
        var movements = await _context.StockMovements
            .Include(m => m.CreatedByUser)
            .Where(m => m.BatchId == id)
            .OrderByDescending(m => m.CreatedAt)
            .Take(50)
            .Select(m => new
            {
                m.Id,
                m.MovementType,
                m.DocumentId,
                m.QuantityChange,
                m.QualityStatus,
                m.CreatedAt,
                CreatedBy = m.CreatedByUser != null ? m.CreatedByUser.FullName : "",
                m.Note
            })
            .ToListAsync();

        return Ok(new
        {
            batch.Id,
            batch.VaccineId,
            VaccineName = batch.Vaccine?.Name,
            batch.BatchNo,
            batch.ManufacturedAt,
            batch.ExpiresAt,
            batch.ReferenceDoc,
            Segments = segments,
            Movements = movements
        });
    }
}
