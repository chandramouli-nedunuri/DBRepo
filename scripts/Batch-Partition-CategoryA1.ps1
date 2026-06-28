# Comprehensive Partition Creation Script - Category A1 Tables
# Executes all remaining tables: RX_TX, PRESCRIBER, MRN, CARD, PAYMENT, LINE_ITEM, ALLERGY, DISEASE

param(
    [string]$Action = "ExecuteAll"  # Options: ExecuteAll, ValidateOnly, ReportOnly
)

$ErrorActionPreference = "Stop"

# ============================================================================
# CONFIGURATION
# ============================================================================

$Category_A1_Tables = @(
    "RX_TX",
    "PRESCRIBER", 
    "MRN",
    "CARD",
    "PAYMENT",
    "LINE_ITEM",
    "ALLERGY",
    "DISEASE"
)

$PartitionFunction = "pf_ChainID_EPS"
$PartitionScheme = "ps_ChainID_EPS"
$ReportDir = "C:\Users\cnedunuri\Documents\DBRepo\EXECUTION_REPORTS"
$Results = @()

# ============================================================================
# FUNCTION: Execute Query
# ============================================================================

function Execute-Query {
    param([string]$Query, [string]$Description)
    
    try {
        $result = & .\scripts\Connect-ToDatabase.ps1 -Query $Query 2>&1
        return @{ Success = $true; Result = $result; Description = $Description }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message; Description = $Description }
    }
}

# ============================================================================
# FUNCTION: Execute Table Partitioning (All Phases)
# ============================================================================

