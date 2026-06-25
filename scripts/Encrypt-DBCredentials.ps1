# Script to encrypt database credentials using DPAPI
# Usage: .\Encrypt-DBCredentials.ps1

param(
    [string]$ConfigPath = "$PSScriptRoot\..\config\db-credentials.encrypted"
)

# Prompt for credentials
Write-Host "Enter database credentials to encrypt:"
$serverName = Read-Host "Server name (sql-epr-qa-eastus2.database.windows.net)"
$databaseName = Read-Host "Database name (sqldb-epr-qa)"
$username = Read-Host "Username (db-admin@sql-epr-qa-eastus2)"
$password = Read-Host "Password" -AsSecureString

# Create credentials object
$credentials = @{
    ServerName = $serverName
    DatabaseName = $databaseName
    Username = $username
    Password = $password | ConvertFrom-SecureString
}

# Export to encrypted file (DPAPI - tied to Windows user)
$credentials | ConvertTo-Json | Out-File $ConfigPath -Force

Write-Host "[SUCCESS] Credentials encrypted and stored at: $ConfigPath" -ForegroundColor Green
Write-Host "  Encrypted with DPAPI - only accessible by current Windows user on this machine"
