using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VaxStock.Api.Data;
using VaxStock.Api.Models;

namespace VaxStock.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class MasterDataController : ControllerBase
{
    private readonly AppDbContext _context;

    public MasterDataController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet("warehouses")]
    public async Task<IActionResult> GetWarehouses()
    {
        var list = await _context.Warehouses
            .Include(w => w.Locations)
            .Where(w => w.IsActive)
            .ToListAsync();
        return Ok(list);
    }

    [HttpGet("warehouses/{warehouseId}/locations")]
    public async Task<IActionResult> GetLocations(int warehouseId)
    {
        var locations = await _context.StorageLocations
            .Where(l => l.WarehouseId == warehouseId)
            .ToListAsync();
        return Ok(locations);
    }

    [HttpGet("partners")]
    public async Task<IActionResult> GetPartners([FromQuery] string? type)
    {
        var query = _context.Partners.Where(p => p.IsActive);
        if (!string.IsNullOrEmpty(type))
        {
            query = query.Where(p => p.Type == type);
        }
        var list = await query.ToListAsync();
        return Ok(list);
    }

    [HttpGet("vaccines")]
    public async Task<IActionResult> GetVaccines()
    {
        var list = await _context.Vaccines
            .Include(v => v.Manufacturer)
            .Where(v => v.IsActive)
            .ToListAsync();
        return Ok(list);
    }

    [HttpPost("vaccines")]
    [Authorize(Roles = UserRoles.Admin)]
    public async Task<IActionResult> CreateVaccine([FromBody] Vaccine vaccine)
    {
        _context.Vaccines.Add(vaccine);
        await _context.SaveChangesAsync();
        return CreatedAtAction(nameof(GetVaccines), new { id = vaccine.Id }, vaccine);
    }
}
