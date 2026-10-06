using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SystemOptimasi.Models.Entities
{
    [Table("Roles")]
    public class Role
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        public string NamaRole { get; set; } = string.Empty;

        [MaxLength(200)]
        public string? Deskripsi { get; set; }

        // Navigation
        public ICollection<User> Users { get; set; } = new List<User>();
        public ICollection<MenuRole> MenuRoles { get; set; } = new List<MenuRole>();
    }
}

