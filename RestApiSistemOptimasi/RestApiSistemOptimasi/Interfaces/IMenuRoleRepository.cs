using RestApiSistemOptimasi.Models.Entities;

namespace RestApiSistemOptimasi.Interfaces
{
    public interface IMenuRoleRepository
    {
        Task<IEnumerable<MenuRole>> GetByRoleIdAsync(int roleId);
        Task<IEnumerable<MenuRole>> GetAllAsync();
        Task<MenuRole?> GetByIdAsync(int id);
        Task AddAsync(MenuRole menuRole);
        Task UpdateAsync(MenuRole menuRole);
        Task DeleteAsync(int id);
        Task SaveChangesAsync();
    }
}

