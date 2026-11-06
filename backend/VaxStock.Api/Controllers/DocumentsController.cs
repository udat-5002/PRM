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
public class DocumentsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IInventoryService _inventoryService;

    public DocumentsController(AppDbContext context, IInventoryService inventoryService)
    {
        _context = context;
        _inventoryService = inventoryService;
    }

    private int GetCurrentUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return int.TryParse(idStr, out int id) ? id : 1;
    }

    [HttpGet]
    public async Task<IActionResult> GetDocuments(
        [FromQuery] string? type,
        [FromQuery] string? status,
        [FromQuery] int? warehouseId)
    {
        var query = _context.InventoryDocuments
            .Include(d => d.Warehouse)
            .Include(d => d.Partner)
            .Include(d => d.CreatedByUser)
            .AsQueryable();

        if (!string.IsNullOrEmpty(type))
        {
            query = query.Where(d => d.DocumentType == type);
        }

        if (!string.IsNullOrEmpty(status))
        {
            query = query.Where(d => d.Status == status);
        }

        if (warehouseId.HasValue)
        {
            query = query.Where(d => d.WarehouseId == warehouseId.Value);
        }

        var list = await query
            .OrderByDescending(d => d.CreatedAt)
            .Select(d => new
            {
                d.Id,
                d.DocNo,
                d.DocumentType,
                d.Status,
                d.WarehouseId,
                WarehouseName = d.Warehouse != null ? d.Warehouse.Name : "",
                d.PartnerId,
                PartnerName = d.Partner != null ? d.Partner.Name : "",
                d.TradeShipmentId,
                d.DocumentDate,
                d.ExpectedDate,
                d.Note,
                d.CreatedAt,
                CreatedByName = d.CreatedByUser != null ? d.CreatedByUser.FullName : "",
                TotalItems = d.Details.Count,
                TotalQuantity = d.Details.Sum(i => i.Quantity)
            })
            .ToListAsync();

        return Ok(list);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetDocumentById(int id)
    {
        var doc = await _context.InventoryDocuments
            .Include(d => d.Warehouse)
            .Include(d => d.Partner)
            .Include(d => d.CreatedByUser)
            .Include(d => d.PostedByUser)
            .Include(d => d.Details)
                .ThenInclude(dt => dt.Vaccine)
            .Include(d => d.Details)
                .ThenInclude(dt => dt.Location)
            .FirstOrDefaultAsync(d => d.Id == id);

        if (doc == null) return NotFound();

        return Ok(new
        {
            doc.Id,
            doc.DocNo,
            doc.DocumentType,
            doc.Status,
            doc.WarehouseId,
            WarehouseName = doc.Warehouse?.Name,
            doc.PartnerId,
            PartnerName = doc.Partner?.Name,
            doc.TradeShipmentId,
            doc.DocumentDate,
            doc.ExpectedDate,
            doc.Note,
            doc.CreatedAt,
            CreatedByName = doc.CreatedByUser?.FullName,
            doc.PostedAt,
            PostedByName = doc.PostedByUser?.FullName,
            Details = doc.Details.Select(dt => new
            {
                dt.Id,
                dt.VaccineId,
                VaccineCode = dt.Vaccine?.Code,
                VaccineName = dt.Vaccine?.Name,
                dt.BatchId,
                dt.BatchNo,
                dt.ExpiresAt,
                dt.LocationId,
                LocationName = dt.Location?.Name,
                dt.Quantity,
                dt.UnitPrice,
                dt.FEFOSuggestedBatchId,
                dt.OverrideReason
            })
        });
    }

    [HttpPost("receipt")]
    public async Task<IActionResult> CreateReceipt([FromBody] CreateReceiptRequest req)
    {
        try
        {
            var userId = GetCurrentUserId();
            var doc = await _inventoryService.CreateReceiptDraftAsync(req, userId);
            return Ok(new { message = "Tạo phiếu nhập nháp thành công", documentId = doc.Id, docNo = doc.DocNo });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("receipt/{id}/post")]
    public async Task<IActionResult> PostReceipt(int id)
    {
        try
        {
            var userId = GetCurrentUserId();
            var doc = await _inventoryService.PostReceiptAsync(id, userId);
            return Ok(new { message = "Ghi sổ phiếu nhập thành công (Hàng đang ở trạng thái chờ QA kiểm tra)", documentId = doc.Id });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("issue")]
    public async Task<IActionResult> CreateIssue([FromBody] CreateIssueRequest req)
    {
        try
        {
            var userId = GetCurrentUserId();
            var doc = await _inventoryService.CreateIssueDraftAsync(req, userId);
            return Ok(new { message = "Tạo phiếu xuất nháp và giữ hàng thành công", documentId = doc.Id, docNo = doc.DocNo });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("issue/{id}/post")]
    public async Task<IActionResult> PostIssue(int id)
    {
        try
        {
            var userId = GetCurrentUserId();
            var doc = await _inventoryService.PostIssueAsync(id, userId);
            return Ok(new { message = "Ghi sổ phiếu xuất thành công (Đã trừ tồn kho thực tế)", documentId = doc.Id });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("{id}/cancel")]
    public async Task<IActionResult> CancelDocument(int id)
    {
        try
        {
            var userId = GetCurrentUserId();
            var doc = await _inventoryService.CancelDocumentAsync(id, userId);
            return Ok(new { message = "Hủy phiếu và giải phóng giữ hàng thành công", documentId = doc.Id });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
