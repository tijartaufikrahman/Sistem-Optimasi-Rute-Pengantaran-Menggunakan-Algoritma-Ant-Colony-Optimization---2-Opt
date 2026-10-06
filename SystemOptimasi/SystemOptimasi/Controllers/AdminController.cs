using Microsoft.AspNetCore.Mvc;

namespace SystemOptimasi.Controllers
{
    public class AdminController : Controller
    {
        public IActionResult HalamanDepan()
        {
            return RedirectToAction("Index", "Home");
        }

        public IActionResult Dashboard()
        {
            return RedirectToAction("Index", "Home");
        }

        public IActionResult Database()
        {
            ViewData["Title"] = "Database";
            return View();
        }

        public IActionResult Manifest()
        {
            ViewData["Title"] = "Manifest Kiriman";
            return View();
        }

        public IActionResult Kantor()
        {
            ViewData["Title"] = "Kantor / Hub Distribusi";
            return View();
        }

        public IActionResult Drs()
        {
            ViewData["Title"] = "Delivery Run Sheet";
            return View();
        }

        public IActionResult DrsDetail(int id)
        {
            ViewData["Title"] = "Detail Delivery Run Sheet";
            ViewData["DrsId"] = id;
            return View();
        }

        public IActionResult DrsHistory()
        {
            ViewData["Title"] = "History Delivery Run Sheet";
            return View();
        }
    }
}
