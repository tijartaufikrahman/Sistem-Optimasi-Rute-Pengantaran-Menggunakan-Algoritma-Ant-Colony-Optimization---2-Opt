using System.ComponentModel.DataAnnotations;

namespace RestApiSistemOptimasi.Models.DTOs
{
    public class KantorDto
    {
        public int Id { get; set; }
        public string KodeKantor { get; set; } = string.Empty;
        public string NamaKantor { get; set; } = string.Empty;
        public string Alamat { get; set; } = string.Empty;
        public decimal Latitude { get; set; }
        public decimal Longitude { get; set; }
        public string CreatedAt { get; set; } = string.Empty;
        public string? UpdatedAt { get; set; }
    }

    public class UpdateKantorDto
    {
        [Required(ErrorMessage = "Kode kantor wajib diisi.")]
        [MaxLength(20)]
        public string KodeKantor { get; set; } = string.Empty;

        [Required(ErrorMessage = "Nama kantor wajib diisi.")]
        [MaxLength(100)]
        public string NamaKantor { get; set; } = string.Empty;

        [Required(ErrorMessage = "Alamat wajib diisi.")]
        public string Alamat { get; set; } = string.Empty;

        public decimal Latitude { get; set; }
        public decimal Longitude { get; set; }
    }
}
