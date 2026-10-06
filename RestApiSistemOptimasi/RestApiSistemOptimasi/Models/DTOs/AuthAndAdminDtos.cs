using RestApiSistemOptimasi.Models.Entities;

namespace RestApiSistemOptimasi.Models.DTOs
{
    public class LoginRequestDto
    {
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public bool RememberMe { get; set; }
    }

    public class LoginResponseDto
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public UserDto? User { get; set; }
    }

    public class UserDto
    {
        public int Id { get; set; }
        public string NamaLengkap { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public int RoleId { get; set; }
        public string RoleName { get; set; } = string.Empty;
        public int RoleType { get; set; }
        public bool IsActive { get; set; }
        public string CreatedAt { get; set; } = string.Empty;
    }

    public class CreateUserDto
    {
        public string NamaLengkap { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string ConfirmPassword { get; set; } = string.Empty;
        public int RoleId { get; set; }
    }

    public class EditUserDto
    {
        public int Id { get; set; }
        public string NamaLengkap { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? Password { get; set; }
        public int RoleId { get; set; }
        public bool IsActive { get; set; }
    }

    public class CreateRoleDto
    {
        public string NamaRole { get; set; } = string.Empty;
        public string? Deskripsi { get; set; }
    }

    public class EditRoleDto
    {
        public int Id { get; set; }
        public string NamaRole { get; set; } = string.Empty;
        public string? Deskripsi { get; set; }
    }

    public class CreateMenuRoleDto
    {
        public int RoleId { get; set; }
        public string NamaMenu { get; set; } = string.Empty;
        public string? Icon { get; set; }
        public string Url { get; set; } = string.Empty;
        public int Urutan { get; set; }
    }

    public class EditMenuRoleDto
    {
        public int Id { get; set; }
        public int RoleId { get; set; }
        public string NamaMenu { get; set; } = string.Empty;
        public string? Icon { get; set; }
        public string Url { get; set; } = string.Empty;
        public int Urutan { get; set; }
    }

    public class ForgotPasswordRequestDto
    {
        public string Email { get; set; } = string.Empty;
        public string? ResetBaseUrl { get; set; }
    }

    public class ResetPasswordRequestDto
    {
        public string Token { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;
    }

    public class ApiResponse
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public object? Data { get; set; }

        public static ApiResponse Ok(string message = "Sukses", object? data = null)
            => new ApiResponse { Success = true, Message = message, Data = data };

        public static ApiResponse Fail(string message = "Gagal")
            => new ApiResponse { Success = false, Message = message };
    }
}
