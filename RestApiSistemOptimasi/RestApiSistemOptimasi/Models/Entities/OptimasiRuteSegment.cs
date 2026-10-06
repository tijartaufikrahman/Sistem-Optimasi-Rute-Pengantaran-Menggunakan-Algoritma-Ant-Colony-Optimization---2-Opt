using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RestApiSistemOptimasi.Models.Entities
{
    [Table("OptimasiRuteSegments")]
    public class OptimasiRuteSegment
    {
        [Key]
        public int Id { get; set; }

        [ForeignKey("OptimasiRuteHistory")]
        public int OptimasiRuteHistoryId { get; set; }

        [ForeignKey("DetailDeliveryRunSheet")]
        public int? DetailDeliveryRunSheetId { get; set; }

        public int UrutanKe { get; set; }

        [Column(TypeName = "decimal(10,8)")]
        public decimal LatitudeAwal { get; set; }

        [Column(TypeName = "decimal(11,8)")]
        public decimal LongitudeAwal { get; set; }

        [Column(TypeName = "decimal(10,8)")]
        public decimal LatitudeAkhir { get; set; }

        [Column(TypeName = "decimal(11,8)")]
        public decimal LongitudeAkhir { get; set; }

        [Column(TypeName = "decimal(7,2)")]
        public decimal JarakKm { get; set; }

        [Column(TypeName = "decimal(7,2)")]
        public decimal EstimasiWaktuMenit { get; set; }

        public string? PolylineSegmen { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [MaxLength(100)]
        public string CreatedBy { get; set; } = "System";

        public DateTime? UpdatedAt { get; set; }

        [MaxLength(100)]
        public string? UpdatedBy { get; set; }

        // Navigation
        public OptimasiRuteHistory? OptimasiRuteHistory { get; set; }
        public DetailDeliveryRunSheet? DetailDeliveryRunSheet { get; set; }
    }
}
