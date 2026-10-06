using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RestApiSistemOptimasi.Models.Entities
{
    [Table("ProofOfDeliveries")]
    public class ProofOfDelivery
    {
        [Key]
        public int Id { get; set; }

        [ForeignKey("DetailDeliveryRunSheet")]
        public int DetailDeliveryRunSheetId { get; set; }

        [Required]
        [MaxLength(100)]
        public string NamaPenerima { get; set; } = string.Empty;

        [MaxLength(20)]
        public string? TelpPenerima { get; set; }

        [Required]
        public string AlamatPenerima { get; set; } = string.Empty;

        [Required]
        [MaxLength(30)]
        public string StatusDelivery { get; set; } = string.Empty;

        [Column(TypeName = "decimal(10,8)")]
        public decimal Latitude { get; set; }

        [Column(TypeName = "decimal(11,8)")]
        public decimal Longitude { get; set; }

        [Required]
        [MaxLength(255)]
        public string Photo1 { get; set; } = string.Empty;

        [MaxLength(255)]
        public string? Photo2 { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [MaxLength(100)]
        public string CreatedBy { get; set; } = "System";

        public DateTime? UpdatedAt { get; set; }

        [MaxLength(100)]
        public string? UpdatedBy { get; set; }

        // Navigation
        public DetailDeliveryRunSheet? DetailDeliveryRunSheet { get; set; }
    }
}
