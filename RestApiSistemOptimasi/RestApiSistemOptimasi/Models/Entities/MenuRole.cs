using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RestApiSistemOptimasi.Models.Entities
{
    [Table("Menu_Roles")]
    public class MenuRole
    {
        [Key]
        public int Id { get; set; }

        [ForeignKey("Role")]
        public int RoleId { get; set; }

        [Required]
        [MaxLength(100)]
        public string NamaMenu { get; set; } = string.Empty;

        [MaxLength(100)]
        public string? Icon { get; set; }

        [Required]
        [MaxLength(200)]
        public string Url { get; set; } = string.Empty;

        public int Urutan { get; set; } = 0;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [MaxLength(100)]
        public string CreatedBy { get; set; } = "System";

        public DateTime? UpdatedAt { get; set; }

        [MaxLength(100)]
        public string? UpdatedBy { get; set; }

        // Navigation
        public Role? Role { get; set; }
    }
}

