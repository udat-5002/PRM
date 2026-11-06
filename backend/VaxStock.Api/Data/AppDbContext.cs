using Microsoft.EntityFrameworkCore;
using VaxStock.Api.Models;

namespace VaxStock.Api.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<Warehouse> Warehouses => Set<Warehouse>();
    public DbSet<StorageLocation> StorageLocations => Set<StorageLocation>();
    public DbSet<Partner> Partners => Set<Partner>();
    public DbSet<Vaccine> Vaccines => Set<Vaccine>();
    public DbSet<VaccineBatch> VaccineBatches => Set<VaccineBatch>();
    public DbSet<StockSegment> StockSegments => Set<StockSegment>();
    public DbSet<StockMovement> StockMovements => Set<StockMovement>();
    public DbSet<InventoryDocument> InventoryDocuments => Set<InventoryDocument>();
    public DbSet<InventoryDocumentDetail> InventoryDocumentDetails => Set<InventoryDocumentDetail>();
    public DbSet<QualityDecision> QualityDecisions => Set<QualityDecision>();
    public DbSet<TradeShipment> TradeShipments => Set<TradeShipment>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // User
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasIndex(u => u.Username).IsUnique();
        });

        // VaccineBatch: 1 Vaccine có nhiều Batch; (VaccineId, BatchNo) là duy nhất
        modelBuilder.Entity<VaccineBatch>(entity =>
        {
            entity.HasIndex(b => new { b.VaccineId, b.BatchNo }).IsUnique();
            entity.HasOne(b => b.Vaccine)
                  .WithMany(v => v.Batches)
                  .HasForeignKey(b => b.VaccineId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // StockSegment
        modelBuilder.Entity<StockSegment>(entity =>
        {
            entity.HasIndex(s => new { s.WarehouseId, s.LocationId, s.BatchId, s.QualityStatus }).IsUnique();
            entity.HasOne(s => s.Batch)
                  .WithMany()
                  .HasForeignKey(s => s.BatchId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // InventoryDocument
        modelBuilder.Entity<InventoryDocument>(entity =>
        {
            entity.HasIndex(d => d.DocNo).IsUnique();
            entity.HasOne(d => d.Partner)
                  .WithMany()
                  .HasForeignKey(d => d.PartnerId)
                  .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(d => d.TradeShipment)
                  .WithMany(s => s.LinkedDocuments)
                  .HasForeignKey(d => d.TradeShipmentId)
                  .OnDelete(DeleteBehavior.SetNull);
        });

        // InventoryDocumentDetail
        modelBuilder.Entity<InventoryDocumentDetail>(entity =>
        {
            entity.Property(d => d.UnitPrice).HasPrecision(18, 2);
            entity.HasOne(d => d.Document)
                  .WithMany(doc => doc.Details)
                  .HasForeignKey(d => d.DocumentId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // StockMovement
        modelBuilder.Entity<StockMovement>(entity =>
        {
            entity.HasOne(m => m.Segment)
                  .WithMany()
                  .HasForeignKey(m => m.SegmentId)
                  .OnDelete(DeleteBehavior.Restrict);
        });
    }
}
