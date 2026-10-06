using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;
using System.Text;
using RestApiSistemOptimasi.Data;
using RestApiSistemOptimasi.Models.DTOs;
using RestApiSistemOptimasi.Models.Entities;

namespace RestApiSistemOptimasi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class DrsController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ILogger<DrsController> _logger;

        public DrsController(AppDbContext context, ILogger<DrsController> logger)
        {
            _context = context;
            _logger = logger;
        }

        // GET: api/drs
        [HttpGet]
        public async Task<IActionResult> GetAll(
            [FromQuery] string? search,
            [FromQuery] string? status,
            [FromQuery] int? orangerId,
            [FromQuery] string? tanggal,
            [FromQuery] string? tglAwal,
            [FromQuery] string? tglAkhir)
        {
            var query = _context.DeliveryRunSheets
                .AsNoTracking()
                .Include(d => d.Kantor)
                .Include(d => d.BranchManager)
                .Include(d => d.Oranger)
                .AsQueryable();

            if (orangerId.HasValue && orangerId.Value > 0)
            {
                query = query.Where(d => d.OrangerId == orangerId.Value);
            }

            // Filter Rentang Tanggal (tglAwal & tglAkhir) atau Tanggal Tunggal
            if (!string.IsNullOrWhiteSpace(tglAwal) && DateOnly.TryParse(tglAwal, out var parsedAwal))
            {
                query = query.Where(d => d.TanggalTugas >= parsedAwal);
            }
            if (!string.IsNullOrWhiteSpace(tglAkhir) && DateOnly.TryParse(tglAkhir, out var parsedAkhir))
            {
                query = query.Where(d => d.TanggalTugas <= parsedAkhir);
            }
            if (string.IsNullOrWhiteSpace(tglAwal) && string.IsNullOrWhiteSpace(tglAkhir) && !string.IsNullOrWhiteSpace(tanggal))
            {
                if (DateOnly.TryParse(tanggal, out var tglOnly))
                {
                    query = query.Where(d => d.TanggalTugas == tglOnly);
                }
            }

            if (!string.IsNullOrWhiteSpace(status) && status != "Semua")
            {
                query = query.Where(d => d.StatusDRS == status);
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.Trim();
                query = query.Where(d =>
                    d.NoDRS.Contains(s) ||
                    (d.Oranger != null && d.Oranger.NamaLengkap.Contains(s)) ||
                    (d.Kantor != null && d.Kantor.NamaKantor.Contains(s))
                );
            }

            var list = await query
                .OrderByDescending(d => d.CreatedAt)
                .Select(d => new DrsDto
                {
                    Id = d.Id,
                    NoDRS = d.NoDRS,
                    KantorId = d.KantorId,
                    NamaKantor = d.Kantor != null ? d.Kantor.NamaKantor : "-",
                    BranchManagerId = d.BranchManagerId,
                    NamaBranchManager = d.BranchManager != null ? d.BranchManager.NamaLengkap : "-",
                    OrangerId = d.OrangerId,
                    NamaOranger = d.Oranger != null ? d.Oranger.NamaLengkap : "-",
                    TanggalTugas = d.TanggalTugas.ToString("yyyy-MM-dd"),
                    TotalKiriman = d.TotalKiriman,
                    StatusDRS = d.StatusDRS,
                    CreatedAt = d.CreatedAt.ToLocalTime().ToString("dd/MM/yyyy HH:mm"),
                    UpdatedAt = d.UpdatedAt.HasValue ? d.UpdatedAt.Value.ToLocalTime().ToString("dd/MM/yyyy HH:mm") : null,
                    HasOptimasi = d.OptimasiHistories.Any()
                })
                .ToListAsync();

            return Ok(list);
        }

        // GET: api/drs/{id}
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var d = await _context.DeliveryRunSheets
                .AsNoTracking()
                .Include(x => x.Kantor)
                .Include(x => x.BranchManager)
                .Include(x => x.Oranger)
                .FirstOrDefaultAsync(x => x.Id == id);

            if (d == null)
                return NotFound(ApiResponse.Fail("DRS tidak ditemukan."));

            var latestOpt = await _context.OptimasiRuteHistories
                .AsNoTracking()
                .Where(oh => oh.DeliveryRunSheetId == id)
                .OrderByDescending(o => o.ExecutedAt)
                .Include(oh => oh.Segments)
                .FirstOrDefaultAsync();

            var segmentsDto = new List<DrsOptimasiSegmentDto>();
            var orderMap = new Dictionary<int, int>(); // DetailDeliveryRunSheetId -> UrutanKe

            if (latestOpt != null && latestOpt.Segments != null)
            {
                foreach (var seg in latestOpt.Segments.OrderBy(s => s.UrutanKe))
                {
                    segmentsDto.Add(new DrsOptimasiSegmentDto
                    {
                        UrutanKe = seg.UrutanKe,
                        DetailDeliveryRunSheetId = seg.DetailDeliveryRunSheetId,
                        LatitudeAwal = seg.LatitudeAwal,
                        LongitudeAwal = seg.LongitudeAwal,
                        LatitudeAkhir = seg.LatitudeAkhir,
                        LongitudeAkhir = seg.LongitudeAkhir,
                        JarakKm = seg.JarakKm,
                        EstimasiWaktuMenit = seg.EstimasiWaktuMenit,
                        PolylineSegmen = seg.PolylineSegmen
                    });

                    if (seg.DetailDeliveryRunSheetId.HasValue)
                    {
                        orderMap[seg.DetailDeliveryRunSheetId.Value] = seg.UrutanKe;
                    }
                }
            }

            var details = await _context.DetailDeliveryRunSheets
                .AsNoTracking()
                .Where(dt => dt.DeliveryRunSheetId == id)
                .Include(dt => dt.Manifest)
                .Include(dt => dt.ProofOfDelivery)
                .ToListAsync();

            var kirimanList = details.Select(dt => new DrsDetailItemDto
            {
                Id = dt.Id,
                ManifestId = dt.ManifestId,
                NomorUrutan = orderMap.ContainsKey(dt.Id) ? orderMap[dt.Id] : null,
                NomorKiriman = dt.Manifest != null ? dt.Manifest.NomorKiriman : "-",
                NamaPenerima = dt.Manifest != null ? dt.Manifest.NamaPenerima : "-",
                TeleponPenerima = dt.Manifest?.TeleponPenerima,
                AlamatTujuan = dt.Manifest != null ? dt.Manifest.AlamatTujuan : "-",
                Latitude = dt.Manifest?.Latitude ?? 0,
                Longitude = dt.Manifest?.Longitude ?? 0,
                BeratKg = dt.Manifest?.BeratKg ?? 0,
                StatusPengantaran = dt.StatusPengantaran,
                HasPod = dt.ProofOfDelivery != null,
                FotoPod = dt.ProofOfDelivery?.Photo1
            }).ToList();

            // Jika sudah dioptimasi, urutkan kirimanList sesuai nomor urutan
            if (orderMap.Any())
            {
                kirimanList = kirimanList
                    .OrderBy(k => k.NomorUrutan ?? 999999)
                    .ThenBy(k => k.Id)
                    .ToList();
            }

            return Ok(new DrsDto
            {
                Id = d.Id,
                NoDRS = d.NoDRS,
                KantorId = d.KantorId,
                NamaKantor = d.Kantor != null ? d.Kantor.NamaKantor : "-",
                BranchManagerId = d.BranchManagerId,
                NamaBranchManager = d.BranchManager != null ? d.BranchManager.NamaLengkap : "-",
                OrangerId = d.OrangerId,
                NamaOranger = d.Oranger != null ? d.Oranger.NamaLengkap : "-",
                TanggalTugas = d.TanggalTugas.ToString("yyyy-MM-dd"),
                TotalKiriman = d.TotalKiriman,
                StatusDRS = d.StatusDRS,
                CreatedAt = d.CreatedAt.ToLocalTime().ToString("dd/MM/yyyy HH:mm"),
                UpdatedAt = d.UpdatedAt.HasValue ? d.UpdatedAt.Value.ToLocalTime().ToString("dd/MM/yyyy HH:mm") : null,
                HasOptimasi = latestOpt != null,
                TotalJarakKm = latestOpt?.TotalJarakKm,
                TotalEstimasiMenit = latestOpt?.TotalEstimasiMenit,
                PolylineFull = latestOpt?.PolylineFull,
                Segments = segmentsDto,
                KirimanList = kirimanList
            });
        }

        // GET: api/drs/orangers
        // Mengambil daftar user yang RoleType-nya 1 (Mobile) atau 2 (All)
        [HttpGet("orangers")]
        public async Task<IActionResult> GetEligibleOrangers()
        {
            var orangers = await _context.Users
                .Include(u => u.Role)
                .Where(u => u.IsActive && u.Role != null && (u.Role.RoleType == 1 || u.Role.RoleType == 2))
                .OrderBy(u => u.NamaLengkap)
                .Select(u => new OrangerOptionDto
                {
                    Id = u.Id,
                    NamaLengkap = u.NamaLengkap,
                    Email = u.Email,
                    RoleName = u.Role != null ? u.Role.NamaRole : "-",
                    RoleType = u.Role != null ? u.Role.RoleType : 0
                })
                .ToListAsync();

            return Ok(orangers);
        }

        // GET: api/drs/generate-number
        // Format: {KodeKantor}-{yyyyMMddHHmm}
        [HttpGet("generate-number")]
        public async Task<IActionResult> GenerateDrsNumber()
        {
            var kantor = await _context.Kantors.AsNoTracking().FirstOrDefaultAsync();
            var kodeKantor = !string.IsNullOrWhiteSpace(kantor?.KodeKantor) ? kantor.KodeKantor.Trim() : "KCP44188";
            
            // Format waktu WIB / Local (yyyyMMddHHmm)
            var timeStamp = DateTime.Now.ToString("yyyyMMddHHmm");
            var noDrs = $"{kodeKantor}-{timeStamp}";

            return Ok(new { noDRS = noDrs, kodeKantor = kodeKantor });
        }

        // POST: api/drs
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateDrsDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(new { success = false, message = "Data tidak valid." });

            // Validasi Oranger (harus memiliki RoleType 1 atau 2)
            var oranger = await _context.Users
                .Include(u => u.Role)
                .FirstOrDefaultAsync(u => u.Id == dto.OrangerId);

            if (oranger == null || oranger.Role == null || (oranger.Role.RoleType != 1 && oranger.Role.RoleType != 2))
            {
                return BadRequest(new { success = false, message = "User yang dipilih bukan merupakan Oranger yang valid (RoleType harus 1 atau 2)." });
            }

            // Ambil Kantor utama
            var kantor = await _context.Kantors.FirstOrDefaultAsync();
            if (kantor == null)
            {
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

            var finalNoDrs = !string.IsNullOrWhiteSpace(dto.NoDRS) 
                ? dto.NoDRS.Trim() 
                : $"{kantor.KodeKantor}-{DateTime.Now:yyyyMMddHHmm}";

            var exists = await _context.DeliveryRunSheets.AnyAsync(d => d.NoDRS == finalNoDrs);
            if (exists)
                return BadRequest(new { success = false, message = $"No. DRS '{finalNoDrs}' sudah terdaftar." });

            // Ambil Branch Manager (default ID 1)
            var bmId = dto.BranchManagerId.GetValueOrDefault(1);

            DateOnly tanggal;
            if (!DateOnly.TryParse(dto.TanggalTugas, out tanggal))
            {
                tanggal = DateOnly.FromDateTime(DateTime.Today);
            }

            var drs = new DeliveryRunSheet
            {
                NoDRS = finalNoDrs,
                KantorId = kantor.Id,
                BranchManagerId = bmId,
                OrangerId = dto.OrangerId,
                TanggalTugas = tanggal,
                TotalKiriman = 0,
                StatusDRS = string.IsNullOrWhiteSpace(dto.StatusDRS) ? "Assigned" : dto.StatusDRS.Trim(),
                CreatedAt = DateTime.UtcNow,
                CreatedBy = "Branch Manager"
            };

            _context.DeliveryRunSheets.Add(drs);
            await _context.SaveChangesAsync();

            _logger.LogInformation("DRS dibuat: {NoDRS}", drs.NoDRS);
            return Ok(new { success = true, message = "Delivery Run Sheet berhasil dibuat.", data = drs.Id });
        }

        // PUT: api/drs/{id}
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] EditDrsDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(new { success = false, message = "Data tidak valid." });

            var drs = await _context.DeliveryRunSheets.FindAsync(id);
            if (drs == null)
                return NotFound(new { success = false, message = "DRS tidak ditemukan." });

            var duplicate = await _context.DeliveryRunSheets.AnyAsync(d => d.NoDRS == dto.NoDRS.Trim() && d.Id != id);
            if (duplicate)
                return BadRequest(new { success = false, message = $"No. DRS '{dto.NoDRS}' sudah digunakan di DRS lain." });

            // Validasi Oranger
            var oranger = await _context.Users
                .Include(u => u.Role)
                .FirstOrDefaultAsync(u => u.Id == dto.OrangerId);

            if (oranger == null || oranger.Role == null || (oranger.Role.RoleType != 1 && oranger.Role.RoleType != 2))
            {
                return BadRequest(new { success = false, message = "User yang dipilih bukan merupakan Oranger yang valid (RoleType harus 1 atau 2)." });
            }

            DateOnly tanggal;
            if (!DateOnly.TryParse(dto.TanggalTugas, out tanggal))
            {
                tanggal = drs.TanggalTugas;
            }

            drs.NoDRS = dto.NoDRS.Trim();
            drs.OrangerId = dto.OrangerId;
            drs.TanggalTugas = tanggal;
            drs.StatusDRS = string.IsNullOrWhiteSpace(dto.StatusDRS) ? drs.StatusDRS : dto.StatusDRS.Trim();
            drs.UpdatedAt = DateTime.UtcNow;
            drs.UpdatedBy = "Branch Manager";

            await _context.SaveChangesAsync();

            _logger.LogInformation("DRS diperbarui: {Id}", id);
            return Ok(new { success = true, message = "Delivery Run Sheet berhasil diperbarui." });
        }

        // POST: api/drs/{id}/approve
        // Oranger menyetujui / menerima lembar tugas DRS
        [HttpPost("{id}/approve")]
        public async Task<IActionResult> ApproveDrs(int id, [FromBody] ApproveDrsDto? dto)
        {
            var drs = await _context.DeliveryRunSheets.FirstOrDefaultAsync(d => d.Id == id);
            if (drs == null)
                return NotFound(new { success = false, message = "DRS tidak ditemukan." });

            if (dto != null && dto.OrangerId > 0 && drs.OrangerId != dto.OrangerId)
            {
                return BadRequest(new { success = false, message = "DRS ini bukan ditugaskan untuk Anda." });
            }

            if (drs.StatusDRS == "Completed")
            {
                return BadRequest(new { success = false, message = "DRS sudah selesai (Completed)." });
            }

            drs.StatusDRS = "In Progress";
            drs.UpdatedAt = DateTime.UtcNow;
            drs.UpdatedBy = "Oranger (Approved)";

            await _context.SaveChangesAsync();
            _logger.LogInformation("DRS #{Id} disetujui / In Progress oleh Oranger #{OrangerId}", id, drs.OrangerId);

            return Ok(new { success = true, message = "Delivery Run Sheet berhasil disetujui. Status kini In Progress.", status = drs.StatusDRS });
        }

        // POST: api/drs/{id}/scan-kiriman
        // Scan nomor kiriman untuk dimasukkan/diambil ke DRS ini.
        // Status kiriman di tabel Manifests diubah dari 'Manifest' menjadi 'On Delivery'.
        [HttpPost("{id}/scan-kiriman")]
        public async Task<IActionResult> ScanKiriman(int id, [FromBody] ScanKirimanDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.NomorKiriman))
                return BadRequest(new { success = false, message = "Nomor kiriman wajib diisi." });

            var drs = await _context.DeliveryRunSheets
                .Include(d => d.Details)
                .FirstOrDefaultAsync(d => d.Id == id);

            if (drs == null)
                return NotFound(new { success = false, message = "DRS tidak ditemukan." });

            if (drs.StatusDRS == "Completed" || drs.StatusDRS == "Canceled")
            {
                return BadRequest(new { success = false, message = $"DRS berstatus {drs.StatusDRS}, tidak dapat mengambil kiriman baru." });
            }

            var cleanNo = dto.NomorKiriman.Trim();
            var manifest = await _context.Manifests.FirstOrDefaultAsync(m => m.NomorKiriman == cleanNo);
            if (manifest == null)
            {
                return NotFound(new { success = false, message = $"Kiriman dengan nomor '{cleanNo}' tidak ditemukan di database." });
            }

            // Cek apakah sudah terdaftar di DRS ini
            var alreadyInThisDrs = drs.Details.Any(dt => dt.ManifestId == manifest.Id);
            if (alreadyInThisDrs)
            {
                return BadRequest(new { success = false, message = $"Kiriman '{cleanNo}' sudah terdaftar dalam lembar tugas DRS ini." });
            }

            // Tambahkan ke DetailDeliveryRunSheets
            var detail = new DetailDeliveryRunSheet
            {
                DeliveryRunSheetId = drs.Id,
                ManifestId = manifest.Id,
                StatusPengantaran = "On Delivery",
                CreatedAt = DateTime.UtcNow,
                CreatedBy = "Oranger (Scan)"
            };
            _context.DetailDeliveryRunSheets.Add(detail);

            // Update status kiriman di tabel Manifests menjadi 'On Delivery'
            manifest.StatusKiriman = "On Delivery";
            manifest.UpdatedAt = DateTime.UtcNow;
            manifest.UpdatedBy = "Oranger (Scan)";

            // Update total kiriman di DRS
            drs.TotalKiriman = drs.Details.Count + 1;
            if (drs.StatusDRS == "Assigned")
            {
                drs.StatusDRS = "In Progress";
            }
            drs.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            _logger.LogInformation("Kiriman {NomorKiriman} berhasil di-scan & diambil ke DRS #{DrsId}", cleanNo, drs.Id);

            return Ok(new
            {
                success = true,
                message = $"Kiriman '{cleanNo}' berhasil diambil. Status kiriman kini 'On Delivery'.",
                data = new
                {
                    detailId = detail.Id,
                    manifestId = manifest.Id,
                    nomorKiriman = manifest.NomorKiriman,
                    namaPenerima = manifest.NamaPenerima,
                    alamatTujuan = manifest.AlamatTujuan,
                    statusKiriman = manifest.StatusKiriman,
                    totalKirimanDrs = drs.TotalKiriman
                }
            });
        }

        // GET: api/drs/{id}/check-kiriman?no={nomorKiriman}
        // Mengecek apakah kiriman ada di database dan berstatus 'Manifest' sebelum ditambahkan ke antrian scan
        [HttpGet("{id}/check-kiriman")]
        public async Task<IActionResult> CheckKiriman(int id, [FromQuery] string no)
        {
            if (string.IsNullOrWhiteSpace(no))
                return BadRequest(new { success = false, message = "Nomor kiriman wajib diisi." });

            var cleanNo = no.Trim();
            var manifest = await _context.Manifests.AsNoTracking().FirstOrDefaultAsync(m => m.NomorKiriman == cleanNo);
            if (manifest == null)
            {
                return NotFound(new { success = false, message = $"Nomor kiriman '{cleanNo}' tidak terdaftar di database." });
            }

            if (manifest.StatusKiriman != "Manifest")
            {
                return BadRequest(new { success = false, message = $"Kiriman '{cleanNo}' berstatus '{manifest.StatusKiriman}', hanya kiriman berstatus 'Manifest' yang dapat diambil." });
            }

            // Cek apakah sudah terdaftar di DRS ini
            var alreadyInDrs = await _context.DetailDeliveryRunSheets.AnyAsync(dt => dt.DeliveryRunSheetId == id && dt.ManifestId == manifest.Id);
            if (alreadyInDrs)
            {
                return BadRequest(new { success = false, message = $"Kiriman '{cleanNo}' sudah pernah dimasukkan ke dalam DRS ini." });
            }

            return Ok(new
            {
                success = true,
                message = "Kiriman valid dan siap diambil.",
                data = new
                {
                    id = manifest.Id,
                    nomorKiriman = manifest.NomorKiriman,
                    namaPenerima = manifest.NamaPenerima,
                    alamatTujuan = manifest.AlamatTujuan,
                    teleponPenerima = manifest.TeleponPenerima,
                    statusKiriman = manifest.StatusKiriman,
                    beratKg = manifest.BeratKg
                }
            });
        }

        // POST: api/drs/{id}/batch-submit-kiriman
        // Submit seluruh nomor kiriman hasil scan sekaligus.
        // Kiriman di tabel Manifests diubah menjadi 'On Delivery', ditambahkan ke DetailDeliveryRunSheets,
        // dan DRS diupdate total kirimannya serta statusnya menjadi 'In Progress'.
        [HttpPost("{id}/batch-submit-kiriman")]
        public async Task<IActionResult> BatchSubmitKiriman(int id, [FromBody] BatchSubmitKirimanDto dto)
        {
            if (dto.NomorKirimanList == null || !dto.NomorKirimanList.Any())
                return BadRequest(new { success = false, message = "Daftar nomor kiriman kosong." });

            var drs = await _context.DeliveryRunSheets
                .Include(d => d.Details)
                .FirstOrDefaultAsync(d => d.Id == id);

            if (drs == null)
                return NotFound(new { success = false, message = "DRS tidak ditemukan." });

            if (drs.StatusDRS == "Completed" || drs.StatusDRS == "Canceled")
            {
                return BadRequest(new { success = false, message = $"DRS berstatus '{drs.StatusDRS}', tidak dapat mengambil kiriman." });
            }

            // Ambil nomor yang unik (cegah duplikat dalam batch)
            var cleanNumbers = dto.NomorKirimanList
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Select(x => x.Trim())
                .Distinct()
                .ToList();

            var manifests = await _context.Manifests
                .Where(m => cleanNumbers.Contains(m.NomorKiriman))
                .ToListAsync();

            int insertedCount = 0;
            var existingManifestIds = drs.Details.Select(dt => dt.ManifestId).ToHashSet();

            foreach (var m in manifests)
            {
                if (!existingManifestIds.Contains(m.Id))
                {
                    var detail = new DetailDeliveryRunSheet
                    {
                        DeliveryRunSheetId = drs.Id,
                        ManifestId = m.Id,
                        StatusPengantaran = "On Delivery",
                        CreatedAt = DateTime.UtcNow,
                        CreatedBy = "Oranger (Batch Scan)"
                    };
                    _context.DetailDeliveryRunSheets.Add(detail);
                    existingManifestIds.Add(m.Id);

                    // Update status kiriman di Manifest
                    m.StatusKiriman = "On Delivery";
                    m.UpdatedAt = DateTime.UtcNow;
                    m.UpdatedBy = "Oranger (Batch Scan)";

                    insertedCount++;
                }
            }

            drs.TotalKiriman = drs.Details.Count + insertedCount;
            if (drs.StatusDRS == "Assigned")
            {
                drs.StatusDRS = "In Progress";
            }
            drs.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            _logger.LogInformation("Batch scan: {Count} kiriman berhasil dimasukkan ke DRS #{Id}", insertedCount, drs.Id);

            return Ok(new
            {
                success = true,
                message = $"{insertedCount} kiriman berhasil disimpan ke lembar tugas DRS. Status kiriman kini 'On Delivery'.",
                totalKiriman = drs.TotalKiriman,
                statusDRS = drs.StatusDRS
            });
        }

        // POST: api/drs/{id}/closing
        // Oranger melakukan closing tugas DRS. Mengubah StatusDRS menjadi 'Completed'.
        [HttpPost("{id}/closing")]
        public async Task<IActionResult> ClosingDrs(int id, [FromBody] ClosingDrsDto? dto)
        {
            var drs = await _context.DeliveryRunSheets
                .Include(d => d.Details)
                    .ThenInclude(dt => dt.Manifest)
                .FirstOrDefaultAsync(d => d.Id == id);

            if (drs == null)
                return NotFound(new { success = false, message = "DRS tidak ditemukan." });

            if (dto != null && dto.OrangerId > 0 && drs.OrangerId != dto.OrangerId)
            {
                return BadRequest(new { success = false, message = "DRS ini bukan ditugaskan untuk Anda." });
            }

            if (drs.StatusDRS == "Completed")
            {
                return BadRequest(new { success = false, message = "DRS ini sudah selesai (Completed) sebelumnya." });
            }

            drs.StatusDRS = "Completed";
            drs.UpdatedAt = DateTime.UtcNow;
            drs.UpdatedBy = "Oranger (Closing)";

            // Update status kiriman yang masih 'On Delivery' atau 'Pending' menjadi 'Delivered'
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
            _logger.LogInformation("DRS #{Id} berhasil di-closing oleh Oranger", id);

            return Ok(new
            {
                success = true,
                message = "Delivery Run Sheet berhasil diselesaikan (Closing). Status kini Completed.",
                status = drs.StatusDRS
            });
        }

        // POST: api/drs/{id}/optimize
        // Menjalankan Algoritma Ant Colony Optimization (ACO) + 2-Opt
        // Parameter statik: semut = jumlah titik + kantor, feromon awal = 0.1, alpha = 1, beta = 3, Q = 100, rho = 0.3
        [HttpPost("{id}/optimize")]
        public async Task<IActionResult> OptimizeDrs(int id)
        {
            var drs = await _context.DeliveryRunSheets
                .Include(d => d.Kantor)
                .Include(d => d.Details)
                    .ThenInclude(dt => dt.Manifest)
                .FirstOrDefaultAsync(d => d.Id == id);

            if (drs == null)
                return NotFound(ApiResponse.Fail("DRS tidak ditemukan."));

            var details = drs.Details
                .Where(dt => dt.Manifest != null && dt.Manifest.Latitude != 0 && dt.Manifest.Longitude != 0)
                .ToList();

            if (!details.Any())
            {
                return BadRequest(ApiResponse.Fail("Tidak ada kiriman dengan koordinat valid untuk dioptimasi."));
            }

            // Titik 0: Kantor Pos (Depot Awal & Akhir)
            var kantor = drs.Kantor ?? await _context.Kantors.FirstOrDefaultAsync() ?? new Kantor
            {
                Latitude = -6.9218m,
                Longitude = 107.6071m
            };

            // List Node: Node 0 = Kantor, Node 1..N = Kiriman
            var nodes = new List<(int Index, int DetailId, double Lat, double Lon)>();
            nodes.Add((0, 0, (double)kantor.Latitude, (double)kantor.Longitude));

            for (int i = 0; i < details.Count; i++)
            {
                var dt = details[i];
                nodes.Add((i + 1, dt.Id, (double)dt.Manifest!.Latitude, (double)dt.Manifest!.Longitude));
            }

            int n = nodes.Count; // Total titik (termasuk kantor)
            double[,] distMatrix = new double[n, n];
            double[,] timeMatrix = new double[n, n];

            // Panggil API Valhalla sources_to_targets untuk menghitung matriks jarak real jalan dan waktu
            try
            {
                using var httpClient = new HttpClient();
                httpClient.Timeout = TimeSpan.FromSeconds(15);

                var sourcesList = nodes.Select(node => new { lat = node.Lat, lon = node.Lon }).ToList();
                var matrixPayload = new
                {
                    sources = sourcesList,
                    targets = sourcesList,
                    costing = "motorcycle"
                };

                var matrixContent = new StringContent(JsonSerializer.Serialize(matrixPayload), Encoding.UTF8, "application/json");
                var matrixResp = await httpClient.PostAsync("http://62.171.169.192:8002/sources_to_targets", matrixContent);

                if (matrixResp.IsSuccessStatusCode)
                {
                    var matrixJson = await matrixResp.Content.ReadAsStringAsync();
                    using var doc = JsonDocument.Parse(matrixJson);
                    if (doc.RootElement.TryGetProperty("sources_to_targets", out var s2tElement))
                    {
                        for (int r = 0; r < n && r < s2tElement.GetArrayLength(); r++)
                        {
                            var row = s2tElement[r];
                            for (int c = 0; c < n && c < row.GetArrayLength(); c++)
                            {
                                var cell = row[c];
                                if (cell.TryGetProperty("distance", out var distProp))
                                {
                                    distMatrix[r, c] = distProp.GetDouble();
                                }
                                if (cell.TryGetProperty("time", out var timeProp))
                                {
                                    timeMatrix[r, c] = timeProp.GetDouble();
                                }
                            }
                        }
                    }
                }
                else
                {
                    FillHaversineMatrix(nodes, distMatrix, timeMatrix);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Gagal memanggil Valhalla sources_to_targets, menggunakan Haversine: {Msg}", ex.Message);
                FillHaversineMatrix(nodes, distMatrix, timeMatrix);
            }

            // Pastikan diagonal 0 dan jarak non-nol untuk titik berbeda
            for (int i = 0; i < n; i++)
            {
                for (int j = 0; j < n; j++)
                {
                    if (i == j)
                    {
                        distMatrix[i, j] = 0;
                        timeMatrix[i, j] = 0;
                    }
                    else
                    {
                        if (distMatrix[i, j] <= 0.0001) distMatrix[i, j] = 0.05;
                        if (timeMatrix[i, j] <= 0.0001) timeMatrix[i, j] = 10;
                    }
                }
            }

            // Ambil matriks jarak dan waktu
            // n = jumlah titik (termasuk kantor sebagai node 0)
            int numAnts = n;
            int nIter = 9999; // Sesuai nIter ACO
            double alpha = 1.0;
            double beta = 3.0;
            double evaporation = 0.5; // Koefisien evaporasi rho
            double Q = 100.0;
            int maxStagnation = 100;
            int stagnationCount = 0;
            double previousIterationBestDistance = -1;

            /* PHEROMONE AWAL */
            double[][] pheromone = new double[n][];
            for (int i = 0; i < n; i++)
            {
                pheromone[i] = new double[n];
                for (int j = 0; j < n; j++)
                {
                    pheromone[i][j] = 0.01;
                }
            }

            List<int> bestRoute = null!;
            double bestDistance = double.MaxValue;
            double bestDuration = double.MaxValue;

            Random rand = new Random(42);

            /* ITERASI ACO */
            for (int iter = 0; iter < nIter; iter++)
            {
                var allRoutes = new List<(List<int> route, double dist, double time)>();

                /* SETIAP SEMUT */
                for (int ant = 0; ant < numAnts; ant++)
                {
                    bool[] visited = new bool[n];
                    List<int> route = new List<int>();

                    int current = 0; // Mulai dari kantor (node 0)
                    route.Add(current);
                    visited[current] = true;

                    /* CARI RUTE */
                    while (route.Count < n)
                    {
                        var candidates = new List<(int node, double value)>();
                        double total = 0;

                        /* HITUNG NILAI PROBABILITAS */
                        for (int i = 0; i < n; i++)
                        {
                            if (!visited[i] && distMatrix[current, i] > 0)
                            {
                                double distance = distMatrix[current, i];

                                double tau = Math.Pow(pheromone[current][i], alpha);
                                double eta = Math.Pow(1.0 / distance, beta);
                                double value = tau * eta;

                                candidates.Add((i, value));
                                total += value;
                            }
                        }

                        /* TIDAK ADA KANDIDAT */
                        if (candidates.Count == 0 || total <= 0)
                        {
                            break;
                        }

                        /* RANDOM ROULETTE WHEEL */
                        double randomValue = rand.NextDouble();
                        double cumulativeProbability = 0;
                        int next = candidates[0].node;

                        foreach (var candidate in candidates)
                        {
                            double probability = candidate.value / total;
                            cumulativeProbability += probability;

                            if (randomValue <= cumulativeProbability)
                            {
                                next = candidate.node;
                                break;
                            }
                        }

                        /* PINDAH KE NODE BERIKUTNYA */
                        route.Add(next);
                        visited[next] = true;
                        current = next;
                    }

                    /* Jika tidak semua titik berhasil dikunjungi */
                    if (route.Count != n)
                    {
                        continue;
                    }

                    /* KEMBALI KE DEPOT */
                    route.Add(0);

                    /* HITUNG TOTAL JARAK DAN DURASI */
                    double totalDistance = 0;
                    double totalDuration = 0;
                    bool validRoute = true;

                    for (int i = 0; i < route.Count - 1; i++)
                    {
                        int from = route[i];
                        int to = route[i + 1];

                        totalDistance += distMatrix[from, to];
                        totalDuration += timeMatrix[from, to];
                    }

                    /* Jika ada jalur tidak valid */
                    if (!validRoute || totalDistance <= 0)
                    {
                        continue;
                    }

                    /* SIMPAN RUTE SEMUT */
                    allRoutes.Add((
                        route,
                        totalDistance,
                        totalDuration
                    ));
                }

                /* Jika tidak ada rute valid */
                if (allRoutes.Count == 0)
                {
                    break;
                }

                /* EVAPORATION */
                for (int i = 0; i < n; i++)
                {
                    for (int j = 0; j < n; j++)
                    {
                        pheromone[i][j] *= (1.0 - evaporation);
                    }
                }

                /* UPDATE PHEROMONE (semua semut yang valid berkontribusi) */
                foreach (var r in allRoutes)
                {
                    if (r.dist <= 0) continue;

                    double delta = Q / r.dist;

                    for (int i = 0; i < r.route.Count - 1; i++)
                    {
                        int from = r.route[i];
                        int to = r.route[i + 1];

                        pheromone[from][to] += delta;
                        pheromone[to][from] += delta;
                    }
                }

                /* RUTE TERBAIK PADA ITERASI SAAT INI */
                var iterationBest = allRoutes
                    .OrderBy(x => x.dist)
                    .First();

                /* UPDATE SOLUSI TERBAIK GLOBAL */
                if (iterationBest.dist < bestDistance)
                {
                    bestDistance = iterationBest.dist;
                    bestDuration = iterationBest.time;
                    bestRoute = new List<int>(iterationBest.route);
                }

                /* CEK STAGNASI */
                if (previousIterationBestDistance >= 0 && Math.Abs(iterationBest.dist - previousIterationBestDistance) < 0.000001)
                {
                    stagnationCount++;
                }
                else
                {
                    stagnationCount = 0;
                }

                /* Simpan nilai iterasi sekarang untuk pembanding iterasi berikutnya */
                previousIterationBestDistance = iterationBest.dist;

                /*
                 * BERHENTI JIKA NILAI TERBAIK SAMA
                 * SELAMA 100 ITERASI BERTURUT-TURUT */
                if (stagnationCount >= maxStagnation)
                {
                    _logger.LogInformation("ACO konvergen pada iterasi #{Iter}. Stagnasi: {Count}x. Jarak: {Dist:F3} km", iter + 1, stagnationCount, bestDistance);
                    break;
                }
            }

            /* 2-OPT FIRST IMPROVEMENT */
            var twoOptRes = TwoOptFirstImprovement(distMatrix, timeMatrix, bestRoute ?? nodes.Select(x => x.Index).Concat(new[] { 0 }).ToList());
            var bestTour = twoOptRes.route;

            // Urutan DetailDeliveryRunSheet yang teroptimasi (hanya node kiriman 1..N)
            var orderedDetailIds = new List<int>();
            for (int i = 1; i < bestTour.Count - 1; i++)
            {
                int nodeIdx = bestTour[i];
                orderedDetailIds.Add(nodes[nodeIdx].DetailId);
            }

            // ==========================================
            // AMBIL POLYLINE & SEGMENT DARI VALHALLA /route
            // ==========================================
            string polylineFull = "";
            decimal totalJarakKm = 0m;
            decimal totalEstimasiMenit = 0m;
            var segmentsList = new List<DrsOptimasiSegmentDto>();

            try
            {
                using var httpClient = new HttpClient();
                httpClient.Timeout = TimeSpan.FromSeconds(20);

                var routeLocations = bestTour.Select(idx => new
                {
                    lat = nodes[idx].Lat,
                    lon = nodes[idx].Lon
                }).ToList();

                var routePayload = new
                {
                    locations = routeLocations,
                    costing = "auto"
                };

                var routeContent = new StringContent(JsonSerializer.Serialize(routePayload), Encoding.UTF8, "application/json");
                var routeResp = await httpClient.PostAsync("http://62.171.169.192:8002/route", routeContent);

                if (routeResp.IsSuccessStatusCode)
                {
                    var routeJson = await routeResp.Content.ReadAsStringAsync();
                    using var doc = JsonDocument.Parse(routeJson);
                    var trip = doc.RootElement.GetProperty("trip");

                    if (trip.TryGetProperty("summary", out var summary))
                    {
                        totalJarakKm = (decimal)summary.GetProperty("length").GetDouble();
                        double timeSeconds = summary.GetProperty("time").GetDouble();
                        totalEstimasiMenit = Math.Round((decimal)(timeSeconds / 60.0), 2);
                    }

                    if (trip.TryGetProperty("legs", out var legsElement))
                    {
                        var legArray = legsElement.EnumerateArray().ToList();
                        for (int legIdx = 0; legIdx < legArray.Count; legIdx++)
                        {
                            var leg = legArray[legIdx];
                            var legSummary = leg.GetProperty("summary");
                            string legShape = leg.GetProperty("shape").GetString() ?? "";

                            double legLength = legSummary.GetProperty("length").GetDouble();
                            double legTime = legSummary.GetProperty("time").GetDouble();

                            int fromNodeIdx = bestTour[legIdx];
                            int toNodeIdx = bestTour[legIdx + 1];

                            int? detailId = toNodeIdx > 0 ? nodes[toNodeIdx].DetailId : null;

                            segmentsList.Add(new DrsOptimasiSegmentDto
                            {
                                UrutanKe = legIdx + 1,
                                DetailDeliveryRunSheetId = detailId,
                                LatitudeAwal = (decimal)nodes[fromNodeIdx].Lat,
                                LongitudeAwal = (decimal)nodes[fromNodeIdx].Lon,
                                LatitudeAkhir = (decimal)nodes[toNodeIdx].Lat,
                                LongitudeAkhir = (decimal)nodes[toNodeIdx].Lon,
                                JarakKm = Math.Round((decimal)legLength, 3),
                                EstimasiWaktuMenit = Math.Round((decimal)(legTime / 60.0), 2),
                                DurasiDetik = legTime,
                                PolylineSegmen = legShape
                            });
                        }
                    }

                    // Gabungkan segmen polyline dengan pemisah ';' (ASCII 59 di luar range polyline 63..126)
                    polylineFull = string.Join(";", segmentsList.Where(s => !string.IsNullOrEmpty(s.PolylineSegmen)).Select(s => s.PolylineSegmen));
                }
            }
            catch (Exception ex)
            {
                _logger.LogError("Gagal mengambil rute Valhalla: {Msg}", ex.Message);
            }

            if (totalJarakKm == 0m)
            {
                double sumDist = 0;
                for (int s = 0; s < bestTour.Count - 1; s++)
                    sumDist += distMatrix[bestTour[s], bestTour[s + 1]];
                totalJarakKm = Math.Round((decimal)sumDist, 2);
                totalEstimasiMenit = Math.Round(totalJarakKm * 3.5m, 2); // Estimasi kasaran
            }

            return Ok(new RunOptimasiResponseDto
            {
                Success = true,
                Message = "Optimasi rute berhasil (ACO + 2-Opt).",
                TotalDistanceKm = totalJarakKm,
                TotalDurationMenit = totalEstimasiMenit,
                PolylineFull = polylineFull,
                OrderedDetailIds = orderedDetailIds,
                Segments = segmentsList
            });
        }

        // POST: api/drs/{id}/save-optimasi
        // Menyimpan hasil optimasi rute ke database tabel OptimasiRuteHistory & Segments
        [HttpPost("{id}/save-optimasi")]
        public async Task<IActionResult> SaveOptimasi(int id, [FromBody] SaveOptimasiRequestDto dto)
        {
            var drs = await _context.DeliveryRunSheets
                .Include(d => d.OptimasiHistories)
                .FirstOrDefaultAsync(d => d.Id == id);

            if (drs == null)
                return NotFound(ApiResponse.Fail("DRS tidak ditemukan."));

            // Hapus riwayat optimasi sebelumnya jika ada
            var oldHistories = await _context.OptimasiRuteHistories
                .Where(h => h.DeliveryRunSheetId == id)
                .Include(h => h.Segments)
                .ToListAsync();

            if (oldHistories.Any())
            {
                _context.OptimasiRuteHistories.RemoveRange(oldHistories);
            }

            var history = new OptimasiRuteHistory
            {
                DeliveryRunSheetId = id,
                TotalJarakKm = dto.TotalJarakKm,
                TotalEstimasiMenit = dto.TotalEstimasiMenit,
                PolylineFull = dto.PolylineFull ?? string.Empty,
                ExecutedAt = DateTime.UtcNow,
                CreatedAt = DateTime.UtcNow,
                CreatedBy = "Oranger (Optimasi Rute)",
                Segments = new List<OptimasiRuteSegment>()
            };

            if (dto.Segments != null && dto.Segments.Any())
            {
                foreach (var seg in dto.Segments)
                {
                    history.Segments.Add(new OptimasiRuteSegment
                    {
                        DetailDeliveryRunSheetId = seg.DetailDeliveryRunSheetId,
                        UrutanKe = seg.UrutanKe,
                        LatitudeAwal = seg.LatitudeAwal,
                        LongitudeAwal = seg.LongitudeAwal,
                        LatitudeAkhir = seg.LatitudeAkhir,
                        LongitudeAkhir = seg.LongitudeAkhir,
                        JarakKm = seg.JarakKm,
                        EstimasiWaktuMenit = seg.EstimasiWaktuMenit,
                        PolylineSegmen = seg.PolylineSegmen,
                        CreatedAt = DateTime.UtcNow,
                        CreatedBy = "System"
                    });

                }
            }

            _context.OptimasiRuteHistories.Add(history);
            
            // 🔥 Update status DRS menjadi "Sudah Dioptimasi" jika belum selesai (Completed)
            if (drs.StatusDRS != "Completed")
            {
                drs.StatusDRS = "Sudah Dioptimasi";
            }
            drs.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            _logger.LogInformation("Hasil optimasi rute berhasil disimpan untuk DRS #{Id}, Status DRS: {Status}", id, drs.StatusDRS);

            return Ok(new
            {
                success = true,
                message = "Hasil optimasi rute berhasil disimpan ke database.",
                historyId = history.Id,
                statusDRS = drs.StatusDRS
            });
        }

        // POST: api/drs/{id}/hasil-optimasi
        // Mengembalikan data lengkap rute yang sudah dioptimasi (urutan pengantaran, polyline, jarak, waktu, segmen) dalam 1 respon
        [HttpPost("{id}/hasil-optimasi")]
        public async Task<IActionResult> GetHasilOptimasiPost(int id)
        {
            return await BuildHasilOptimasiResponse(id);
        }

        // POST: api/drs/hasil-optimasi
        // Alternatif POST dengan JSON body: { "drsId": 1 }
        [HttpPost("hasil-optimasi")]
        public async Task<IActionResult> GetHasilOptimasiFromBodyPost([FromBody] HasilOptimasiQueryDto? dto)
        {
            if (dto == null || dto.DrsId <= 0)
                return BadRequest(ApiResponse.Fail("drsId wajib disertakan dalam body."));

            return await BuildHasilOptimasiResponse(dto.DrsId);
        }

        private async Task<IActionResult> BuildHasilOptimasiResponse(int id)
        {
            var d = await _context.DeliveryRunSheets
                .AsNoTracking()
                .Include(x => x.Kantor)
                .FirstOrDefaultAsync(x => x.Id == id);

            if (d == null)
                return NotFound(ApiResponse.Fail("DRS tidak ditemukan."));

            var latestOpt = await _context.OptimasiRuteHistories
                .AsNoTracking()
                .Where(oh => oh.DeliveryRunSheetId == id)
                .OrderByDescending(o => o.ExecutedAt)
                .Include(oh => oh.Segments)
                .FirstOrDefaultAsync();

            var segmentsDto = new List<DrsOptimasiSegmentDto>();
            var orderMap = new Dictionary<int, int>(); // DetailDeliveryRunSheetId -> UrutanKe

            if (latestOpt != null && latestOpt.Segments != null && latestOpt.Segments.Any())
            {
                foreach (var seg in latestOpt.Segments.OrderBy(s => s.UrutanKe))
                {
                    segmentsDto.Add(new DrsOptimasiSegmentDto
                    {
                        UrutanKe = seg.UrutanKe,
                        DetailDeliveryRunSheetId = seg.DetailDeliveryRunSheetId,
                        LatitudeAwal = seg.LatitudeAwal,
                        LongitudeAwal = seg.LongitudeAwal,
                        LatitudeAkhir = seg.LatitudeAkhir,
                        LongitudeAkhir = seg.LongitudeAkhir,
                        JarakKm = seg.JarakKm,
                        EstimasiWaktuMenit = seg.EstimasiWaktuMenit,
                        DurasiDetik = (double)(seg.EstimasiWaktuMenit * 60m),
                        PolylineSegmen = seg.PolylineSegmen
                    });

                    if (seg.DetailDeliveryRunSheetId.HasValue)
                    {
                        orderMap[seg.DetailDeliveryRunSheetId.Value] = seg.UrutanKe;
                    }
                }
            }

            var details = await _context.DetailDeliveryRunSheets
                .AsNoTracking()
                .Where(dt => dt.DeliveryRunSheetId == id)
                .Include(dt => dt.Manifest)
                .Include(dt => dt.ProofOfDelivery)
                .ToListAsync();

            var kirimanList = details.Select(dt => new DrsDetailItemDto
            {
                Id = dt.Id,
                ManifestId = dt.ManifestId,
                NomorUrutan = orderMap.ContainsKey(dt.Id) ? orderMap[dt.Id] : null,
                NomorKiriman = dt.Manifest != null ? dt.Manifest.NomorKiriman : "-",
                NamaPenerima = dt.Manifest != null ? dt.Manifest.NamaPenerima : "-",
                TeleponPenerima = dt.Manifest?.TeleponPenerima,
                AlamatTujuan = dt.Manifest != null ? dt.Manifest.AlamatTujuan : "-",
                Latitude = dt.Manifest?.Latitude ?? 0,
                Longitude = dt.Manifest?.Longitude ?? 0,
                BeratKg = dt.Manifest?.BeratKg ?? 0,
                StatusPengantaran = dt.StatusPengantaran,
                HasPod = dt.ProofOfDelivery != null,
                FotoPod = dt.ProofOfDelivery?.Photo1
            }).ToList();

            bool hasOptimasi = latestOpt != null && (orderMap.Any() || !string.IsNullOrWhiteSpace(latestOpt.PolylineFull));

            // Jika sudah dioptimasi, susun kirimanList sesuai nomor urutan
            if (hasOptimasi && orderMap.Any())
            {
                kirimanList = kirimanList
                    .OrderBy(k => k.NomorUrutan ?? 999999)
                    .ThenBy(k => k.Id)
                    .ToList();
            }

            var kantor = d.Kantor ?? await _context.Kantors.AsNoTracking().FirstOrDefaultAsync();

            var response = new HasilOptimasiResponseDto
            {
                Success = true,
                HasOptimasi = hasOptimasi,
                DrsId = d.Id,
                NoDrs = d.NoDRS,
                StatusDrs = d.StatusDRS,
                TotalKiriman = d.TotalKiriman,
                TotalJarakKm = latestOpt?.TotalJarakKm ?? 0m,
                TotalEstimasiMenit = latestOpt?.TotalEstimasiMenit ?? 0m,
                PolylineFull = latestOpt?.PolylineFull ?? string.Empty,
                Segments = segmentsDto,
                KirimanList = kirimanList,
                Depot = new DepotLocationDto
                {
                    NamaKantor = kantor != null ? kantor.NamaKantor : "Kantor Pos",
                    Latitude = kantor != null ? (double)kantor.Latitude : -6.9218,
                    Longitude = kantor != null ? (double)kantor.Longitude : 107.6071
                }
            };

            return Ok(response);
        }

        // POST: api/drs/{id}/reset-optimasi
        [HttpPost("{id}/reset-optimasi")]
        public async Task<IActionResult> ResetOptimasi(int id)
        {
            var drs = await _context.DeliveryRunSheets.FirstOrDefaultAsync(d => d.Id == id);
            var oldHistories = await _context.OptimasiRuteHistories
                .Where(h => h.DeliveryRunSheetId == id)
                .Include(h => h.Segments)
                .ToListAsync();

            if (oldHistories.Any())
            {
                _context.OptimasiRuteHistories.RemoveRange(oldHistories);
            }

            if (drs != null && drs.StatusDRS == "Sudah Dioptimasi")
            {
                drs.StatusDRS = "In Progress";
                drs.UpdatedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync();

            return Ok(new { success = true, message = "Riwayat optimasi rute berhasil direset." });
        }

        // POST: api/drs/seed-custom-data
        // Menghapus semua DRS, POD, Optimasi, dan Manifest lama, lalu membuat ulang Manifest & DRS baru sesuai koordinat kustom
        [HttpPost("seed-custom-data")]
        public async Task<IActionResult> SeedCustomData()
        {
            try
            {
                // 1. Bersihkan tabel-tabel terkait DRS & Manifest
                var allSegs = await _context.OptimasiRuteSegments.ToListAsync();
                _context.OptimasiRuteSegments.RemoveRange(allSegs);

                var allHistories = await _context.OptimasiRuteHistories.ToListAsync();
                _context.OptimasiRuteHistories.RemoveRange(allHistories);

                var allPods = await _context.ProofOfDeliveries.ToListAsync();
                _context.ProofOfDeliveries.RemoveRange(allPods);

                var allDetails = await _context.DetailDeliveryRunSheets.ToListAsync();
                _context.DetailDeliveryRunSheets.RemoveRange(allDetails);

                var allDrs = await _context.DeliveryRunSheets.ToListAsync();
                _context.DeliveryRunSheets.RemoveRange(allDrs);

                var allManifests = await _context.Manifests.ToListAsync();
                _context.Manifests.RemoveRange(allManifests);

                await _context.SaveChangesAsync();

                // 2. Ambil kantor & user (pastikan koordinat kantor berada di lokasi klaster paket yang sama)
                var kantor = await _context.Kantors.FirstOrDefaultAsync();
                if (kantor == null)
                {
                    kantor = new Kantor
                    {
                        KodeKantor = "KCU-44100",
                        NamaKantor = "Kantor Pos Tasikmalaya / Garut",
                        Alamat = "Jl. Raya",
                        Latitude = -7.060519m,
                        Longitude = 108.090528m,
                        CreatedAt = DateTime.UtcNow,
                        CreatedBy = "System"
                    };
                    _context.Kantors.Add(kantor);
                }
                else
                {
                    kantor.KodeKantor = "KCU-44100";
                    kantor.NamaKantor = "Kantor Pos Tasikmalaya / Garut";
                    kantor.Latitude = -7.060519m;
                    kantor.Longitude = 108.090528m;
                    kantor.UpdatedAt = DateTime.UtcNow;
                }
                await _context.SaveChangesAsync();

                var bm = await _context.Users.FirstOrDefaultAsync(u => u.Role != null && u.Role.RoleType == 3) 
                         ?? await _context.Users.FirstOrDefaultAsync();
                var oranger = await _context.Users.FirstOrDefaultAsync(u => u.Role != null && (u.Role.RoleType == 1 || u.Role.RoleType == 2))
                              ?? await _context.Users.FirstOrDefaultAsync();

                int bmId = bm?.Id ?? 1;
                int orangerId = oranger?.Id ?? 1;

                // 3. 64 Koordinat Kustom yang diberikan
                var rawCoords = new List<(decimal Lat, decimal Lon)>
                {
                    (-7.060519m, 108.090528m),
                    (-7.067381m, 108.091981m),
                    (-7.0720395m, 108.0890227m),
                    (-7.073216m, 108.078999m),
                    (-7.072793m, 108.072858m),
                    (-7.0750189m, 108.0888726m),
                    (-7.086719m, 108.09371m),
                    (-7.087355m, 108.0979891m),
                    (-7.085303m, 108.0954295m),
                    (-7.090108m, 108.10367m),
                    (-7.101454m, 108.10283m),
                    (-7.0947577m, 108.0992966m),
                    (-7.1003494m, 108.1055422m),
                    (-7.1011207m, 108.0937904m),
                    (-7.1096018m, 108.078928m),
                    (-7.1102619m, 108.0833324m),
                    (-7.1119211m, 108.0775843m),
                    (-7.1100856m, 108.0741721m),
                    (-7.1080935m, 108.072693m),
                    (-7.110406m, 108.07746m),
                    (-7.0874187m, 108.0864456m),
                    (-7.083879m, 108.081151m),
                    (-7.0904694m, 108.0822682m),
                    (-7.0952055m, 108.0765985m),
                    (-7.076562m, 108.066788m),
                    (-7.082579m, 108.0625215m),
                    (-7.0919999m, 108.0632511m),
                    (-7.088555m, 108.061791m),
                    (-7.0866856m, 108.0598986m),
                    (-7.0860619m, 108.0600496m),
                    (-7.0893358m, 108.0560194m),
                    (-7.0778817m, 108.0522224m),
                    (-7.07608m, 108.05214m),
                    (-7.067829m, 108.055814m),
                    (-7.062639m, 108.0471m),
                    (-7.0622026m, 108.0486777m),
                    (-7.061062m, 108.05545m),
                    (-7.062691m, 108.04721m),
                    (-7.0622966m, 108.0468138m),
                    (-7.0532502m, 108.0485662m),
                    (-7.0636328m, 108.0819943m),
                    (-7.0595926m, 108.0792942m),
                    (-7.0517552m, 108.0600628m),
                    (-7.0565111m, 108.0646134m),
                    (-7.0576646m, 108.0511739m),
                    (-7.056930m, 108.050101m),
                    (-7.0569736m, 108.0493907m),
                    (-7.046479m, 108.043471m),
                    (-7.046852m, 108.043745m),
                    (-7.045857m, 108.040628m),
                    (-7.0462051m, 108.0396358m),
                    (-7.0469292m, 108.0386447m),
                    (-7.047427m, 108.038447m),
                    (-7.0396617m, 108.0562887m),
                    (-7.0356402m, 108.0573722m),
                    (-7.0392274m, 108.0526034m),
                    (-7.0406643m, 108.0512188m),
                    (-7.039781m, 108.050629m),
                    (-7.0641695m, 108.0876916m),
                    (-7.0536012m, 108.0869508m),
                    (-7.0453805m, 108.0870997m),
                    (-7.03666m, 108.0913382m),
                    (-7.027638m, 108.0856539m),
                    (-7.076360m, 108.089261m)
                };

                // Daftar nama penerima acak
                var namaList = new[]
                {
                    "Budi Santoso", "Siti Aminah", "Ahmad Fauzi", "Dewi Lestari", "Rian Hidayat",
                    "Eka Pratama", "Nurul Hidayah", "Agus Setiawan", "Indah Permata", "Hendra Gunawan",
                    "Putri Wulandari", "Reza Rahardian", "Fitri Handayani", "Dedi Kusnadi", "Mega Utami",
                    "Aris Munandar", "Yuni Shara", "Bambang Pamungkas", "Maya Sari", "Fajar Sidiq",
                    "Rina Nose", "Taufik Hidayat", "Ratna Sarumpaet", "Iwan Fals", "Nia Ramadhani",
                    "Denny Cagur", "Gita Gutawa", "Raffi Ahmad", "Nagita Slavina", "Sule Prikitiew"
                };

                var jalanList = new[]
                {
                    "Jl. Mawar No.", "Jl. Melati No.", "Jl. Anggrek No.", "Jl. Kenanga No.", "Jl. Dahlia No.",
                    "Jl. Merdeka No.", "Jl. Diponegoro No.", "Jl. Sudirman No.", "Jl. Gatot Subroto No.", "Jl. Ahmad Yani No."
                };

                var rand = new Random();
                var newManifests = new List<Manifest>();

                for (int i = 0; i < rawCoords.Count; i++)
                {
                    var coord = rawCoords[i];
                    string noKiriman = $"POS{DateTime.Now:yyyyMMdd}{1000 + i + 1}";
                    string nama = namaList[i % namaList.Length] + $" #{i + 1}";
                    string jalan = $"{jalanList[i % jalanList.Length]} {rand.Next(1, 150)}";
                    decimal berat = Math.Round((decimal)(rand.NextDouble() * 4.5 + 0.5), 2);
                    string telp = $"08{rand.Next(11, 99)}{rand.Next(1000000, 9999999)}";

                    newManifests.Add(new Manifest
                    {
                        NomorKiriman = noKiriman,
                        NamaPenerima = nama,
                        TeleponPenerima = telp,
                        AlamatTujuan = jalan,
                        Latitude = coord.Lat,
                        Longitude = coord.Lon,
                        BeratKg = berat,
                        StatusKiriman = "On Delivery",
                        CreatedAt = DateTime.UtcNow,
                        CreatedBy = "System Seeder"
                    });
                }

                _context.Manifests.AddRange(newManifests);
                await _context.SaveChangesAsync();

                // 4. Buat 1 DRS baru yang memuat seluruh 64 paket
                var newDrs = new DeliveryRunSheet
                {
                    NoDRS = $"{kantor.KodeKantor}-{DateTime.Now:yyyyMMddHHmm}",
                    KantorId = kantor.Id,
                    BranchManagerId = bmId,
                    OrangerId = orangerId,
                    TanggalTugas = DateOnly.FromDateTime(DateTime.Today),
                    TotalKiriman = newManifests.Count,
                    StatusDRS = "Assigned",
                    CreatedAt = DateTime.UtcNow,
                    CreatedBy = "System Seeder"
                };

                _context.DeliveryRunSheets.Add(newDrs);
                await _context.SaveChangesAsync();

                // 5. Tambahkan Detail DRS untuk ke-64 manifest
                var newDetails = new List<DetailDeliveryRunSheet>();
                foreach (var m in newManifests)
                {
                    newDetails.Add(new DetailDeliveryRunSheet
                    {
                        DeliveryRunSheetId = newDrs.Id,
                        ManifestId = m.Id,
                        StatusPengantaran = "Pending",
                        CreatedAt = DateTime.UtcNow,
                        CreatedBy = "System Seeder"
                    });
                }

                _context.DetailDeliveryRunSheets.AddRange(newDetails);
                await _context.SaveChangesAsync();

                _logger.LogInformation("Berhasil reset dan seed 64 data custom ke DRS #{DrsId}", newDrs.Id);

                return Ok(new
                {
                    success = true,
                    message = $"Berhasil membuat ulang data: 64 Manifest & DRS #{newDrs.Id} ({newDrs.NoDRS}) telah dibuat.",
                    drsId = newDrs.Id,
                    noDrs = newDrs.NoDRS,
                    totalKiriman = newManifests.Count
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Gagal seed custom data");
                return StatusCode(500, new { success = false, message = "Gagal seed data: " + ex.Message });
            }
        }

        // Helper TwoOptFirstImprovement sesuai algoritma acuan user
        private (List<int> route, double distance, double duration) TwoOptFirstImprovement(double[,] distMatrix, double[,] timeMatrix, List<int> initialRoute)
        {
            var bestRoute = new List<int>(initialRoute);
            double bestDistance = CalculateRouteDistance(distMatrix, bestRoute);
            double bestDuration = 0;

            for (int i = 0; i < bestRoute.Count - 1; i++)
            {
                int from = bestRoute[i];
                int to = bestRoute[i + 1];
                bestDuration += timeMatrix[from, to];
            }

            bool improved = true;
            int iteration = 0;

            /* LOOP TERUS SAMPAI TIDAK ADA PERBAIKAN */
            while (improved)
            {
                improved = false;
                iteration++;

                /* CEK SEMUA KOMBINASI */
                for (int i = 1; i < bestRoute.Count - 2; i++)
                {
                    for (int k = i + 1; k < bestRoute.Count - 1; k++)
                    {
                        /* SWAP ROUTE */
                        var newRoute = TwoOptSwap(bestRoute, i, k);

                        /* HITUNG DISTANCE BARU */
                        double newDistance = CalculateRouteDistance(distMatrix, newRoute);

                        /* JIKA LEBIH BAIK */
                        if (newDistance < bestDistance - 1e-6)
                        {
                            bestRoute = newRoute;
                            bestDistance = newDistance;

                            /* HITUNG DURATION BARU */
                            bestDuration = 0;
                            for (int x = 0; x < bestRoute.Count - 1; x++)
                            {
                                int from = bestRoute[x];
                                int to = bestRoute[x + 1];
                                bestDuration += timeMatrix[from, to];
                            }

                            improved = true;

                            /* FIRST IMPROVEMENT LANGSUNG ULANG */
                            goto NEXT_ITERATION;
                        }
                    }
                }

            NEXT_ITERATION:
                ;
            }

            return (bestRoute, bestDistance, bestDuration);
        }

        private List<int> TwoOptSwap(List<int> route, int i, int k)
        {
            var newRoute = new List<int>();

            // 1. Tambahkan node dari awal sampai i - 1
            for (int c = 0; c <= i - 1; c++)
            {
                newRoute.Add(route[c]);
            }

            // 2. Balikkan urutan node dari i sampai k
            for (int c = k; c >= i; c--)
            {
                newRoute.Add(route[c]);
            }

            // 3. Tambahkan node dari k + 1 sampai akhir
            for (int c = k + 1; c < route.Count; c++)
            {
                newRoute.Add(route[c]);
            }

            return newRoute;
        }

        private double CalculateRouteDistance(double[,] distMatrix, List<int> route)
        {
            double dist = 0;
            for (int i = 0; i < route.Count - 1; i++)
            {
                dist += distMatrix[route[i], route[i + 1]];
            }
            return dist;
        }

        private void FillHaversineMatrix(List<(int Index, int DetailId, double Lat, double Lon)> nodes, double[,] distMatrix, double[,] timeMatrix)
        {
            int n = nodes.Count;
            for (int i = 0; i < n; i++)
            {
                for (int j = 0; j < n; j++)
                {
                    if (i == j)
                    {
                        distMatrix[i, j] = 0;
                        timeMatrix[i, j] = 0;
                    }
                    else
                    {
                        double d = HaversineKm(nodes[i].Lat, nodes[i].Lon, nodes[j].Lat, nodes[j].Lon);
                        distMatrix[i, j] = d;
                        timeMatrix[i, j] = (d / 30.0) * 3600.0; // Kecepatan rata-rata 30 km/jam dalam detik
                    }
                }
            }
        }

        private double HaversineKm(double lat1, double lon1, double lat2, double lon2)
        {
            double dLat = (lat2 - lat1) * Math.PI / 180.0;
            double dLon = (lon2 - lon1) * Math.PI / 180.0;

            double a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                       Math.Cos(lat1 * Math.PI / 180.0) * Math.Cos(lat2 * Math.PI / 180.0) *
                       Math.Sin(dLon / 2) * Math.Sin(dLon / 2);

            double c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
            return 6371.0 * c;
        }

        // DELETE: api/drs/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var drs = await _context.DeliveryRunSheets
                .Include(d => d.Details)
                .FirstOrDefaultAsync(d => d.Id == id);

            if (drs == null)
                return NotFound(new { success = false, message = "DRS tidak ditemukan." });

            if (drs.Details != null && drs.Details.Any())
            {
                return BadRequest(new { success = false, message = "DRS tidak dapat dihapus karena memiliki rincian kiriman yang masih terhubung." });
            }

            _context.DeliveryRunSheets.Remove(drs);
            await _context.SaveChangesAsync();

            _logger.LogInformation("DRS dihapus: {Id}", id);
            return Ok(new { success = true, message = "Delivery Run Sheet berhasil dihapus." });
        }
    }
}
