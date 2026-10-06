using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RestApiSistemOptimasi.Models.Entities
{
    [Table("Kantors")]
    public class Kantor
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(20)]
        public string KodeKantor { get; set; } = string.Empty;

        [Required]
        [MaxLength(100)]
        public string NamaKantor { get; set; } = string.Empty;

        [Required]
        public string Alamat { get; set; } = string.Empty;

        [Column(TypeName = "decimal(10,8)")]
        public decimal Latitude { get; set; }

        [Column(TypeName = "decimal(11,8)")]
        public decimal Longitude { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [MaxLength(100)]
        public string CreatedBy { get; set; } = "System";

        public DateTime? UpdatedAt { get; set; }

        [MaxLength(100)]
        public string? UpdatedBy { get; set; }

        // Navigation
        public ICollection<DeliveryRunSheet> DeliveryRunSheets { get; set; } = new List<DeliveryRunSheet>();
    }
}
