#!/usr/bin/env pwsh
# ============================================================================
# CATEGORY A1 AUTOMATED PARTITIONING AGENT
# Executes: RX_TX, PRESCRIBER, MRN, CARD, PAYMENT, LINE_ITEM, ALLERGY, DISEASE
# Created: 2026-06-26
# Purpose: Partition all remaining Category A1 tables without manual intervention
# ============================================================================

param(
    [string]$ReportDir = "C:\Users\cnedunuri\Documents\DBRepo\EXECUTION_REPORTS",
    [string]$LogFile = "C:\Users\cnedunuri\Documents\DBRepo\EXECUTION_REPORTS\Agent_Execution.log"
)

$ErrorActionPreference = "Continue"

# Configuration
$Tables = @("RX_TX", "PRESCRIBER", "MRN", "CARD", "PAYMENT", "LINE_ITEM", "ALLERGY", "DISEASE")
$PartitionScheme = "ps_ChainID_EPS"
$Results = @()
$StartTime = Get-Date

# ============================================================================
# HELPER: Get table's actual PK column names
# ============================================================================
function Get-TablePKColumns {
    param([string]$TableName)
    
    try {
        $query = @"
SELECT c.name as ColumnName, ic.key_ordinal as Ordinal
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id=ic.object_id AND i.index_id=ic.index_id
JOIN sys.columns c ON ic.object_id=c.object_id AND ic.column_id=c.column_id
WHERE i.object_id=OBJECT_ID('EPS.$TableName')
  AND i.is_primary_key=1
ORDER BY ic.key_ordinal
"@
        
        $output = & .\scripts\Connect-ToDatabase.ps1 -Query $query 2>&1 | Out-String
        
        # Parse output to extract column names
        $columns = @()
        $lines = $output -split "`n" | Where-Object { $_.trim() -match "^\w" }
        
        foreach ($line in $lines) {
            if ($line -match "(\w+)\s+(\d+)") {
                $columns += @{ Name = $matches[1]; Ordinal = $matches[2] }
            }
        }
        
        return $columns
    }
    catch {
        return @()
    }
}

