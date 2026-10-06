using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SystemOptimasi.Models;
using System.Diagnostics;

namespace SystemOptimasi.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;

        public HomeController(ILogger<HomeController> logger)
        {
            _logger = logger;
        }

        public IActionResult Index()
        {
            // Redirect based on auth
            if (User.Identity?.IsAuthenticated == true)
            {
                ViewData["Title"] = "Halaman Depan";
                return View();
            }
            return RedirectToAction("Login", "Account");
        }

        public IActionResult HalamanDepan()
        {
            ViewData["Title"] = "Halaman Depan";
            return View("Index");
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}

