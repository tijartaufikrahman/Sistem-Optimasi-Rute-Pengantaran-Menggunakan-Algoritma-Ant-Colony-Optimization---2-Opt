using Microsoft.AspNetCore.Mvc;
using RestApiSistemOptimasi.Interfaces;
using RestApiSistemOptimasi.Models.DTOs;

namespace RestApiSistemOptimasi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly IAuthService _authService;
        private readonly ILogger<AuthController> _logger;

        public AuthController(IAuthService authService, ILogger<AuthController> logger)
        {
            _authService = authService;
            _logger = logger;
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequestDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Email) || string.IsNullOrWhiteSpace(model.Password))
                return BadRequest(ApiResponse.Fail("Email dan password wajib diisi."));

            var user = await _authService.LoginAsync(model.Email, model.Password);
            if (user == null)
            {
                return Unauthorized(ApiResponse.Fail("Email atau password salah. Silakan coba lagi."));
            }

            var userDto = new UserDto
            {
                Id = user.Id,
                NamaLengkap = user.NamaLengkap,
                Email = user.Email,
                RoleId = user.RoleId,
                RoleName = user.Role?.NamaRole ?? "Guest",
                RoleType = user.Role?.RoleType ?? 0,
                IsActive = user.IsActive,
                CreatedAt = user.CreatedAt.ToLocalTime().ToString("dd/MM/yyyy HH:mm")
            };

            _logger.LogInformation("API Login sukses: {Email}", model.Email);
            return Ok(ApiResponse.Ok("Login berhasil.", userDto));
        }

        [HttpPost("forgot-password")]
        public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequestDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Email))
                return BadRequest(ApiResponse.Fail("Email wajib diisi."));

            var resetUrl = !string.IsNullOrWhiteSpace(model.ResetBaseUrl)
                ? model.ResetBaseUrl
                : $"{Request.Scheme}://{Request.Host}/Account/ResetPassword";

            await _authService.ForgotPasswordAsync(model.Email, resetUrl);
            return Ok(ApiResponse.Ok("Jika email terdaftar di sistem, link reset password telah dikirim."));
        }

        [HttpGet("validate-reset-token")]
        public async Task<IActionResult> ValidateResetToken([FromQuery] string token)
        {
            if (string.IsNullOrWhiteSpace(token))
                return BadRequest(ApiResponse.Fail("Token wajib disertakan."));

            var isValid = await _authService.ValidateResetTokenAsync(token);
            if (!isValid)
                return BadRequest(ApiResponse.Fail("Token reset password tidak valid atau telah kedaluwarsa."));

            return Ok(ApiResponse.Ok("Token valid."));
        }

        [HttpPost("reset-password")]
        public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequestDto model)
        {
            if (string.IsNullOrWhiteSpace(model.Token) || string.IsNullOrWhiteSpace(model.NewPassword))
                return BadRequest(ApiResponse.Fail("Token dan password baru wajib diisi."));

            var result = await _authService.ResetPasswordAsync(model.Token, model.NewPassword);
            if (!result)
                return BadRequest(ApiResponse.Fail("Link reset password tidak valid atau telah kedaluwarsa."));

            return Ok(ApiResponse.Ok("Password berhasil diubah! Silakan login dengan password baru Anda."));
        }
    }
}
