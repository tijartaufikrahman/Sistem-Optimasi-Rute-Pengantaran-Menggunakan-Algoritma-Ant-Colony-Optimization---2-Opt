using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RestApiSistemOptimasi.Models.Entities
{
    [Table("Roles")]
    public class Role
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        public string NamaRole { get; set; } = string.Empty;

        public int RoleType { get; set; } = 0; // 0 = Web (BM/Admin), 1 = Mobile (Oranger Kurir), 2 = All

        [MaxLength(200)]
        public string? Deskripsi { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        [MaxLength(100)]
        public string CreatedBy { get; set; } = "System";
        public DateTime? UpdatedAt { get; set; }
        [MaxLength(100)]
        public string? UpdatedBy { get; set; }

        // Navigation
        public ICollection<User> Users { get; set; } = new List<User>();
        public ICollection<MenuRole> MenuRoles { get; set; } = new List<MenuRole>();
    }
}

