using Microsoft.EntityFrameworkCore;
using RestApiSistemOptimasi.Models.Entities;

namespace RestApiSistemOptimasi.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

        public DbSet<User> Users { get; set; }
        public DbSet<Role> Roles { get; set; }
        public DbSet<MenuRole> MenuRoles { get; set; }
        public DbSet<Kantor> Kantors { get; set; }
        public DbSet<Manifest> Manifests { get; set; }
        public DbSet<DeliveryRunSheet> DeliveryRunSheets { get; set; }
        public DbSet<DetailDeliveryRunSheet> DetailDeliveryRunSheets { get; set; }
        public DbSet<ProofOfDelivery> ProofOfDeliveries { get; set; }
        public DbSet<OptimasiRuteHistory> OptimasiRuteHistories { get; set; }
        public DbSet<OptimasiRuteSegment> OptimasiRuteSegments { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Configure Relationships
            modelBuilder.Entity<DeliveryRunSheet>()
                .HasOne(d => d.BranchManager)
                .WithMany()
                .HasForeignKey(d => d.BranchManagerId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<DeliveryRunSheet>()
                .HasOne(d => d.Oranger)
                .WithMany()
                .HasForeignKey(d => d.OrangerId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<DeliveryRunSheet>()
                .HasOne(d => d.Kantor)
                .WithMany(k => k.DeliveryRunSheets)
                .HasForeignKey(d => d.KantorId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<ProofOfDelivery>()
                .HasOne(p => p.DetailDeliveryRunSheet)
                .WithOne(d => d.ProofOfDelivery)
                .HasForeignKey<ProofOfDelivery>(p => p.DetailDeliveryRunSheetId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}

