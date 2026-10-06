using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RestApiSistemOptimasi.Models.Entities
{
    [Table("DetailDeliveryRunSheets")]
    public class DetailDeliveryRunSheet
    {
        [Key]
        public int Id { get; set; }

        [ForeignKey("DeliveryRunSheet")]
        public int DeliveryRunSheetId { get; set; }

        [ForeignKey("Manifest")]
        public int ManifestId { get; set; }

        [Required]
        [MaxLength(30)]
        public string StatusPengantaran { get; set; } = "Pending";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [MaxLength(100)]
        public string CreatedBy { get; set; } = "System";

        public DateTime? UpdatedAt { get; set; }

        [MaxLength(100)]
        public string? UpdatedBy { get; set; }

        // Navigation
        public DeliveryRunSheet? DeliveryRunSheet { get; set; }
        public Manifest? Manifest { get; set; }
        public ProofOfDelivery? ProofOfDelivery { get; set; }
    }
}
