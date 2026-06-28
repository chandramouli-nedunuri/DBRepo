#!/usr/bin/env pwsh
# Category A1 Batch Partitioning - Simplified

$tables = @("RX_TX", "PRESCRIBER", "MRN", "CARD", "PAYMENT", "LINE_ITEM", "ALLERGY", "DISEASE")
$results = @()

foreach ($table in $tables) {
    Write-Host "`n========== PARTITIONING: $table ==========" -ForegroundColor Cyan
    
    # Phase 3: Create partitioned PK
    $sql = "ALTER TABLE EPS.$table ADD CONSTRAINT PK_$table PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);"
    
    $result = & .\scripts\Connect-ToDatabase.ps1 -Query $sql 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ $table PARTITIONED" -ForegroundColor Green
        $results += @{ Table = $table; Status = "SUCCESS" }
    } else {
        Write-Host "❌ $table FAILED: $result" -ForegroundColor Red
        $results += @{ Table = $table; Status = "FAILED"; Error = $result }
    }
}

Write-Host "`n========== SUMMARY ==========" -ForegroundColor Cyan
$success = ($results | Where-Object { $_.Status -eq "SUCCESS" }).Count
Write-Host "✅ Successful: $success/$($results.Count)" -ForegroundColor Green
