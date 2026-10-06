using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RestApiSistemOptimasi.Models.Entities
{
    [Table("Users")]
    public class User
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(100)]
        public string NamaLengkap { get; set; } = string.Empty;

        /// <summary>Email untuk login dan identitas user</summary>
        [Required]
        [MaxLength(100)]
        public string Email { get; set; } = string.Empty;

        [Required]
        [MaxLength(255)]
        public string PasswordHash { get; set; } = string.Empty;

        [ForeignKey("Role")]
        public int RoleId { get; set; }

        public bool IsActive { get; set; } = true;

        public string? ResetPasswordToken { get; set; }

        public DateTime? ResetPasswordExpiry { get; set; }

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


