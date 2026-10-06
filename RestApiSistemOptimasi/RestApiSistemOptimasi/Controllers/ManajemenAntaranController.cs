using System.Globalization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestApiSistemOptimasi.Data;
using RestApiSistemOptimasi.Models.Entities;

namespace RestApiSistemOptimasi.Controllers
{
    [ApiController]
    [Route("api")]
    public class ManajemenAntaranController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IWebHostEnvironment _env;
        private readonly ILogger<ManajemenAntaranController> _logger;

        public ManajemenAntaranController(AppDbContext context, IWebHostEnvironment env, ILogger<ManajemenAntaranController> logger)
        {
            _context = context;
            _env = env;
            _logger = logger;
        }

        // POST: api/manajemen-antaran/update-status-pengiriman
        // Menerima multipart form data dari aplikasi mobile Flutter saat kurir/oranger mengantar paket
        [HttpPost("manajemen-antaran/update-status-pengiriman")]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> UpdateStatusPengiriman([FromForm] UpdateStatusPengirimanDto dto)
        {
            try
            {
                int UrutanId = dto.UrutanId;
                string Status = dto.Status;
                string? NamaPenerima = dto.NamaPenerima;
                string? StatusPenerima = dto.StatusPenerima;
                string? PodDateTime = dto.PodDateTime;
                IFormFile? PodPhoto = dto.PodPhoto;

                DateTime parsedPodDateTime = DateTime.UtcNow;
                if (!string.IsNullOrWhiteSpace(PodDateTime) && DateTime.TryParse(PodDateTime, out var dt))
                {
                    parsedPodDateTime = dt;
                }

                // Parse latitude & longitude dengan CultureInfo.InvariantCulture untuk mencegah culture formatting error
                decimal? parsedLat = null;
                if (!string.IsNullOrWhiteSpace(dto.PodLatitude))
                {
                    var latClean = dto.PodLatitude.Trim().Replace(',', '.');
                    if (decimal.TryParse(latClean, NumberStyles.Any, CultureInfo.InvariantCulture, out var vLat))
                    {
                        parsedLat = Math.Round(vLat, 8);
                    }
                }

                decimal? parsedLon = null;
                if (!string.IsNullOrWhiteSpace(dto.PodLongitude))
                {
                    var lonClean = dto.PodLongitude.Trim().Replace(',', '.');
                    if (decimal.TryParse(lonClean, NumberStyles.Any, CultureInfo.InvariantCulture, out var vLon))
                    {
                        parsedLon = Math.Round(vLon, 8);
                    }
                }

                // 1. UrutanId di Flutter merujuk pada DetailDeliveryRunSheet.Id
                var detail = await _context.DetailDeliveryRunSheets
                    .Include(d => d.Manifest)
                    .Include(d => d.ProofOfDelivery)
                    .FirstOrDefaultAsync(d => d.Id == UrutanId);

                // 2. Fallback jika UrutanId yang dikirim adalah ManifestId
                if (detail == null)
                {
                    detail = await _context.DetailDeliveryRunSheets
                        .Include(d => d.Manifest)
                        .Include(d => d.ProofOfDelivery)
                        .FirstOrDefaultAsync(d => d.ManifestId == UrutanId);
                }

                if (detail == null)
                {
                    _logger.LogWarning("UpdateStatusPengiriman: Detail DRS tidak ditemukan untuk ID/ManifestID: {Id}", UrutanId);
                    return NotFound(new { status = false, message = $"Data rincian tugas kiriman (ID: {UrutanId}) tidak ditemukan." });
                }

                // Normalisasi status pengantaran
                // Di Flutter: "delivered" atau "returned"
                string statusDelivery = "Delivered";
                if (!string.IsNullOrWhiteSpace(Status))
                {
                    if (Status.Equals("returned", StringComparison.OrdinalIgnoreCase))
                        statusDelivery = "Returned";
                    else if (Status.Equals("delivered", StringComparison.OrdinalIgnoreCase))
                        statusDelivery = "Delivered";
                    else
                        statusDelivery = Status;
                }

                // Simpan Foto Bukti (POD Photo) jika ada
                string photoFileName = string.Empty;
                if (PodPhoto != null && PodPhoto.Length > 0)
                {
                    var uploadsDir = Path.Combine(_env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot"), "uploads", "pod");
                    if (!Directory.Exists(uploadsDir))
                    {
                        Directory.CreateDirectory(uploadsDir);
                    }

                    var ext = Path.GetExtension(PodPhoto.FileName);
                    if (string.IsNullOrEmpty(ext)) ext = ".jpg";
                    photoFileName = $"POD_{detail.Id}_{DateTime.UtcNow.Ticks}{ext}";
                    var filePath = Path.Combine(uploadsDir, photoFileName);

                    using (var stream = new FileStream(filePath, FileMode.Create))
                    {
                        await PodPhoto.CopyToAsync(stream);
                    }
                }
                else if (detail.ProofOfDelivery != null && !string.IsNullOrEmpty(detail.ProofOfDelivery.Photo1))
                {
                    photoFileName = detail.ProofOfDelivery.Photo1;
                }
                else
                {
                    photoFileName = "NO_PHOTO";
                }

                // Format nama penerima dengan status hubungan penerima
                string namaPenerimaFinal = !string.IsNullOrWhiteSpace(NamaPenerima)
                    ? NamaPenerima
                    : (detail.Manifest?.NamaPenerima ?? "-");
                if (!string.IsNullOrWhiteSpace(StatusPenerima) && !namaPenerimaFinal.Contains(StatusPenerima, StringComparison.OrdinalIgnoreCase))
                {
                    namaPenerimaFinal = $"{namaPenerimaFinal} ({StatusPenerima})";
                }

                decimal finalLat = parsedLat ?? (detail.Manifest != null ? Math.Round(detail.Manifest.Latitude, 8) : 0m);
                decimal finalLon = parsedLon ?? (detail.Manifest != null ? Math.Round(detail.Manifest.Longitude, 8) : 0m);

                // Update atau Create data ProofOfDelivery
                var pod = detail.ProofOfDelivery ?? await _context.ProofOfDeliveries.FirstOrDefaultAsync(p => p.DetailDeliveryRunSheetId == detail.Id);
                if (pod == null)
                {
                    pod = new ProofOfDelivery
                    {
                        DetailDeliveryRunSheetId = detail.Id,
                        DetailDeliveryRunSheet = detail,
                        NamaPenerima = namaPenerimaFinal,
                        TelpPenerima = detail.Manifest?.TeleponPenerima,
                        AlamatPenerima = detail.Manifest?.AlamatTujuan ?? "-",
                        StatusDelivery = statusDelivery,
                        Latitude = finalLat,
                        Longitude = finalLon,
                        Photo1 = photoFileName,
                        CreatedAt = parsedPodDateTime,
                        CreatedBy = "Oranger (Mobile)"
                    };
                    detail.ProofOfDelivery = pod;
                    _context.ProofOfDeliveries.Add(pod);
                }
                else
                {
                    pod.NamaPenerima = namaPenerimaFinal;
                    pod.StatusDelivery = statusDelivery;
                    if (parsedLat.HasValue) pod.Latitude = parsedLat.Value;
                    if (parsedLon.HasValue) pod.Longitude = parsedLon.Value;
                    if (!string.IsNullOrEmpty(photoFileName) && photoFileName != "NO_PHOTO") pod.Photo1 = photoFileName;
                    pod.UpdatedAt = DateTime.UtcNow;
                    pod.UpdatedBy = "Oranger (Mobile)";
                }

                // Update Status Pengantaran di Detail DRS
                detail.StatusPengantaran = statusDelivery;
                detail.UpdatedAt = DateTime.UtcNow;
                detail.UpdatedBy = "Oranger (Mobile)";

                // Update Status Kiriman di Manifest
                if (detail.Manifest != null)
                {
                    detail.Manifest.StatusKiriman = statusDelivery;
                    detail.Manifest.UpdatedAt = DateTime.UtcNow;
                    detail.Manifest.UpdatedBy = "Oranger (Mobile)";
                }

                await _context.SaveChangesAsync();
                _logger.LogInformation("Status kiriman #{Id} berhasil diupdate menjadi {Status} dengan POD", detail.Id, statusDelivery);

                return Ok(new
                {
                    status = true,
                    message = "Status pengiriman dan data POD berhasil disimpan.",
                    data = new
                    {
                        detailId = detail.Id,
                        status = statusDelivery,
                        photo = photoFileName
                    }
                });
            }
            catch (Exception ex)
            {
                var baseEx = ex.GetBaseException() ?? ex;
                _logger.LogError(ex, "Error UpdateStatusPengiriman: {Message}", baseEx.Message);
                return StatusCode(500, new { status = false, message = "Terjadi kesalahan server: " + baseEx.Message });
            }
        }

        // POST: api/pod/cek-by-kiriman
        // Mengecek apakah paket kiriman sudah memiliki bukti POD
        [HttpPost("pod/cek-by-kiriman")]
        public async Task<IActionResult> CekPodByKiriman([FromBody] CekPodRequest request)
        {
            if (request == null || request.KirimanId <= 0)
            {
                return BadRequest(new { status = false, message = "KirimanId tidak valid." });
            }

            // Cari detail berdasarkan DetailDeliveryRunSheet.Id ATAU ManifestId
            var detail = await _context.DetailDeliveryRunSheets
                .Include(d => d.Manifest)
                .Include(d => d.ProofOfDelivery)
                .FirstOrDefaultAsync(d => d.Id == request.KirimanId || d.ManifestId == request.KirimanId);

            if (detail == null || detail.ProofOfDelivery == null)
            {
                return Ok(new { status = false, message = "Belum ada POD untuk kiriman ini.", data = (object?)null });
            }

            var pod = detail.ProofOfDelivery;
            return Ok(new
            {
                status = true,
                message = "Data POD ditemukan.",
                data = new
                {
                    id = pod.Id,
                    kirimanId = detail.Id,
                    namaPenerima = pod.NamaPenerima,
                    waktuPengantaran = pod.CreatedAt.ToLocalTime().ToString("yyyy-MM-ddTHH:mm:ss"),
                    koordinat = $"{pod.Latitude}, {pod.Longitude}",
                    latitude = (double)pod.Latitude,
                    longitude = (double)pod.Longitude,
                    fotoBukti = pod.Photo1,
                    nomorKiriman = detail.Manifest?.NomorKiriman ?? "-",
                    telepon = pod.TelpPenerima ?? detail.Manifest?.TeleponPenerima,
                    alamatPenerima = pod.AlamatPenerima,
                    kiriman = new
                    {
                        status = detail.StatusPengantaran,
                        namaPenerima = detail.Manifest?.NamaPenerima ?? pod.NamaPenerima
                    }
                }
            });
        }

        // GET: api/pod/view/{fileName}
        // Menampilkan atau mengunduh foto bukti POD
        [HttpGet("pod/view/{fileName}")]
        public IActionResult ViewPodPhoto(string fileName)
        {
            if (string.IsNullOrWhiteSpace(fileName)) return NotFound();

            var uploadsDir = Path.Combine(_env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot"), "uploads", "pod");
            var filePath = Path.Combine(uploadsDir, fileName);

            if (!System.IO.File.Exists(filePath))
            {
                return NotFound();
            }

            var contentType = "image/jpeg";
            if (fileName.EndsWith(".png", StringComparison.OrdinalIgnoreCase))
                contentType = "image/png";

            return PhysicalFile(filePath, contentType);
        }

        // PUT: api/manajemen-antaran/selesaikan-penugasan/{id}
        // Endpoint pelengkap closing penugasan jika Flutter memanggil selesaikanPenugasan
        [HttpPut("manajemen-antaran/selesaikan-penugasan/{id}")]
        public async Task<IActionResult> SelesaikanPenugasan(int id)
        {
            var drs = await _context.DeliveryRunSheets
                .Include(d => d.Details)
                    .ThenInclude(dt => dt.Manifest)
                .FirstOrDefaultAsync(d => d.Id == id);

            if (drs == null)
            {
                return NotFound(new { success = false, message = "DRS tidak ditemukan." });
            }

            drs.StatusDRS = "Completed";
            drs.UpdatedAt = DateTime.UtcNow;
            drs.UpdatedBy = "Oranger (Closing)";

            // Update kiriman yang masih 'On Delivery' atau 'Pending' menjadi 'Delivered' / closing state
            foreach (var dt in drs.Details)
            {
                if (dt.StatusPengantaran == "On Delivery" || dt.StatusPengantaran == "Pending")
                {
                    dt.StatusPengantaran = "Delivered";
                    dt.UpdatedAt = DateTime.UtcNow;
                    dt.UpdatedBy = "Oranger (Closing)";

                    if (dt.Manifest != null)
                    {
                        dt.Manifest.StatusKiriman = "Delivered";
                        dt.Manifest.UpdatedAt = DateTime.UtcNow;
                        dt.Manifest.UpdatedBy = "Oranger (Closing)";
                    }
                }
            }

            await _context.SaveChangesAsync();
            return Ok(new { success = true, message = "Penugasan DRS berhasil diselesaikan." });
        }
    }

    public class CekPodRequest
    {
        public int KirimanId { get; set; }
    }

    public class UpdateStatusPengirimanDto
    {
        public int UrutanId { get; set; }
        public string Status { get; set; } = string.Empty;
        public string? NamaPenerima { get; set; }
        public string? StatusPenerima { get; set; }
        public string? PodLatitude { get; set; }
        public string? PodLongitude { get; set; }
        public string? PodDateTime { get; set; }
        public IFormFile? PodPhoto { get; set; }
    }
}