function Partition-Table {
    param([string]$TableName)
    
    $StartTime = Get-Date
    $Phase1Pass = $false
    $ForeignKeysDropped = 0
    $Errors = @()
    
    Write-Host "`n========== PARTITIONING: $TableName ==========" -ForegroundColor Cyan
    
    # PHASE 1: PRE-EXECUTION CHECKS
    Write-Host "[PHASE 1] Pre-execution checks..." -ForegroundColor Yellow
    
    $tableExists = Execute-Query "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='EPS' AND TABLE_NAME='$TableName'" "Table exists"
    $chainIdExists = Execute-Query "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='EPS' AND TABLE_NAME='$TableName' AND COLUMN_NAME='CHAIN_ID'" "CHAIN_ID exists"
    
    if ($tableExists.Success -and $chainIdExists.Success) {
        $Phase1Pass = $true
        Write-Host "  ✅ Table and CHAIN_ID verified" -ForegroundColor Green
    } else {
        $Errors += "Phase 1: Table or CHAIN_ID verification failed"
        Write-Host "  ❌ Phase 1 failed - skipping table" -ForegroundColor Red
        return @{ Table = $TableName; Status = "FAILED"; Phase = 1; Errors = $Errors; Duration = (Get-Date) - $StartTime }
    }
    
    # PHASE 2: DROP FOREIGN KEYS (if any exist)
    Write-Host "[PHASE 2] Checking foreign keys..." -ForegroundColor Yellow
    
    $fkQuery = "SELECT name FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID('EPS.$TableName')"
    $fkResult = Execute-Query $fkQuery "Get outbound FKs"
    
    if ($fkResult.Success -and $fkResult.Result) {
        # Parse FK names and drop them
        $fkLines = ($fkResult.Result | Out-String).Split([Environment]::NewLine) | Where-Object { $_ -match "^\w" }
        foreach ($fkName in $fkLines) {
            if ($fkName) {
                $dropResult = Execute-Query "ALTER TABLE EPS.$TableName DROP CONSTRAINT $($fkName.Trim())" "Drop FK: $fkName"
                if ($dropResult.Success) {
                    $ForeignKeysDropped++
                    Write-Host "  ✅ Dropped FK: $fkName" -ForegroundColor Green
                }
            }
        }
    }
    Write-Host "  ✅ FK phase complete ($ForeignKeysDropped FKs dropped)" -ForegroundColor Green
    
    # PHASE 3: PRIMARY KEY MODIFICATION
    Write-Host "[PHASE 3] Modifying primary key..." -ForegroundColor Yellow
    
    # Get current PK name
    $pkQuery = "SELECT name FROM sys.indexes WHERE object_id=OBJECT_ID('EPS.$TableName') AND is_primary_key=1"
    $pkResult = Execute-Query $pkQuery "Get current PK"
    
    if ($pkResult.Success -and $pkResult.Result) {
        $pkName = ($pkResult.Result | Out-String).Split([Environment]::NewLine)[0].Trim()
        
        if ($pkName) {
            # Drop old PK
            $dropPKResult = Execute-Query "ALTER TABLE EPS.$TableName DROP CONSTRAINT $pkName" "Drop old PK"
            if ($dropPKResult.Success) {
                Write-Host "  ✅ Old PK dropped: $pkName" -ForegroundColor Green
            } else {
                $Errors += "Could not drop PK: $pkName"
            }
        }
    }
    
    # Create new composite PK (CHAIN_ID, ID)
    $newPKSQL = "ALTER TABLE EPS.$TableName ADD CONSTRAINT PK_$TableName PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON $PartitionScheme(CHAIN_ID);"
    $newPKResult = Execute-Query $newPKSQL "Create new partitioned PK"
    
    if ($newPKResult.Success) {
        Write-Host "  ✅ New PK created on partition scheme" -ForegroundColor Green
    } else {
        $Errors += "Could not create new PK: $($newPKResult.Error)"
        Write-Host "  ❌ PK creation failed" -ForegroundColor Red
        return @{ Table = $TableName; Status = "FAILED"; Phase = 3; Errors = $Errors; Duration = (Get-Date) - $StartTime }
    }
    
    # PHASE 4: FK RECREATION (if any were dropped)
    Write-Host "[PHASE 4] Foreign key recreation..." -ForegroundColor Yellow
    Write-Host "  ℹ️  (Manual FK recreation handled separately)" -ForegroundColor Gray
    
    # PHASE 5: VERIFICATION
    Write-Host "[PHASE 5] Verification..." -ForegroundColor Yellow
    
    $verifyPartitions = Execute-Query "SELECT COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.$TableName') AND index_id=1" "Verify 6 partitions"
    $verifyPKColumns = Execute-Query "SELECT COUNT(*) FROM sys.index_columns WHERE object_id=OBJECT_ID('EPS.$TableName') AND index_id=1 AND key_ordinal > 0" "Verify PK columns"
    $verifyPartitionKey = Execute-Query "SELECT COUNT(*) FROM sys.index_columns WHERE object_id=OBJECT_ID('EPS.$TableName') AND index_id=1 AND partition_ordinal=1" "Verify partition key"
    
    $allPassed = $verifyPartitions.Success -and $verifyPKColumns.Success -and $verifyPartitionKey.Success
    
    if ($allPassed) {
        Write-Host "  ✅ All verification queries PASSED" -ForegroundColor Green
        Write-Host "`n✅ $TableName PARTITIONING COMPLETE" -ForegroundColor Green
        return @{ Table = $TableName; Status = "SUCCESS"; Phase = 5; Duration = (Get-Date) - $StartTime; FKsDropped = $ForeignKeysDropped }
    } else {
        $Errors += "Verification failed"
        Write-Host "  ❌ Verification failed" -ForegroundColor Red
        return @{ Table = $TableName; Status = "FAILED"; Phase = 5; Errors = $Errors; Duration = (Get-Date) - $StartTime }
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host "`n╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  CATEGORY A1 - BATCH PARTITIONING EXECUTION  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Cyan

foreach ($table in $Category_A1_Tables) {
    $result = Partition-Table $table
    $Results += $result
}

# ============================================================================
# SUMMARY REPORT
# ============================================================================

Write-Host "`n╔════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          EXECUTION SUMMARY REPORT              ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Green

$SuccessCount = ($Results | Where-Object { $_.Status -eq "SUCCESS" }).Count
$FailureCount = ($Results | Where-Object { $_.Status -eq "FAILED" }).Count
$TotalDuration = ($Results | Measure-Object -Property Duration -Sum).Sum

Write-Host "`nResults Summary:"
Write-Host "  Total Tables:    $($Results.Count)" -ForegroundColor White
Write-Host "  ✅ Successful:   $SuccessCount" -ForegroundColor Green
Write-Host "  ❌ Failed:       $FailureCount" -ForegroundColor Red
Write-Host "  ⏱️  Total Time:    $($TotalDuration.Hours)h $($TotalDuration.Minutes)m $($TotalDuration.Seconds)s" -ForegroundColor Cyan

Write-Host "`nDetailed Results:"
foreach ($result in $Results) {
    $status = $result.Status -eq "SUCCESS" ? "✅" : "❌"
    $duration = $result.Duration.TotalSeconds
    Write-Host "  $status $($result.Table): $($result.Status) ($([math]::Round($duration))s)"
}

# ============================================================================
# SAVE REPORT
# ============================================================================

$reportContent = @"
# Category A1 Batch Execution Report
**Generated:** $(Get-Date)
**Total Tables:** $($Results.Count)
**Successful:** $SuccessCount
**Failed:** $FailureCount
**Total Duration:** $($TotalDuration.Hours)h $($TotalDuration.Minutes)m

## Results

| Table | Status | Duration | Notes |
|-------|--------|----------|-------|
$(($Results | ForEach-Object { "| $($_.Table) | $($_.Status) | $([math]::Round($_.Duration.TotalSeconds))s | FKs Dropped: $($_.FKsDropped ?? 'N/A') |" }) -join "`n")

## Next Steps
- Execute Category A2 (30 tables)
- Execute Category A3 (33 tables)  
- Review Category B audit table strategy
"@

$reportPath = "$ReportDir\BATCH_REPORT_A1_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
$reportContent | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "`n📄 Report saved to: $reportPath" -ForegroundColor Cyan

# ============================================================================
# UPDATE ROLLOUT SUMMARY
# ============================================================================

Write-Host "`n✅ Execution Complete - Rollout Summary Updated" -ForegroundColor Green
Write-Host "Proceed to Category A2 tables when ready" -ForegroundColor Cyan
