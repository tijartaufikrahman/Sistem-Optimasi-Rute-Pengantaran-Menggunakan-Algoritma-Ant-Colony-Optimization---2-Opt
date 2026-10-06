using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestApiSistemOptimasi.Data;
using RestApiSistemOptimasi.Models.DTOs;
using RestApiSistemOptimasi.Models.Entities;

namespace RestApiSistemOptimasi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ManifestsController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ILogger<ManifestsController> _logger;

        public ManifestsController(AppDbContext context, ILogger<ManifestsController> logger)
        {
            _context = context;
            _logger = logger;
        }

        // GET: api/manifests
        [HttpGet]
        public async Task<IActionResult> GetAll([FromQuery] string? search, [FromQuery] string? status)
        {
            var query = _context.Manifests.AsNoTracking().AsQueryable();

            if (!string.IsNullOrWhiteSpace(status) && status != "Semua")
            {
                query = query.Where(m => m.StatusKiriman == status);
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.Trim();
                query = query.Where(m =>
                    m.NomorKiriman.Contains(s) ||
                    m.NamaPenerima.Contains(s) ||
                    m.AlamatTujuan.Contains(s) ||
                    (m.TeleponPenerima != null && m.TeleponPenerima.Contains(s))
                );
            }

            var list = await query
                .OrderByDescending(m => m.CreatedAt)
                .Select(m => new ManifestDto
                {
                    Id = m.Id,
                    NomorKiriman = m.NomorKiriman,
                    NamaPenerima = m.NamaPenerima,
                    TeleponPenerima = m.TeleponPenerima,
                    AlamatTujuan = m.AlamatTujuan,
                    Latitude = m.Latitude,
                    Longitude = m.Longitude,
                    BeratKg = m.BeratKg,
                    StatusKiriman = m.StatusKiriman,
                    CreatedAt = m.CreatedAt.ToLocalTime().ToString("dd/MM/yyyy HH:mm"),
                    UpdatedAt = m.UpdatedAt.HasValue ? m.UpdatedAt.Value.ToLocalTime().ToString("dd/MM/yyyy HH:mm") : null
                })
                .ToListAsync();

            return Ok(list);
        }

        // GET: api/manifests/{id}
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var m = await _context.Manifests.FindAsync(id);
            if (m == null)
                return NotFound(ApiResponse.Fail("Manifest tidak ditemukan."));

            return Ok(new ManifestDto
            {
                Id = m.Id,
                NomorKiriman = m.NomorKiriman,
                NamaPenerima = m.NamaPenerima,
                TeleponPenerima = m.TeleponPenerima,
                AlamatTujuan = m.AlamatTujuan,
                Latitude = m.Latitude,
                Longitude = m.Longitude,
                BeratKg = m.BeratKg,
                StatusKiriman = m.StatusKiriman,
                CreatedAt = m.CreatedAt.ToLocalTime().ToString("dd/MM/yyyy HH:mm"),
                UpdatedAt = m.UpdatedAt.HasValue ? m.UpdatedAt.Value.ToLocalTime().ToString("dd/MM/yyyy HH:mm") : null
            });
        }

        // POST: api/manifests
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateManifestDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(new { success = false, message = "Data tidak valid." });

            var exists = await _context.Manifests.AnyAsync(m => m.NomorKiriman == dto.NomorKiriman.Trim());
            if (exists)
                return BadRequest(new { success = false, message = $"Nomor kiriman '{dto.NomorKiriman}' sudah terdaftar." });

            var manifest = new Manifest
            {
                NomorKiriman = dto.NomorKiriman.Trim(),
                NamaPenerima = dto.NamaPenerima.Trim(),
                TeleponPenerima = dto.TeleponPenerima?.Trim(),
                AlamatTujuan = dto.AlamatTujuan.Trim(),
                Latitude = dto.Latitude,
                Longitude = dto.Longitude,
                BeratKg = dto.BeratKg,
                StatusKiriman = string.IsNullOrWhiteSpace(dto.StatusKiriman) ? "Manifest" : dto.StatusKiriman.Trim(),
                CreatedAt = DateTime.UtcNow,
                CreatedBy = "Branch Manager"
            };

            _context.Manifests.Add(manifest);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Manifest dibuat: {NomorKiriman}", manifest.NomorKiriman);
            return Ok(new { success = true, message = "Manifest berhasil ditambahkan.", data = manifest.Id });
        }

        // PUT: api/manifests/{id}
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] EditManifestDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(new { success = false, message = "Data tidak valid." });

            var manifest = await _context.Manifests.FindAsync(id);
            if (manifest == null)
                return NotFound(new { success = false, message = "Manifest tidak ditemukan." });

            var duplicate = await _context.Manifests.AnyAsync(m => m.NomorKiriman == dto.NomorKiriman.Trim() && m.Id != id);
            if (duplicate)
                return BadRequest(new { success = false, message = $"Nomor kiriman '{dto.NomorKiriman}' sudah digunakan di manifest lain." });

            manifest.NomorKiriman = dto.NomorKiriman.Trim();
            manifest.NamaPenerima = dto.NamaPenerima.Trim();
            manifest.TeleponPenerima = dto.TeleponPenerima?.Trim();
            manifest.AlamatTujuan = dto.AlamatTujuan.Trim();
            manifest.Latitude = dto.Latitude;
            manifest.Longitude = dto.Longitude;
            manifest.BeratKg = dto.BeratKg;
            manifest.StatusKiriman = string.IsNullOrWhiteSpace(dto.StatusKiriman) ? manifest.StatusKiriman : dto.StatusKiriman.Trim();
            manifest.UpdatedAt = DateTime.UtcNow;
            manifest.UpdatedBy = "Branch Manager";

            await _context.SaveChangesAsync();

            _logger.LogInformation("Manifest diperbarui: {Id}", id);
            return Ok(new { success = true, message = "Manifest berhasil diperbarui." });
        }

        // DELETE: api/manifests/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var manifest = await _context.Manifests.FindAsync(id);
            if (manifest == null)
                return NotFound(new { success = false, message = "Manifest tidak ditemukan." });

            // Cek apakah terhubung dengan DRS
            var usedInDrs = await _context.DetailDeliveryRunSheets.AnyAsync(d => d.ManifestId == id);
            if (usedInDrs)
                return BadRequest(new { success = false, message = "Manifest tidak dapat dihapus karena sudah terkait dengan Delivery Run Sheet (DRS)." });

            _context.Manifests.Remove(manifest);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Manifest dihapus: {Id}", id);
            return Ok(new { success = true, message = "Manifest berhasil dihapus." });
        }
    }
}
