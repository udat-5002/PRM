namespace VaxStock.Api.Models;

public static class PartnerTypes
{
    public const string Supplier = "Supplier";
    public const string Recipient = "Recipient";
    public const string Manufacturer = "Manufacturer";
    public const string Carrier = "Carrier";
}

public class Partner
{
    public int Id { get; set; }
    public required string Code { get; set; }
    public required string Name { get; set; }
    public required string Type { get; set; } // Supplier, Recipient, Manufacturer, Carrier
    public string? Country { get; set; }
    public string? ContactEmail { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public bool IsActive { get; set; } = true;
}
