// Sidebar toggle
document.addEventListener("DOMContentLoaded", function () {
    var sidebar = document.getElementById("sidebar");
    var mainContent = document.getElementById("mainContent");
    var overlay = document.getElementById("sidebarOverlay");
    var menuToggle = document.getElementById("menuToggle");
    var topbar = document.querySelector(".topbar");

    function isMobile() { return window.innerWidth <= 768; }

    function setSidebarState(open) {
        if (isMobile()) {
            if (open) {
                sidebar && sidebar.classList.remove("closed");
                overlay && overlay.classList.add("show");
            } else {
                sidebar && sidebar.classList.add("closed");
                overlay && overlay.classList.remove("show");
            }
        } else {
            if (open) {
                sidebar && sidebar.classList.remove("closed");
                mainContent && mainContent.classList.remove("sidebar-closed");
                if (topbar) topbar.style.left = "260px";
            } else {
                sidebar && sidebar.classList.add("closed");
                mainContent && mainContent.classList.add("sidebar-closed");
                if (topbar) topbar.style.left = "0";
            }
        }
    }

    if (menuToggle) {
        menuToggle.addEventListener("click", function () {
            var isOpen = sidebar && !sidebar.classList.contains("closed");
            setSidebarState(!isOpen);
        });
    }

    if (overlay) {
        overlay.addEventListener("click", function () {
            setSidebarState(false);
        });
    }

    // On mobile, start closed
    if (isMobile()) {
        setSidebarState(false);
    }

    window.addEventListener("resize", function () {
        if (!isMobile()) {
            setSidebarState(true);
            overlay && overlay.classList.remove("show");
        }
    });
});
