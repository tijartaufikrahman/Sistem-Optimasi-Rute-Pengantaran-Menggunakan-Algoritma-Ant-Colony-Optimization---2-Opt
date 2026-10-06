using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RestApiSistemOptimasi.Models.Entities
{
    [Table("DeliveryRunSheets")]
    public class DeliveryRunSheet
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        public string NoDRS { get; set; } = string.Empty;

        [ForeignKey("Kantor")]
        public int KantorId { get; set; }

        [ForeignKey("BranchManager")]
        public int BranchManagerId { get; set; }

        [ForeignKey("Oranger")]
        public int OrangerId { get; set; }

        public DateOnly TanggalTugas { get; set; }

        public int TotalKiriman { get; set; } = 0;

        [Required]
        [MaxLength(30)]
        public string StatusDRS { get; set; } = "Assigned";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [MaxLength(100)]
        public string CreatedBy { get; set; } = "System";

        public DateTime? UpdatedAt { get; set; }

        [MaxLength(100)]
        public string? UpdatedBy { get; set; }

        // Navigation
        public Kantor? Kantor { get; set; }
        public User? BranchManager { get; set; }
        public User? Oranger { get; set; }

        public ICollection<DetailDeliveryRunSheet> Details { get; set; } = new List<DetailDeliveryRunSheet>();
        public ICollection<OptimasiRuteHistory> OptimasiHistories { get; set; } = new List<OptimasiRuteHistory>();
    }
}
