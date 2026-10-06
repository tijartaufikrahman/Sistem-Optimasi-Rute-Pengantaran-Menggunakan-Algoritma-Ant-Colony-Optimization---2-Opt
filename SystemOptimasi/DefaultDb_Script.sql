-- Buat database DefaultDb
CREATE DATABASE DefaultDb;
GO
USE DefaultDb;
GO

-- Tabel Roles
IF OBJECT_ID('Roles', 'U') IS NOT NULL DROP TABLE Roles;
GO
CREATE TABLE Roles (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    NamaRole NVARCHAR(50) NOT NULL,
    Deskripsi NVARCHAR(200) NULL
);
GO

-- Tabel Menu_Roles
IF OBJECT_ID('Menu_Roles', 'U') IS NOT NULL DROP TABLE Menu_Roles;
GO
CREATE TABLE Menu_Roles (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    RoleId INT NOT NULL,
    NamaMenu NVARCHAR(100) NOT NULL,
    Icon NVARCHAR(100) NULL,
    Url NVARCHAR(200) NOT NULL,
    Urutan INT NOT NULL,
    CONSTRAINT FK_Menu_Roles_Roles_RoleId FOREIGN KEY (RoleId) REFERENCES Roles(Id) ON DELETE CASCADE
);
GO

-- Tabel Users
IF OBJECT_ID('Users', 'U') IS NOT NULL DROP TABLE Users;
GO
CREATE TABLE Users (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    NamaLengkap NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    PasswordHash NVARCHAR(255) NOT NULL,
    RoleId INT NOT NULL,
    IsActive BIT NOT NULL,
    ResetPasswordToken NVARCHAR(MAX) NULL,
    ResetPasswordExpiry DATETIME2 NULL,
    CreatedAt DATETIME2 NOT NULL,
    UpdatedAt DATETIME2 NULL,
    CONSTRAINT FK_Users_Roles_RoleId FOREIGN KEY (RoleId) REFERENCES Roles(Id) ON DELETE CASCADE
);
GO

CREATE INDEX IX_Menu_Roles_RoleId ON Menu_Roles(RoleId);
CREATE INDEX IX_Users_RoleId ON Users(RoleId);
GO

SET IDENTITY_INSERT Roles ON;
INSERT INTO Roles (Id, NamaRole, Deskripsi) VALUES
(1, N'Admin', N'Administrator sistem dengan akses penuh'),
(2, N'Guest', N'Tamu dengan akses terbatas');
SET IDENTITY_INSERT Roles OFF;
GO

SET IDENTITY_INSERT Menu_Roles ON;
INSERT INTO Menu_Roles (Id, RoleId, NamaMenu, Icon, Url, Urutan) VALUES
(1, 1, N'Dashboard', N'fas fa-tachometer-alt', N'/Admin/Dashboard', 1),
(2, 1, N'Database', N'fas fa-database', N'/Admin/Database', 2),
(3, 2, N'Halaman Depan', N'fas fa-home', N'/Home/Index', 1);
SET IDENTITY_INSERT Menu_Roles OFF;
GO

SET IDENTITY_INSERT Users ON;
INSERT INTO Users (Id, NamaLengkap, Email, PasswordHash, RoleId, IsActive, ResetPasswordToken, ResetPasswordExpiry, CreatedAt, UpdatedAt) VALUES
(1, N'Administrator', N'admin@example.com', N'$2a$11$93mOPK/u6I2lupLLDEggA.2nr.JLS0iDY0kGbUBdTGhzoJu8vMtaq', 1, 1, NULL, NULL, SYSUTCDATETIME(), NULL),
(2, N'Tamu', N'guest@example.com', N'$2a$11$O8u72u3ubzX4wUh33Rvf4eXND9K63uWnUVxN2A8QDT/5oFO0HpT0.', 2, 1, NULL, NULL, SYSUTCDATETIME(), NULL);
SET IDENTITY_INSERT Users OFF;
GO
