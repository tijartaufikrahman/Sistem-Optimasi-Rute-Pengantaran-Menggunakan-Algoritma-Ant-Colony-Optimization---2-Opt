using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RestApiSistemOptimasi.Models.Entities
{
    [Table("Manifests")]
    public class Manifest
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        public string NomorKiriman { get; set; } = string.Empty;

        [Required]
        [MaxLength(100)]
        public string NamaPenerima { get; set; } = string.Empty;

        [MaxLength(20)]
        public string? TeleponPenerima { get; set; }

        [Required]
        public string AlamatTujuan { get; set; } = string.Empty;

        [Column(TypeName = "decimal(10,8)")]
        public decimal Latitude { get; set; }

        [Column(TypeName = "decimal(11,8)")]
        public decimal Longitude { get; set; }

        [Column(TypeName = "decimal(6,2)")]
        public decimal BeratKg { get; set; } = 0;

        [Required]
        [MaxLength(30)]
        public string StatusKiriman { get; set; } = "Manifest";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [MaxLength(100)]
        public string CreatedBy { get; set; } = "System";

        public DateTime? UpdatedAt { get; set; }

        [MaxLength(100)]
        public string? UpdatedBy { get; set; }

        // Navigation
        public ICollection<DetailDeliveryRunSheet> Details { get; set; } = new List<DetailDeliveryRunSheet>();
    }
}
