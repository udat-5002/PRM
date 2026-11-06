using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using VaxStock.Api.Data;
using VaxStock.Api.DTOs;
using VaxStock.Api.Services;

namespace VaxStock.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ITokenService _tokenService;

    public AuthController(AppDbContext context, ITokenService tokenService)
    {
        _context = context;
        _tokenService = tokenService;
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest req)
    {
        var user = await _context.Users
            .Include(u => u.Warehouse)
            .FirstOrDefaultAsync(u => u.Username == req.Username.Trim());

        if (user == null || !user.IsActive || !BCrypt.Net.BCrypt.Verify(req.Password, user.PasswordHash))
        {
            return Unauthorized(new { message = "Tên đăng nhập hoặc mật khẩu không chính xác" });
        }

        var token = _tokenService.GenerateToken(user);
        var response = new LoginResponse(
            Token: token,
            UserId: user.Id,
            Username: user.Username,
            FullName: user.FullName,
            Role: user.Role,
            WarehouseId: user.WarehouseId,
            WarehouseName: user.Warehouse?.Name
        );

        return Ok(response);
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> GetCurrentUser()
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(userIdStr, out int userId)) return Unauthorized();

        var user = await _context.Users
            .Include(u => u.Warehouse)
            .FirstOrDefaultAsync(u => u.Id == userId);

        if (user == null) return NotFound();

        return Ok(new
        {
            user.Id,
            user.Username,
            user.FullName,
            user.Role,
            user.WarehouseId,
            WarehouseName = user.Warehouse?.Name
        });
    }
}
