using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VaxStock.Api.Data;
using VaxStock.Api.Models;

namespace VaxStock.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class TradeShipmentsController : ControllerBase
{
    private readonly AppDbContext _context;

    public TradeShipmentsController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<IActionResult> GetShipments([FromQuery] string? type)
    {
        var query = _context.TradeShipments
            .Include(s => s.Partner)
            .AsQueryable();

        if (!string.IsNullOrEmpty(type))
        {
            query = query.Where(s => s.ShipmentType == type);
        }

        var list = await query
            .OrderByDescending(s => s.CreatedAt)
            .Select(s => new
            {
                s.Id,
                s.ShipmentNo,
                s.ShipmentType,
                s.PartnerId,
                PartnerName = s.Partner != null ? s.Partner.Name : "",
                s.Country,
                s.ExpectedDate,
                s.ActualDate,
                s.Status,
                s.CustomsDeclarationNo,
                s.Notes,
                LinkedDocumentsCount = s.LinkedDocuments.Count
            })
            .ToListAsync();

        return Ok(list);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetShipmentById(int id)
    {
        var s = await _context.TradeShipments
            .Include(sh => sh.Partner)
            .Include(sh => sh.LinkedDocuments)
            .FirstOrDefaultAsync(sh => sh.Id == id);

        if (s == null) return NotFound();

        return Ok(new
        {
            s.Id,
            s.ShipmentNo,
            s.ShipmentType,
            s.PartnerId,
            PartnerName = s.Partner?.Name,
            s.Country,
            s.ExpectedDate,
            s.ActualDate,
            s.Status,
            s.CustomsDeclarationNo,
            s.Notes,
            LinkedDocuments = s.LinkedDocuments.Select(d => new
            {
                d.Id,
                d.DocNo,
                d.DocumentType,
                d.Status,
                d.DocumentDate
            })
        });
    }

    [HttpPost]
    public async Task<IActionResult> CreateShipment([FromBody] TradeShipment shipment)
    {
        _context.TradeShipments.Add(shipment);
        await _context.SaveChangesAsync();
        return CreatedAtAction(nameof(GetShipmentById), new { id = shipment.Id }, shipment);
    }
}
