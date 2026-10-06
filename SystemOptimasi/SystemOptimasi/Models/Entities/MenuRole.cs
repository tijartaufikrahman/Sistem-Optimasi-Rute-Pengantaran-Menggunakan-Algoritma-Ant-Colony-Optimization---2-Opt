using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SystemOptimasi.Models.Entities
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

        // Navigation
        public Role? Role { get; set; }
    }
}

