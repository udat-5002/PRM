using VaxStock.Api.Models;

namespace VaxStock.Api.Data;

public static class DbSeeder
{
    public static void Seed(AppDbContext context)
    {
        if (context.Users.Any()) return;

        // 1. Warehouses
        var whHanoi = new Warehouse { Code = "WH-HAN", Name = "Kho Trung Tâm Hà Nội", Address = "Đông Anh, Hà Nội" };
        var whHcm = new Warehouse { Code = "WH-SGN", Name = "Kho Chi Nhánh TP.HCM", Address = "Quận 9, TP.HCM" };
        context.Warehouses.AddRange(whHanoi, whHcm);
        context.SaveChanges();

        // 2. Storage Locations
        var locColdRoom1 = new StorageLocation { WarehouseId = whHanoi.Id, Code = "HAN-CR01", Name = "Phòng lạnh 01", LocationType = "ColdRoom", TempMin = 2, TempMax = 8 };
        var locDeepFreeze1 = new StorageLocation { WarehouseId = whHanoi.Id, Code = "HAN-DF01", Name = "Tủ đông âm sâu 01", LocationType = "Freezer", TempMin = -25, TempMax = -15 };
        var locFridgeHcm = new StorageLocation { WarehouseId = whHcm.Id, Code = "SGN-FR01", Name = "Tủ lạnh vắc xin SGN", LocationType = "Fridge", TempMin = 2, TempMax = 8 };
        context.StorageLocations.AddRange(locColdRoom1, locDeepFreeze1, locFridgeHcm);
        context.SaveChanges();

        // 3. Users (Password hashed with BCrypt)
        var adminUser = new User
        {
            Username = "admin",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("admin123"),
            FullName = "Quản trị viên Hệ Thống",
            Role = UserRoles.Admin
        };
        var staffUser = new User
        {
            Username = "staff_kho1",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("staff123"),
            FullName = "Nguyễn Văn Kho (Hà Nội)",
            Role = UserRoles.WarehouseStaff,
            WarehouseId = whHanoi.Id
        };
        var qaUser = new User
        {
            Username = "qa_manager",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("qa123"),
            FullName = "Lê Thị Kiểm Định (QA/QC)",
            Role = UserRoles.QualityManager
        };
        context.Users.AddRange(adminUser, staffUser, qaUser);
        context.SaveChanges();

        // 4. Partners
        var sanofi = new Partner { Code = "SANOFI", Name = "Sanofi Pasteur", Type = PartnerTypes.Manufacturer, Country = "Pháp" };
        var astra = new Partner { Code = "ASTRA", Name = "AstraZeneca AB", Type = PartnerTypes.Manufacturer, Country = "Thụy Điển" };
        var vnvc = new Partner { Code = "VNVC-HN", Name = "Trung tâm Tiêm chủng VNVC", Type = PartnerTypes.Recipient, Address = "Cầu Giấy, Hà Nội" };
        var dhl = new Partner { Code = "DHL-COLD", Name = "DHL Cold Chain Logistics", Type = PartnerTypes.Carrier, Country = "Việt Nam" };
        context.Partners.AddRange(sanofi, astra, vnvc, dhl);
        context.SaveChanges();

        // 5. Vaccines
        var hexaxim = new Vaccine
        {
            Code = "VAX-HEXA",
            Name = "Hexaxim (6 trong 1)",
            Group = "Vaccine trẻ em",
            ManufacturerId = sanofi.Id,
            CountryOfOrigin = "Pháp",
            DosesPerVial = 1,
            VialsPerPack = 10,
            BaseUnit = "Lọ",
            TempMin = 2,
            TempMax = 8,
            MinStockThreshold = 50,
            NearExpiryDaysThreshold = 90
        };
        var vaxigrip = new Vaccine
        {
            Code = "VAX-FLU",
            Name = "Vaxigrip Tetra (Cúm mùa)",
            Group = "Vaccine cúm",
            ManufacturerId = sanofi.Id,
            CountryOfOrigin = "Pháp",
            DosesPerVial = 1,
            VialsPerPack = 10,
            BaseUnit = "Lọ",
            TempMin = 2,
            TempMax = 8,
            MinStockThreshold = 100,
            NearExpiryDaysThreshold = 60
        };
        context.Vaccines.AddRange(hexaxim, vaxigrip);
        context.SaveChanges();

        // 6. Vaccine Batches
        var now = DateTime.UtcNow;
        // Batch 1: Hexaxim Lô A - Còn hạn dài, đã giải phóng
        var batchHexaA = new VaccineBatch
        {
            VaccineId = hexaxim.Id,
            BatchNo = "HEXA-2026-A",
            ManufacturedAt = now.AddMonths(-3),
            ExpiresAt = now.AddMonths(12),
            ReferenceDoc = "GPNK-1234/BYT"
        };
        // Batch 2: Hexaxim Lô B - Cận date (hết hạn trong 30 ngày), đã giải phóng
        var batchHexaB = new VaccineBatch
        {
            VaccineId = hexaxim.Id,
            BatchNo = "HEXA-2025-NEAR",
            ManufacturedAt = now.AddMonths(-18),
            ExpiresAt = now.AddDays(25),
            ReferenceDoc = "GPNK-1099/BYT"
        };
        // Batch 3: Vaxigrip Lô C - Mới về kho, chờ kiểm định QA
        var batchFluC = new VaccineBatch
        {
            VaccineId = vaxigrip.Id,
            BatchNo = "FLU-2026-NEW",
            ManufacturedAt = now.AddMonths(-1),
            ExpiresAt = now.AddMonths(8),
            ReferenceDoc = "GPNK-2026/BYT"
        };
        // Batch 4: Vaxigrip Lô D - Bị cảnh báo sốc nhiệt, đang cách ly
        var batchFluD = new VaccineBatch
        {
            VaccineId = vaxigrip.Id,
            BatchNo = "FLU-2026-ISO",
            ManufacturedAt = now.AddMonths(-2),
            ExpiresAt = now.AddMonths(6),
            ReferenceDoc = "GPNK-2015/BYT"
        };
        context.VaccineBatches.AddRange(batchHexaA, batchHexaB, batchFluC, batchFluD);
        context.SaveChanges();

        // 7. Stock Segments (Tồn kho thực tế ban đầu)
        var segHexaA = new StockSegment
        {
            WarehouseId = whHanoi.Id,
            LocationId = locColdRoom1.Id,
            BatchId = batchHexaA.Id,
            QualityStatus = QualityStatuses.Released,
            Quantity = 200, // 200 lọ
            ReservedQuantity = 0
        };
        var segHexaB = new StockSegment
        {
            WarehouseId = whHanoi.Id,
            LocationId = locColdRoom1.Id,
            BatchId = batchHexaB.Id,
            QualityStatus = QualityStatuses.Released,
            Quantity = 80, // 80 lọ (sẽ được FEFO ưu tiên xuất trước vì sắp hết hạn)
            ReservedQuantity = 0
        };
        var segFluC = new StockSegment
        {
            WarehouseId = whHanoi.Id,
            LocationId = locColdRoom1.Id,
            BatchId = batchFluC.Id,
            QualityStatus = QualityStatuses.PendingInspection, // Chờ QA duyệt, chưa khả dụng
            Quantity = 150,
            ReservedQuantity = 0
        };
        var segFluD = new StockSegment
        {
            WarehouseId = whHanoi.Id,
            LocationId = locColdRoom1.Id,
            BatchId = batchFluD.Id,
            QualityStatus = QualityStatuses.Quarantined, // Đang cách ly, không được xuất
            Quantity = 50,
            ReservedQuantity = 0
        };
        context.StockSegments.AddRange(segHexaA, segHexaB, segFluC, segFluD);
        context.SaveChanges();

        // 8. Demo Trade Shipment
        var shipment = new TradeShipment
        {
            ShipmentNo = "IMP-2026-001",
            ShipmentType = "Import",
            PartnerId = sanofi.Id,
            Country = "Pháp",
            ExpectedDate = now.AddDays(-2),
            ActualDate = now.AddDays(-1),
            Status = ShipmentStatuses.Arrived,
            CustomsDeclarationNo = "TK-1004567890",
            Notes = "Lô hàng 150 lọ Vaxigrip nhập đường hàng không qua Nội Bài."
        };
        context.TradeShipments.Add(shipment);
        context.SaveChanges();
    }
}
