using System.ComponentModel.DataAnnotations;

namespace RestApiSistemOptimasi.Models.DTOs
{
    public class DrsDto
    {
        public int Id { get; set; }
        public string NoDRS { get; set; } = string.Empty;
        public int KantorId { get; set; }
        public string NamaKantor { get; set; } = string.Empty;
        public int BranchManagerId { get; set; }
        public string NamaBranchManager { get; set; } = string.Empty;
        public int OrangerId { get; set; }
        public string NamaOranger { get; set; } = string.Empty;
        public string TanggalTugas { get; set; } = string.Empty;
        public int TotalKiriman { get; set; }
        public string StatusDRS { get; set; } = "Assigned";
        public string CreatedAt { get; set; } = string.Empty;
        public string? UpdatedAt { get; set; }
        public bool HasOptimasi { get; set; } = false;
        public decimal? TotalJarakKm { get; set; }
        public decimal? TotalEstimasiMenit { get; set; }
        public string? PolylineFull { get; set; }
        public List<DrsOptimasiSegmentDto> Segments { get; set; } = new List<DrsOptimasiSegmentDto>();
        public List<DrsDetailItemDto> KirimanList { get; set; } = new List<DrsDetailItemDto>();
    }

    public class DrsOptimasiSegmentDto
    {
        public int UrutanKe { get; set; }
        public int? DetailDeliveryRunSheetId { get; set; }
        public decimal LatitudeAwal { get; set; }
        public decimal LongitudeAwal { get; set; }
        public decimal LatitudeAkhir { get; set; }
        public decimal LongitudeAkhir { get; set; }
        public decimal JarakKm { get; set; }
        public decimal EstimasiWaktuMenit { get; set; }
        public double DurasiDetik { get; set; }
        public string? PolylineSegmen { get; set; }
    }

    public class DrsDetailItemDto
    {
        public int Id { get; set; }
        public int ManifestId { get; set; }
        public int? NomorUrutan { get; set; }
        public string NomorKiriman { get; set; } = string.Empty;
        public string NamaPenerima { get; set; } = string.Empty;
        public string? TeleponPenerima { get; set; }
        public string AlamatTujuan { get; set; } = string.Empty;
        public decimal Latitude { get; set; }
        public decimal Longitude { get; set; }
        public decimal BeratKg { get; set; }
        public string StatusPengantaran { get; set; } = "Pending";
        public bool HasPod { get; set; } = false;
        public string? FotoPod { get; set; }
    }

    public class CreateDrsDto
    {
        [MaxLength(50)]
        public string? NoDRS { get; set; }

        public int? KantorId { get; set; }

        public int? BranchManagerId { get; set; }

        [Required(ErrorMessage = "Oranger wajib dipilih.")]
        public int OrangerId { get; set; }

        [Required(ErrorMessage = "Tanggal tugas wajib diisi.")]
        public string TanggalTugas { get; set; } = string.Empty;

        public string StatusDRS { get; set; } = "Assigned";
    }

    public class EditDrsDto
    {
        public int Id { get; set; }

        [Required(ErrorMessage = "No. DRS wajib diisi.")]
        [MaxLength(50)]
        public string NoDRS { get; set; } = string.Empty;

        [Required(ErrorMessage = "Oranger wajib dipilih.")]
        public int OrangerId { get; set; }

        [Required(ErrorMessage = "Tanggal tugas wajib diisi.")]
        public string TanggalTugas { get; set; } = string.Empty;

        public string StatusDRS { get; set; } = "Assigned";
    }

    public class OrangerOptionDto
    {
        public int Id { get; set; }
        public string NamaLengkap { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string RoleName { get; set; } = string.Empty;
        public int RoleType { get; set; }
    }

    public class ApproveDrsDto
    {
        public int OrangerId { get; set; }
    }

    public class ScanKirimanDto
    {
        [Required(ErrorMessage = "Nomor Kiriman wajib diisi.")]
        public string NomorKiriman { get; set; } = string.Empty;

        public int OrangerId { get; set; }
    }

    public class BatchSubmitKirimanDto
    {
        [Required(ErrorMessage = "Daftar nomor kiriman tidak boleh kosong.")]
        public List<string> NomorKirimanList { get; set; } = new List<string>();

        public int OrangerId { get; set; }
    }

    public class ClosingDrsDto
    {
        public int OrangerId { get; set; }
        public string? Catatan { get; set; }
    }

    public class RunOptimasiResponseDto
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public decimal TotalDistanceKm { get; set; }
        public decimal TotalDurationMenit { get; set; }
        public string PolylineFull { get; set; } = string.Empty;
        public List<int> OrderedDetailIds { get; set; } = new List<int>();
        public List<DrsOptimasiSegmentDto> Segments { get; set; } = new List<DrsOptimasiSegmentDto>();
    }

    public class SaveOptimasiRequestDto
    {
        public int DeliveryRunSheetId { get; set; }
        public decimal TotalJarakKm { get; set; }
        public decimal TotalEstimasiMenit { get; set; }
        public string PolylineFull { get; set; } = string.Empty;
        public List<DrsOptimasiSegmentDto> Segments { get; set; } = new List<DrsOptimasiSegmentDto>();
    }

    public class HasilOptimasiQueryDto
    {
        public int DrsId { get; set; }
    }

    public class HasilOptimasiResponseDto
    {
        public bool Success { get; set; }
        public bool HasOptimasi { get; set; }
        public int DrsId { get; set; }
        public string NoDrs { get; set; } = string.Empty;
        public string StatusDrs { get; set; } = string.Empty;
        public int TotalKiriman { get; set; }
        public decimal TotalJarakKm { get; set; }
        public decimal TotalEstimasiMenit { get; set; }
        public string PolylineFull { get; set; } = string.Empty;
        public List<DrsOptimasiSegmentDto> Segments { get; set; } = new List<DrsOptimasiSegmentDto>();
        public List<DrsDetailItemDto> KirimanList { get; set; } = new List<DrsDetailItemDto>();
        public DepotLocationDto? Depot { get; set; }
    }

    public class DepotLocationDto
    {
        public string NamaKantor { get; set; } = string.Empty;
        public double Latitude { get; set; }
        public double Longitude { get; set; }
    }
}
