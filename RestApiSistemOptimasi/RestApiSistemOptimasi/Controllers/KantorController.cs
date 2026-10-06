using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestApiSistemOptimasi.Data;
using RestApiSistemOptimasi.Models.DTOs;
using RestApiSistemOptimasi.Models.Entities;

namespace RestApiSistemOptimasi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class KantorController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ILogger<KantorController> _logger;

        public KantorController(AppDbContext context, ILogger<KantorController> logger)
        {
            _context = context;
            _logger = logger;
        }

        // GET: api/kantor
        // Hanya ada 1 kantor utama di sistem
        [HttpGet]
        public async Task<IActionResult> GetSingle()
        {
            var kantor = await _context.Kantors.AsNoTracking().FirstOrDefaultAsync();
            if (kantor == null)
            {
                // Inisialisasi default jika belum ada
                kantor = new Kantor
                {
                    KodeKantor = "KCU-40000",
                    NamaKantor = "Kantor Pos Bandung Asia Afrika",
                    Alamat = "Jl. Asia Afrika No. 49, Bandung",
                    Latitude = -6.92180000m,
                    Longitude = 107.60710000m,
                    CreatedAt = DateTime.UtcNow,
                    CreatedBy = "System"
                };
                _context.Kantors.Add(kantor);
                await _context.SaveChangesAsync();
            }

            return Ok(new KantorDto
            {
                Id = kantor.Id,
                KodeKantor = kantor.KodeKantor,
                NamaKantor = kantor.NamaKantor,
                Alamat = kantor.Alamat,
                Latitude = kantor.Latitude,
                Longitude = kantor.Longitude,
                CreatedAt = kantor.CreatedAt.ToLocalTime().ToString("dd/MM/yyyy HH:mm"),
                UpdatedAt = kantor.UpdatedAt.HasValue ? kantor.UpdatedAt.Value.ToLocalTime().ToString("dd/MM/yyyy HH:mm") : null
            });
        }

        // PUT: api/kantor
        // Hanya update kantor yang ada (tidak membuat baru)
        [HttpPut]
        public async Task<IActionResult> UpdateSingle([FromBody] UpdateKantorDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(new { success = false, message = "Data yang dikirim tidak valid." });

            var kantor = await _context.Kantors.FirstOrDefaultAsync();
            if (kantor == null)
            {
                kantor = new Kantor
                {
                    KodeKantor = dto.KodeKantor.Trim(),
                    NamaKantor = dto.NamaKantor.Trim(),
                    Alamat = dto.Alamat.Trim(),
                    Latitude = dto.Latitude,
                    Longitude = dto.Longitude,
                    CreatedAt = DateTime.UtcNow,
                    CreatedBy = "Branch Manager"
                };
                _context.Kantors.Add(kantor);
            }
            else
            {
                kantor.KodeKantor = dto.KodeKantor.Trim();
                kantor.NamaKantor = dto.NamaKantor.Trim();
                kantor.Alamat = dto.Alamat.Trim();
                kantor.Latitude = dto.Latitude;
                kantor.Longitude = dto.Longitude;
                kantor.UpdatedAt = DateTime.UtcNow;
                kantor.UpdatedBy = "Branch Manager";
            }

            await _context.SaveChangesAsync();
            _logger.LogInformation("Kantor diperbarui: {NamaKantor} ({Lat}, {Lng})", kantor.NamaKantor, kantor.Latitude, kantor.Longitude);

            return Ok(new { success = true, message = "Data kantor dan posisi peta berhasil diperbarui!" });
        }
    }
}
