using System.ComponentModel.DataAnnotations;

namespace RestApiSistemOptimasi.Models.DTOs
{
    public class ManifestDto
    {
        public int Id { get; set; }
        public string NomorKiriman { get; set; } = string.Empty;
        public string NamaPenerima { get; set; } = string.Empty;
        public string? TeleponPenerima { get; set; }
        public string AlamatTujuan { get; set; } = string.Empty;
        public decimal Latitude { get; set; }
        public decimal Longitude { get; set; }
        public decimal BeratKg { get; set; }
        public string StatusKiriman { get; set; } = "Manifest";
        public string CreatedAt { get; set; } = string.Empty;
        public string? UpdatedAt { get; set; }
    }

    public class CreateManifestDto
    {
        [Required(ErrorMessage = "Nomor kiriman wajib diisi.")]
        [MaxLength(50)]
        public string NomorKiriman { get; set; } = string.Empty;

        [Required(ErrorMessage = "Nama penerima wajib diisi.")]
        [MaxLength(100)]
        public string NamaPenerima { get; set; } = string.Empty;

        [MaxLength(20)]
        public string? TeleponPenerima { get; set; }

        [Required(ErrorMessage = "Alamat tujuan wajib diisi.")]
        public string AlamatTujuan { get; set; } = string.Empty;

        public decimal Latitude { get; set; }
        public decimal Longitude { get; set; }

        public decimal BeratKg { get; set; } = 0;

        public string StatusKiriman { get; set; } = "Manifest";
    }

    public class EditManifestDto
    {
        public int Id { get; set; }

        [Required(ErrorMessage = "Nomor kiriman wajib diisi.")]
        [MaxLength(50)]
        public string NomorKiriman { get; set; } = string.Empty;

        [Required(ErrorMessage = "Nama penerima wajib diisi.")]
        [MaxLength(100)]
        public string NamaPenerima { get; set; } = string.Empty;

        [MaxLength(20)]
        public string? TeleponPenerima { get; set; }

        [Required(ErrorMessage = "Alamat tujuan wajib diisi.")]
        public string AlamatTujuan { get; set; } = string.Empty;

        public decimal Latitude { get; set; }
        public decimal Longitude { get; set; }

        public decimal BeratKg { get; set; } = 0;

        public string StatusKiriman { get; set; } = "Manifest";
    }
}
