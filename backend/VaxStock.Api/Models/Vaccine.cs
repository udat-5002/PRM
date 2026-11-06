namespace VaxStock.Api.Models;

public class Vaccine
{
    public int Id { get; set; }
    public required string Code { get; set; }
    public required string Name { get; set; }
    public string? Group { get; set; } // e.g. "Vaccine phòng cúm", "Vaccine dại"
    public int? ManufacturerId { get; set; }
    public Partner? Manufacturer { get; set; }
    public string? CountryOfOrigin { get; set; }
    public int DosesPerVial { get; set; } = 1; // Số liều mỗi lọ (tham khảo)
    public int VialsPerPack { get; set; } = 10; // Quy cách hộp
    public string BaseUnit { get; set; } = "Lọ";
    public double TempMin { get; set; } = 2.0;
    public double TempMax { get; set; } = 8.0;
    public int MinStockThreshold { get; set; } = 50; // Cảnh báo tồn kho tối thiểu (lọ)
    public int NearExpiryDaysThreshold { get; set; } = 60; // Ngưỡng cảnh báo cận date (ngày)
    public bool IsActive { get; set; } = true;

    public List<VaccineBatch> Batches { get; set; } = [];
}

public class VaccineBatch
{
    public int Id { get; set; }
    public int VaccineId { get; set; }
    public Vaccine? Vaccine { get; set; }
    public required string BatchNo { get; set; }
    public DateTime? ManufacturedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public string? ReferenceDoc { get; set; } // Số giấy phép lưu hành / kiểm định
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
