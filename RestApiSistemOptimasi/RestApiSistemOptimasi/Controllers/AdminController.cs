using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestApiSistemOptimasi.Data;
using RestApiSistemOptimasi.Interfaces;
using RestApiSistemOptimasi.Models.DTOs;
using RestApiSistemOptimasi.Models.Entities;

namespace RestApiSistemOptimasi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AdminController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IUserRepository _userRepo;
        private readonly IRoleRepository _roleRepo;
        private readonly IMenuRoleRepository _menuRoleRepo;
        private readonly ILogger<AdminController> _logger;

        public AdminController(
            AppDbContext context,
            IUserRepository userRepo,
            IRoleRepository roleRepo,
            IMenuRoleRepository menuRoleRepo,
            ILogger<AdminController> logger)
        {
            _context = context;
            _userRepo = userRepo;
            _roleRepo = roleRepo;
            _menuRoleRepo = menuRoleRepo;
            _logger = logger;
        }

        // ==================== DASHBOARD & STATS ====================

        [HttpGet("dashboard-stats")]
        public async Task<IActionResult> GetDashboardStats()
        {
            var totalUsers = await _context.Users.CountAsync();
            var totalRoles = await _context.Roles.CountAsync();
            var totalMenus = await _context.MenuRoles.CountAsync();
            return Ok(new { totalUsers, totalRoles, totalMenus });
        }

        // ==================== USERS API ====================

        [HttpGet("users")]
        public async Task<IActionResult> GetUsers()
        {
            var users = await _context.Users
                .Include(u => u.Role)
                .OrderBy(u => u.NamaLengkap)
                .Select(u => new UserDto
                {
                    Id = u.Id,
                    NamaLengkap = u.NamaLengkap,
                    Email = u.Email,
                    RoleId = u.RoleId,
                    RoleName = u.Role != null ? u.Role.NamaRole : "-",
                    IsActive = u.IsActive,
                    CreatedAt = u.CreatedAt.ToLocalTime().ToString("dd/MM/yyyy HH:mm")
                })
                .ToListAsync();

            return Ok(users);
        }

        [HttpGet("users/{id}")]
        public async Task<IActionResult> GetUserById(int id)
        {
            var user = await _userRepo.GetByIdAsync(id);
            if (user == null)
                return NotFound(ApiResponse.Fail("User tidak ditemukan."));

            return Ok(new UserDto
            {
                Id = user.Id,
                NamaLengkap = user.NamaLengkap,
                Email = user.Email,
                RoleId = user.RoleId,
                RoleName = user.Role?.NamaRole ?? "-",
                IsActive = user.IsActive,
                CreatedAt = user.CreatedAt.ToLocalTime().ToString("dd/MM/yyyy HH:mm")
            });
        }

        [HttpPost("users")]
        public async Task<IActionResult> CreateUser([FromBody] CreateUserDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.NamaLengkap))
                return BadRequest(new { success = false, message = "Nama lengkap wajib diisi." });
            if (string.IsNullOrWhiteSpace(dto.Email) || !dto.Email.Contains('@'))
                return BadRequest(new { success = false, message = "Email tidak valid." });
            if (string.IsNullOrWhiteSpace(dto.Password) || dto.Password.Length < 6)
                return BadRequest(new { success = false, message = "Password minimal 6 karakter." });
            if (dto.ConfirmPassword != dto.Password)
                return BadRequest(new { success = false, message = "Password dan konfirmasi tidak cocok." });
            if (dto.RoleId <= 0)
                return BadRequest(new { success = false, message = "Pilih role terlebih dahulu." });

            var existing = await _userRepo.GetByEmailAsync(dto.Email);
            if (existing != null)
                return BadRequest(new { success = false, message = "Email sudah terdaftar." });

            var user = new User
            {
                NamaLengkap = dto.NamaLengkap,
                Email = dto.Email,
                RoleId = dto.RoleId,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password),
                CreatedAt = DateTime.UtcNow,
                IsActive = true
            };

            await _userRepo.AddAsync(user);
            await _userRepo.SaveChangesAsync();

            return Ok(new { success = true, message = "Berhasil menambah user baru." });
        }

        [HttpPut("users/{id}")]
        public async Task<IActionResult> EditUser(int id, [FromBody] EditUserDto dto)
        {
            if (id != dto.Id)
                return BadRequest(new { success = false, message = "ID tidak cocok." });

            var current = await _userRepo.GetByIdAsync(id);
            if (current == null)
                return NotFound(new { success = false, message = "User tidak ditemukan." });

            if (string.IsNullOrWhiteSpace(dto.NamaLengkap))
                return BadRequest(new { success = false, message = "Nama lengkap wajib diisi." });
            if (string.IsNullOrWhiteSpace(dto.Email) || !dto.Email.Contains('@'))
                return BadRequest(new { success = false, message = "Email tidak valid." });

            var emailConflict = await _userRepo.GetByEmailAsync(dto.Email);
            if (emailConflict != null && emailConflict.Id != id)
                return BadRequest(new { success = false, message = "Email sudah digunakan user lain." });

            current.NamaLengkap = dto.NamaLengkap;
            current.Email = dto.Email;
            current.RoleId = dto.RoleId;
            current.IsActive = dto.IsActive;
            current.UpdatedAt = DateTime.UtcNow;

            if (!string.IsNullOrWhiteSpace(dto.Password) && dto.Password.Length >= 6)
                current.PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password);

            await _userRepo.UpdateAsync(current);
            await _userRepo.SaveChangesAsync();

            return Ok(new { success = true, message = "Berhasil memperbarui data user." });
        }

        [HttpDelete("users/{id}")]
        public async Task<IActionResult> DeleteUser(int id)
        {
            var user = await _userRepo.GetByIdAsync(id);
            if (user == null)
                return NotFound(new { success = false, message = "User tidak ditemukan." });

            await _userRepo.DeleteAsync(id);
            await _userRepo.SaveChangesAsync();

            return Ok(new { success = true, message = "Berhasil menghapus user." });
        }

        // ==================== ROLES API ====================

        [HttpGet("roles")]
        public async Task<IActionResult> GetRoles()
        {
            var roles = await _context.Roles
                .OrderBy(r => r.NamaRole)
                .Select(r => new {
                    r.Id,
                    r.NamaRole,
                    Deskripsi = r.Deskripsi ?? "-"
                })
                .ToListAsync();

            return Ok(roles);
        }

        [HttpPost("roles")]
        public async Task<IActionResult> CreateRole([FromBody] CreateRoleDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.NamaRole))
                return BadRequest(new { success = false, message = "Nama role wajib diisi." });

            var existing = await _roleRepo.GetAllAsync();
            if (existing.Any(r => r.NamaRole.Equals(dto.NamaRole, StringComparison.OrdinalIgnoreCase)))
                return BadRequest(new { success = false, message = "Nama role sudah ada." });

            var role = new Role
            {
                NamaRole = dto.NamaRole,
                Deskripsi = dto.Deskripsi
            };

            await _roleRepo.AddAsync(role);
            await _roleRepo.SaveChangesAsync();

            return Ok(new { success = true, message = "Berhasil menambah role baru." });
        }

        [HttpPut("roles/{id}")]
        public async Task<IActionResult> EditRole(int id, [FromBody] EditRoleDto dto)
        {
            if (id != dto.Id)
                return BadRequest(new { success = false, message = "ID tidak cocok." });

            var current = await _roleRepo.GetByIdAsync(id);
            if (current == null)
                return NotFound(new { success = false, message = "Role tidak ditemukan." });

            if (string.IsNullOrWhiteSpace(dto.NamaRole))
                return BadRequest(new { success = false, message = "Nama role wajib diisi." });

            var allRoles = await _roleRepo.GetAllAsync();
            if (allRoles.Any(r => r.NamaRole.Equals(dto.NamaRole, StringComparison.OrdinalIgnoreCase) && r.Id != id))
                return BadRequest(new { success = false, message = "Nama role sudah digunakan." });

            current.NamaRole = dto.NamaRole;
            current.Deskripsi = dto.Deskripsi;

            await _roleRepo.UpdateAsync(current);
            await _roleRepo.SaveChangesAsync();

            return Ok(new { success = true, message = "Berhasil memperbarui role." });
        }

        [HttpDelete("roles/{id}")]
        public async Task<IActionResult> DeleteRole(int id)
        {
            var hasUsers = await _roleRepo.HasUsersAsync(id);
            if (hasUsers)
                return BadRequest(new { success = false, message = "Tidak bisa menghapus role yang masih digunakan oleh user." });

            await _roleRepo.DeleteAsync(id);
            await _roleRepo.SaveChangesAsync();

            return Ok(new { success = true, message = "Berhasil menghapus role." });
        }

        // ==================== MENU ROLES API ====================

        [HttpGet("menu-roles")]
        public async Task<IActionResult> GetMenuRoles([FromQuery] int? roleId = null)
        {
            var query = _context.MenuRoles.Include(m => m.Role).AsQueryable();
            if (roleId.HasValue && roleId.Value > 0)
            {
                query = query.Where(m => m.RoleId == roleId.Value);
            }

            var menus = await query
                .OrderBy(m => m.RoleId).ThenBy(m => m.Urutan)
                .Select(m => new {
                    m.Id,
                    m.RoleId,
                    RoleName = m.Role != null ? m.Role.NamaRole : "-",
                    m.NamaMenu,
                    Icon = m.Icon ?? "",
                    m.Url,
                    m.Urutan
                })
                .ToListAsync();

            return Ok(menus);
        }

        [HttpPost("menu-roles")]
        public async Task<IActionResult> CreateMenuRole([FromBody] CreateMenuRoleDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.NamaMenu))
                return BadRequest(new { success = false, message = "Nama menu wajib diisi." });
            if (string.IsNullOrWhiteSpace(dto.Url))
                return BadRequest(new { success = false, message = "URL wajib diisi." });
            if (dto.RoleId <= 0)
                return BadRequest(new { success = false, message = "Pilih role terlebih dahulu." });

            var menuRole = new MenuRole
            {
                RoleId = dto.RoleId,
                NamaMenu = dto.NamaMenu,
                Icon = dto.Icon,
                Url = dto.Url,
                Urutan = dto.Urutan
            };

            await _menuRoleRepo.AddAsync(menuRole);
            await _menuRoleRepo.SaveChangesAsync();

            return Ok(new { success = true, message = "Berhasil menambah menu role baru." });
        }

        [HttpPut("menu-roles/{id}")]
        public async Task<IActionResult> EditMenuRole(int id, [FromBody] EditMenuRoleDto dto)
        {
            if (id != dto.Id)
                return BadRequest(new { success = false, message = "ID tidak cocok." });

            var current = await _menuRoleRepo.GetByIdAsync(id);
            if (current == null)
                return NotFound(new { success = false, message = "Menu role tidak ditemukan." });

            if (string.IsNullOrWhiteSpace(dto.NamaMenu))
                return BadRequest(new { success = false, message = "Nama menu wajib diisi." });
            if (string.IsNullOrWhiteSpace(dto.Url))
                return BadRequest(new { success = false, message = "URL wajib diisi." });
            if (dto.RoleId <= 0)
                return BadRequest(new { success = false, message = "Pilih role terlebih dahulu." });

            current.RoleId = dto.RoleId;
            current.NamaMenu = dto.NamaMenu;
            current.Icon = dto.Icon;
            current.Url = dto.Url;
            current.Urutan = dto.Urutan;

            await _menuRoleRepo.UpdateAsync(current);
            await _menuRoleRepo.SaveChangesAsync();

            return Ok(new { success = true, message = "Berhasil memperbarui menu role." });
        }

        [HttpDelete("menu-roles/{id}")]
        public async Task<IActionResult> DeleteMenuRole(int id)
        {
            var menuRole = await _menuRoleRepo.GetByIdAsync(id);
            if (menuRole == null)
                return NotFound(new { success = false, message = "Menu role tidak ditemukan." });

            await _menuRoleRepo.DeleteAsync(id);
            await _menuRoleRepo.SaveChangesAsync();

            return Ok(new { success = true, message = "Berhasil menghapus menu role." });
        }
    }
}
