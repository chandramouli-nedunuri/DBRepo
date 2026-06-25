# Script to connect to database using encrypted credentials
# Usage: .\Connect-ToDatabase.ps1 -Query "SELECT 1"

param(
    [string]$Query = "SELECT @@VERSION",
    [string]$ConfigPath = "$PSScriptRoot\..\config\db-credentials.encrypted"
)

# Load encrypted credentials
if (-not (Test-Path $ConfigPath)) {
    Write-Host "✗ Credentials file not found at: $ConfigPath" -ForegroundColor Red
    Write-Host "  Run Encrypt-DBCredentials.ps1 first to create encrypted credentials"
    exit 1
}

try {
    $credentialsJson = Get-Content $ConfigPath | ConvertFrom-Json
    $serverName = $credentialsJson.ServerName
    $databaseName = $credentialsJson.DatabaseName
    $username = $credentialsJson.Username
    $securePassword = $credentialsJson.Password | ConvertTo-SecureString
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemAlloc($securePassword))
    
    # Build connection string
    $connectionString = "Server=$serverName;Database=$databaseName;User Id=$username;Password=$plainPassword;Encrypt=true;TrustServerCertificate=false;"
    
    # Connect
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()
    
    Write-Host "✓ Connected to Azure SQL successfully" -ForegroundColor Green
    Write-Host "  Server: $serverName" -ForegroundColor Gray
    Write-Host "  Database: $databaseName" -ForegroundColor Gray
    
    # Execute query
    if ($Query) {
        $cmd = New-Object System.Data.SqlClient.SqlCommand($Query, $connection)
        $cmd.CommandTimeout = 30
        $result = $cmd.ExecuteReader()
        
        Write-Host "`nQuery Results:" -ForegroundColor Cyan
        while ($result.Read()) {
            for ($i = 0; $i -lt $result.FieldCount; $i++) {
                Write-Host "$($result.GetName($i)): $($result[$i])"
            }
            Write-Host ""
        }
        $result.Close()
    }
    
    $connection.Close()
    
} catch {
    Write-Host "✗ Error: $_" -ForegroundColor Red
    exit 1
}
