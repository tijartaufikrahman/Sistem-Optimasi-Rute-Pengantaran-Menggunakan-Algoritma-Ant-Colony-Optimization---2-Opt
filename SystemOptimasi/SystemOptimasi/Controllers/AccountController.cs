using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using SystemOptimasi.Models.ViewModels;

namespace SystemOptimasi.Controllers
{
    public class AccountController : Controller
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;
        private readonly ILogger<AccountController> _logger;

        public AccountController(
            IHttpClientFactory httpClientFactory,
            IConfiguration configuration,
            ILogger<AccountController> logger)
        {
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
            _logger = logger;
        }

        private string BaseApiUrl => _configuration["ApiSettings:BaseUrl"] ?? "http://localhost:5064";

        [HttpGet]
        public IActionResult Login(string? returnUrl = null)
        {
            if (User.Identity?.IsAuthenticated == true)
                return RedirectToUserHome();

            ViewData["ReturnUrl"] = returnUrl;
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Login(LoginViewModel model, string? returnUrl = null)
        {
            if (!ModelState.IsValid)
                return View(model);

            try
            {
                var client = _httpClientFactory.CreateClient();
                var jsonContent = new StringContent(
                    JsonSerializer.Serialize(new { email = model.Email, password = model.Password, rememberMe = model.RememberMe }),
                    Encoding.UTF8,
                    "application/json"
                );

                var response = await client.PostAsync($"{BaseApiUrl}/api/auth/login", jsonContent);
                var respBody = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                {
                    var errObj = JsonSerializer.Deserialize<JsonElement>(respBody);
                    var msg = errObj.TryGetProperty("message", out var m) ? m.GetString() : "Email atau password salah.";
                    ModelState.AddModelError(string.Empty, msg ?? "Email atau password salah.");
                    return View(model);
                }

                var resObj = JsonSerializer.Deserialize<JsonElement>(respBody);
                var data = resObj.GetProperty("data");

                var userId = data.GetProperty("id").GetInt32().ToString();
                var namaLengkap = data.GetProperty("namaLengkap").GetString() ?? "";
                var email = data.GetProperty("email").GetString() ?? "";
                var roleId = data.GetProperty("roleId").GetInt32().ToString();
                var roleName = data.GetProperty("roleName").GetString() ?? "Guest";
                var roleType = data.TryGetProperty("roleType", out var rt) ? rt.GetInt32() : 0;

                // Validasi: Portal Web hanya dapat diakses oleh RoleType 0 (Web) atau 2 (All)
                if (roleType != 0 && roleType != 2)
                {
                    ModelState.AddModelError(string.Empty, "Akun Anda hanya dapat digunakan melalui aplikasi Mobile (Oranger). Akses web ditolak.");
                    return View(model);
                }

                var claims = new List<Claim>
                {
                    new Claim(ClaimTypes.NameIdentifier, userId),
                    new Claim(ClaimTypes.Name, namaLengkap),
                    new Claim(ClaimTypes.Email, email),
                    new Claim(ClaimTypes.Role, roleName),
                    new Claim("RoleId", roleId),
                    new Claim("RoleType", roleType.ToString())
                };

                var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
                var principal = new ClaimsPrincipal(identity);

                var authProps = new AuthenticationProperties
                {
                    IsPersistent = model.RememberMe,
                    ExpiresUtc = model.RememberMe ? DateTimeOffset.UtcNow.AddDays(30) : DateTimeOffset.UtcNow.AddHours(8)
                };

                await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal, authProps);
                _logger.LogInformation("User {Email} berhasil login via API", model.Email);

                if (!string.IsNullOrEmpty(returnUrl) && Url.IsLocalUrl(returnUrl))
                    return Redirect(returnUrl);

                return RedirectToUserHome();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Gagal menghubungi API server saat login");
                ModelState.AddModelError(string.Empty, "Tidak dapat terhubung ke server RestApi. Pastikan RestApiSistemOptimasi sedang berjalan.");
                return View(model);
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Logout()
        {
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return RedirectToAction(nameof(Login));
        }

        [HttpGet]
        public IActionResult ForgotPassword()
        {
            if (User.Identity?.IsAuthenticated == true)
                return RedirectToUserHome();
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ForgotPassword(ForgotPasswordViewModel model)
        {
            if (!ModelState.IsValid)
                return View(model);

            try
            {
                var client = _httpClientFactory.CreateClient();
                var resetBaseUrl = Url.Action("ResetPassword", "Account", null, Request.Scheme) ?? "";

                var jsonContent = new StringContent(
                    JsonSerializer.Serialize(new { email = model.Email, resetBaseUrl }),
                    Encoding.UTF8,
                    "application/json"
                );

                await client.PostAsync($"{BaseApiUrl}/api/auth/forgot-password", jsonContent);

                TempData["ForgotPasswordSuccess"] = "Jika email terdaftar di sistem, link reset password telah dikirim.";
                return RedirectToAction(nameof(ForgotPasswordConfirmation));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Gagal memanggil API forgot password");
                TempData["ForgotPasswordSuccess"] = "Jika email terdaftar di sistem, link reset password telah dikirim.";
                return RedirectToAction(nameof(ForgotPasswordConfirmation));
            }
        }

        [HttpGet]
        public IActionResult ForgotPasswordConfirmation()
        {
            return View();
        }

        [HttpGet]
        public async Task<IActionResult> ResetPassword(string? token = null)
        {
            if (string.IsNullOrEmpty(token))
                return RedirectToAction(nameof(Login));

            try
            {
                var client = _httpClientFactory.CreateClient();
                var response = await client.GetAsync($"{BaseApiUrl}/api/auth/validate-reset-token?token={Uri.EscapeDataString(token)}");

                if (!response.IsSuccessStatusCode)
                {
                    TempData["ResetError"] = "Link reset password tidak valid atau telah kedaluwarsa. Silakan minta link baru.";
                    return RedirectToAction(nameof(ForgotPassword));
                }

                var model = new ResetPasswordViewModel { Token = token };
                return View(model);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Gagal validasi token via API");
                TempData["ResetError"] = "Tidak dapat terhubung ke server backend.";
                return RedirectToAction(nameof(ForgotPassword));
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ResetPassword(ResetPasswordViewModel model)
        {
            if (!ModelState.IsValid)
                return View(model);

            try
            {
                var client = _httpClientFactory.CreateClient();
                var jsonContent = new StringContent(
                    JsonSerializer.Serialize(new { token = model.Token, newPassword = model.NewPassword }),
                    Encoding.UTF8,
                    "application/json"
                );

                var response = await client.PostAsync($"{BaseApiUrl}/api/auth/reset-password", jsonContent);
                var respBody = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                {
                    var errObj = JsonSerializer.Deserialize<JsonElement>(respBody);
                    var msg = errObj.TryGetProperty("message", out var m) ? m.GetString() : "Gagal mereset password.";
                    ModelState.AddModelError(string.Empty, msg ?? "Gagal mereset password.");
                    return View(model);
                }

                TempData["ResetSuccess"] = "Password berhasil diubah! Silakan login dengan password baru Anda.";
                return RedirectToAction(nameof(Login));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Gagal reset password via API");
                ModelState.AddModelError(string.Empty, "Tidak dapat terhubung ke server RestApi.");
                return View(model);
            }
        }

        private IActionResult RedirectToUserHome()
        {
            return RedirectToAction("Index", "Home");
        }
    }
}
