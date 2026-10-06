using Microsoft.EntityFrameworkCore;
using RestApiSistemOptimasi.Data;
using RestApiSistemOptimasi.Interfaces;
using RestApiSistemOptimasi.Models.Entities;

namespace RestApiSistemOptimasi.Repositories
{
    public class MenuRoleRepository : IMenuRoleRepository
    {
        private readonly AppDbContext _context;

        public MenuRoleRepository(AppDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<MenuRole>> GetByRoleIdAsync(int roleId)
            => await _context.MenuRoles
                .Where(m => m.RoleId == roleId)
                .OrderBy(m => m.Urutan)
                .ToListAsync();

        public async Task<IEnumerable<MenuRole>> GetAllAsync()
            => await _context.MenuRoles.Include(m => m.Role)
                .OrderBy(m => m.RoleId).ThenBy(m => m.Urutan)
                .ToListAsync();

        public async Task<MenuRole?> GetByIdAsync(int id)
            => await _context.MenuRoles.FindAsync(id);

        public async Task AddAsync(MenuRole menuRole)
            => await _context.MenuRoles.AddAsync(menuRole);

        public Task UpdateAsync(MenuRole menuRole)
        {
            _context.MenuRoles.Update(menuRole);
            return Task.CompletedTask;
        }

        public async Task DeleteAsync(int id)
        {
            var menuRole = await _context.MenuRoles.FindAsync(id);
            if (menuRole != null) _context.MenuRoles.Remove(menuRole);
        }

        public async Task SaveChangesAsync()
            => await _context.SaveChangesAsync();
    }
}

