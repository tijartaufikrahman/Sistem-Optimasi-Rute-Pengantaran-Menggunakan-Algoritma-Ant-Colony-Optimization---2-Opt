using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RestApiSistemOptimasi.Models.Entities
{
    [Table("OptimasiRuteHistory")]
    public class OptimasiRuteHistory
    {
        [Key]
        public int Id { get; set; }

        [ForeignKey("DeliveryRunSheet")]
        public int DeliveryRunSheetId { get; set; }

        [Column(TypeName = "decimal(8,2)")]
        public decimal TotalJarakKm { get; set; }

        [Column(TypeName = "decimal(8,2)")]
        public decimal TotalEstimasiMenit { get; set; }

        [Required]
        public string PolylineFull { get; set; } = string.Empty;

        public DateTime ExecutedAt { get; set; } = DateTime.UtcNow;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [MaxLength(100)]
        public string CreatedBy { get; set; } = "System";

        public DateTime? UpdatedAt { get; set; }

        [MaxLength(100)]
        public string? UpdatedBy { get; set; }

        // Navigation
        public DeliveryRunSheet? DeliveryRunSheet { get; set; }
        public ICollection<OptimasiRuteSegment> Segments { get; set; } = new List<OptimasiRuteSegment>();
    }
}