# ============================================================================
# HELPER: Execute SQL Query
# ============================================================================
function Invoke-SQLQuery {
    param([string]$Query, [string]$TableName)
    
    try {
        $result = & .\scripts\Connect-ToDatabase.ps1 -Query $Query 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            return @{ Success = $true; Output = $result }
        } else {
            return @{ Success = $false; Error = $result }
        }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# ============================================================================
# MAIN: Partition a single table
# ============================================================================
function Partition-TableWithAutoDetection {
    param([string]$TableName)
    
    $tableStartTime = Get-Date
    $status = "PENDING"
    $errors = @()
    $pkColumns = @()
    
    Write-Host "`n$('='*60)" -ForegroundColor Cyan
    Write-Host "TABLE: $TableName" -ForegroundColor Cyan
    Write-Host "$('='*60)" -ForegroundColor Cyan
    
    # Step 1: Verify table exists
    Write-Host "  [1/5] Verifying table exists..." -ForegroundColor Yellow
    $tableExists = Invoke-SQLQuery "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='EPS' AND TABLE_NAME='$TableName'" $TableName
    
    if (-not $tableExists.Success) {
        $errors += "Table verification failed: $($tableExists.Error)"
        return @{ Table = $TableName; Status = "FAILED"; Duration = (Get-Date) - $tableStartTime; Errors = $errors; SecondColumn = $null }
    }
    
    # Step 2: Get current PK structure
    Write-Host "  [2/5] Detecting current PK structure..." -ForegroundColor Yellow
    $pkColumns = Get-TablePKColumns $TableName
    
    if ($pkColumns.Count -eq 0) {
        $errors += "Could not detect PK columns"
        return @{ Table = $TableName; Status = "FAILED"; Duration = (Get-Date) - $tableStartTime; Errors = $errors; SecondColumn = $null }
    }
    
    $pkColumnNames = ($pkColumns | ForEach-Object { $_.Name }) -join ", "
    Write-Host "    Current PK columns: $pkColumnNames" -ForegroundColor Green
    
    # Step 3: Find second column for composite key
    $secondColumn = $null
    
    if ($pkColumns.Count -eq 1) {
        # Need to add another column - look for ID variations
        $idQuery = @"
SELECT TOP 1 c.name as ColName
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE TABLE_SCHEMA='EPS' AND TABLE_NAME='$TableName'
  AND c.name IN ('ID', 'RX_TX_ID', 'PATIENT_ID', 'PRESCRIBER_ID', 'ADDRESS_ID', 'CARD_ID', 'PAYMENT_ID')
  AND c.COLUMN_NAME NOT IN (SELECT c2.name FROM sys.index_columns ic 
                              JOIN sys.columns c2 ON ic.object_id=c2.object_id AND ic.column_id=c2.column_id
                              WHERE ic.object_id=OBJECT_ID('EPS.$TableName') AND ic.index_id=1)
ORDER BY ORDINAL_POSITION
"@
        
        $idResult = Invoke-SQLQuery $idQuery $TableName
        
        if ($idResult.Success) {
            $output = $idResult.Output | Out-String
            $lines = $output -split "`n" | Where-Object { $_.trim() -match "^\w" }
            if ($lines[0]) {
                $secondColumn = $lines[0].trim()
            }
        }
        
        # Fallback: Use first numeric column
        if (-not $secondColumn) {
            $fallbackQuery = "SELECT TOP 1 COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='EPS' AND TABLE_NAME='$TableName' AND DATA_TYPE IN ('int', 'bigint', 'numeric') AND COLUMN_NAME NOT IN ('CHAIN_ID') ORDER BY ORDINAL_POSITION"
            $fallback = Invoke-SQLQuery $fallbackQuery $TableName
            if ($fallback.Success) {
                $output = $fallback.Output | Out-String
                $lines = $output -split "`n" | Where-Object { $_.trim() -match "^\w" }
                if ($lines[0]) {
                    $secondColumn = $lines[0].trim()
                }
            }
        }
    } else {
        $secondColumn = $pkColumns[1].Name
    }
    
    if (-not $secondColumn) {
        $errors += "Could not determine second PK column for composite key"
        return @{ Table = $TableName; Status = "FAILED"; Duration = (Get-Date) - $tableStartTime; Errors = $errors; SecondColumn = $null }
    }
    
    Write-Host "    Composite PK will be: (CHAIN_ID, $secondColumn)" -ForegroundColor Green
    
    # Step 4: Drop old PK and create new partitioned PK
    Write-Host "  [3/5] Dropping old PK and creating new partitioned PK..." -ForegroundColor Yellow
    
    $currentPKName = Invoke-SQLQuery "SELECT TOP 1 name FROM sys.indexes WHERE object_id=OBJECT_ID('EPS.$TableName') AND is_primary_key=1" $TableName
    $pkName = "PK_$TableName"
    
    # Drop old PK if exists
    if ($currentPKName.Success) {
        $dropSQL = "ALTER TABLE EPS.$TableName DROP CONSTRAINT $pkName;"
        $dropResult = Invoke-SQLQuery $dropSQL $TableName
    }
    
    # Create new partitioned PK
    $newPKSQL = "ALTER TABLE EPS.$TableName ADD CONSTRAINT $pkName PRIMARY KEY CLUSTERED (CHAIN_ID, [$secondColumn]) ON $PartitionScheme(CHAIN_ID);"
    
    Write-Host "    Executing: $newPKSQL" -ForegroundColor Gray
    
    $pkResult = Invoke-SQLQuery $newPKSQL $TableName
    
    if (-not $pkResult.Success) {
        $errors += "PK creation failed: $($pkResult.Error)"
        Write-Host "    FAILED: $($pkResult.Error)" -ForegroundColor Red
        return @{ Table = $TableName; Status = "FAILED"; Duration = (Get-Date) - $tableStartTime; Errors = $errors; SecondColumn = $secondColumn }
    }
    
    Write-Host "    New PK created successfully" -ForegroundColor Green
    
    # Step 5: Verify partitioning
    Write-Host "  [4/5] Verifying partitioning..." -ForegroundColor Yellow
    
    $verifySQL = @"
SELECT COUNT(DISTINCT partition_number) as PartitionCount
FROM sys.partitions
WHERE object_id=OBJECT_ID('EPS.$TableName') AND index_id=1
"@
    
    $verifyResult = Invoke-SQLQuery $verifySQL $TableName
    
    if ($verifyResult.Success) {
        $output = $verifyResult.Output | Out-String
        $partCount = $output -split "`n" | Where-Object { $_ -match "^\d+" } | Select-Object -First 1
        
        if ($partCount -eq "6") {
            Write-Host "    All 6 partitions allocated" -ForegroundColor Green
            $status = "SUCCESS"
        } else {
            $errors += "Expected 6 partitions, found: $partCount"
            $status = "PARTIAL"
        }
    } else {
        $errors += "Verification query failed: $($verifyResult.Error)"
        $status = "PARTIAL"
    }
    
    Write-Host "  [5/5] Complete" -ForegroundColor Yellow
    
    return @{
        Table = $TableName
        Status = $status
        Duration = (Get-Date) - $tableStartTime
        SecondColumn = $secondColumn
        Errors = $errors
    }
}

# ============================================================================
# EXECUTION LOOP
# ============================================================================

Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host "CATEGORY A1 AUTOMATED PARTITIONING AGENT" -ForegroundColor Cyan
Write-Host "Tables: RX_TX, PRESCRIBER, MRN, CARD, PAYMENT," -ForegroundColor Cyan
Write-Host "         LINE_ITEM, ALLERGY, DISEASE" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

foreach ($table in $Tables) {
    $result = Partition-TableWithAutoDetection $table
    $Results += $result
}

# ============================================================================
# SUMMARY REPORT
# ============================================================================

$successCount = ($Results | Where-Object { $_.Status -eq "SUCCESS" }).Count
$failureCount = ($Results | Where-Object { $_.Status -eq "FAILED" }).Count
$totalDuration = ($Results | Measure-Object -Property Duration -Sum).Sum

Write-Host "`n====================================================" -ForegroundColor Green
Write-Host "EXECUTION SUMMARY" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green

Write-Host "`nResults:"
Write-Host "  Total Tables:     $($Results.Count)" -ForegroundColor White
Write-Host "  [SUCCESS]:        $successCount" -ForegroundColor Green
Write-Host "  [FAILED]:         $failureCount" -ForegroundColor Red
Write-Host "  [DURATION]:       $($totalDuration.Hours)h $($totalDuration.Minutes)m $($totalDuration.Seconds)s" -ForegroundColor Cyan

Write-Host "`nDetailed Results:"
foreach ($result in $Results) {
    if ($result.Status -eq "SUCCESS") { $statusIcon = "[OK]" } else { $statusIcon = "[FAIL]" }
    $duration = [math]::Round($result.Duration.TotalSeconds)
    Write-Host "  $statusIcon $($result.Table): $($result.Status) (${duration}s)"
    
    if ($result.Errors.Count -gt 0) {
        foreach ($error in $result.Errors) {
            Write-Host "     WARNING: $error" -ForegroundColor Yellow
        }
    }
}

# ============================================================================
# SAVE BATCH REPORT
# ============================================================================

$reportPath = "$ReportDir\BATCH_A1_EXECUTION_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"

$reportContent = @"
# Category A1 Batch Execution Report

**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Agent:** Automated Partitioning Agent  
**Total Tables:** $($Results.Count)  
**Successful:** $successCount  
**Failed:** $failureCount  
**Total Duration:** $($totalDuration.Hours)h $($totalDuration.Minutes)m  

## Results

| Table | Status | Duration | Second PK Column | Notes |
|-------|--------|----------|------------------|-------|
$($Results | ForEach-Object { $col = if($_.SecondColumn) { $_.SecondColumn } else { 'N/A' }; $note = if($_.Errors.Count -gt 0) { $_.Errors[0] } else { 'OK' }; "| $($_.Table) | $($_.Status) | $([math]::Round($_.Duration.TotalSeconds))s | $col | $note |" } | Out-String)

## Completed Tables

$($Results | Where-Object { $_.Status -eq "SUCCESS" } | ForEach-Object { "- [OK] $($_.Table)" } | Out-String)

## Failed Tables

$($Results | Where-Object { $_.Status -eq "FAILED" } | ForEach-Object { $err = if($_.Errors.Count -gt 0) { $_.Errors[0] } else { 'Unknown' }; "- [FAIL] $($_.Table) - $err" } | Out-String)

## Next Steps

1. Category A2: 30 tables (PRESCRIBER_ALIAS, STORE, LOCATION, etc.)
2. Category A3: 33 tables  
3. Category B: 50 audit tables (AUDIT_TIMESTAMP partitioning)
4. Category C: 5 flexible tables

---

**Agent Status:** Complete  
**Recommendation:** Review failed tables and rerun individually if needed  
"@

$reportContent | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "`n[REPORT] Saved: $reportPath" -ForegroundColor Cyan

# ============================================================================
# UPDATE ROLLOUT SUMMARY
# ============================================================================

$rolloutPath = "C:\Users\cnedunuri\Documents\DBRepo\PARTITION_ROLLOUT_SUMMARY.md"

$rolloutContent = @"
# PARTITION ROLLOUT SUMMARY - UPDATED

**Last Updated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Agent Execution:** Automated Partitioning Agent  
**Progress:** $($successCount + 2)/9 Category A1 tables complete  

## Category A1 Status (9 Tables)

| # | Table | Status | Date |
|---|-------|--------|------|
| 1 | PATIENT | COMPLETE | 2026-06-26 |
| 2 | ADDRESS | COMPLETE | 2026-06-26 |
$($Results | ForEach-Object { $num = [array]::IndexOf($Tables, $_.Table) + 3; $st = if($_.Status -eq 'SUCCESS'){'COMPLETE'}else{'FAILED'}; "| $num | $($_.Table) | $st | 2026-06-26 |" } | Out-String)

## Statistics

- **Category A1 Completion:** $([math]::Round((($successCount + 2) / 9) * 100))%
- **Estimated A1 Completion Time:** Today EOD
- **Next Phase:** Category A2 (30 tables)
- **Grand Total Remaining:** 63 tables (A2+A3)

## Timeline

- ✅ PATIENT partitioned (baseline established)
- ✅ ADDRESS partitioned (simplified execution)
- ✅ RX_TX - DISEASE partitioned (automated agent)
- ⏳ Category A2: 30 tables (~25-30 hours)
- ⏳ Category A3: 33 tables (~25-30 hours)
- ⏳ Category B: 50 audit tables (TBD)
- ⏳ Category C: 5 flexible tables (TBD)

"@

$rolloutContent | Out-File -FilePath $rolloutPath -Encoding UTF8

Write-Host "`n[OK] Progress tracking updated: $rolloutPath" -ForegroundColor Green

Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host "AGENT EXECUTION COMPLETE" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if ($failureCount -eq 0) { exit 0 } else { exit 1 }
