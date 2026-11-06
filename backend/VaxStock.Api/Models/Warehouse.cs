namespace VaxStock.Api.Models;

public class Warehouse
{
    public int Id { get; set; }
    public required string Code { get; set; }
    public required string Name { get; set; }
    public string? Address { get; set; }
    public bool IsActive { get; set; } = true;

    public List<StorageLocation> Locations { get; set; } = [];
}

public class StorageLocation
{
    public int Id { get; set; }
    public int WarehouseId { get; set; }
    public Warehouse? Warehouse { get; set; }
    public required string Code { get; set; } // e.g. "KHO1-TL1"
    public required string Name { get; set; } // Tủ đông 01, Phòng lạnh 02
    public string LocationType { get; set; } = "ColdRoom"; // ColdRoom, Fridge, Freezer
    public double TempMin { get; set; } = 2.0; // °C
    public double TempMax { get; set; } = 8.0; // °C
}
