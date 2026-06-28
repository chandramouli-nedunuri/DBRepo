#!/usr/bin/env pwsh
# Complete Category A1 Partitioning - All 7 Remaining Tables
# Logs to file for visibility

$logFile = "C:\Users\cnedunuri\Documents\DBRepo\A1_Execution_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$tables = @(
    @{ Name = "RX_TX"; SecondaryKey = "ID"; ChildFKs = @("PACKAGE_INFO_FK_RX_TX", "RX_TX_DIAGNOSIS_CODES_FK2", "RX_TX_DUR_LIST_FK_IDRXTX", "TX_CRED_FK_RX_TX", "TX_LOT_FK_RX_TX", "TX_TP_FK_RX_TX", "VIAL_INFO_FK_RX_TX", "COMPOUND_INGREDIENTS_FK2", "RX_TX_SIG_STR_PRT_FK_RX_TX"); OutboundFKs = @("RX_TX_FK_ALT_PRESCRIBER", "RX_TX_FK_ESCHAIN", "RX_TX_FK_ESSTORE", "RX_TX_FK_MOD_PCM", "RX_TX_FK_PRESCRIBER") },
    @{ Name = "PRESCRIBER"; SecondaryKey = "ID"; ChildFKs = @(); OutboundFKs = @("PRESCRIBER_FK_ESCHAIN", "PRESCRIBER_FK_ESSTORE") },
    @{ Name = "MRN"; SecondaryKey = "ID"; ChildFKs = @(); OutboundFKs = @("MRN_FK_ESCHAIN", "MRN_FK_PATIENT", "MRN_FK_ROOTID") },
    @{ Name = "CARD"; SecondaryKey = "ID"; ChildFKs = @("TP_LINK_FK_CARD", "WORKCOMP_FK_CARD"); OutboundFKs = @("CARD_FK_ESCHAIN", "CARD_FK_ESSTORE") },
    @{ Name = "PAYMENT"; SecondaryKey = "ID"; ChildFKs = @("RX_TX_PAYMENT_FK_CHAIN_PAYID"); OutboundFKs = @("PAYMENT_FK_ESCHAIN", "PAYMENT_FK_ESSTORE") },
    @{ Name = "LINE_ITEM"; SecondaryKey = "ID"; ChildFKs = @(); OutboundFKs = @("LINE_ITEM_FK_PATIENT", "LINE_ITEM_FK_ESCHAIN", "LINE_ITEM_FK_ESSTORE") },
    @{ Name = "ALLERGY"; SecondaryKey = "ID"; ChildFKs = @(); OutboundFKs = @("ALLERGY_FK_ESCHAIN", "ALLERGY_FK_ESSTORE", "ALLERGY_FK_PATIENT") },
    @{ Name = "DISEASE"; SecondaryKey = "ID"; ChildFKs = @(); OutboundFKs = @("DISEASE_FK_ESCHAIN", "DISEASE_FK_ESSTORE", "DISEASE_FK_PATIENT") }
)

function LogWrite {
    param($msg, $color = "White")
    Write-Host $msg -ForegroundColor $color
    Add-Content $logFile "$(Get-Date -Format 'HH:mm:ss') - $msg"
}

LogWrite "==== CATEGORY A1 PARTITIONING - ALL 7 REMAINING TABLES ====" "Cyan"
LogWrite "Log file: $logFile" "Gray"
LogWrite ""

$successCount = 0
$failureCount = 0

foreach ($table in $tables) {
    $tableName = $table.Name
    LogWrite ""
    LogWrite "================== $tableName ==================" "Yellow"
    
    # Build DROP statements
    $dropStatements = @()
    
    # Drop child FKs
    foreach ($fk in $table.ChildFKs) {
        $dropStatements += "ALTER TABLE EPS.$($fk -replace '_FK_.*') DROP CONSTRAINT $fk;"
    }
    
    # Drop outbound FKs
    foreach ($fk in $table.OutboundFKs) {
        $dropStatements += "ALTER TABLE EPS.$tableName DROP CONSTRAINT $fk;"
    }
    
    # Build SQL transaction
    $sql = @"
USE [sqldb-epr-qa];
BEGIN TRANSACTION;
BEGIN TRY
    -- Drop child FKs
    $($dropStatements -join "`n    ")
    
    -- Drop existing PK
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE TABLE_NAME = '$tableName' AND CONSTRAINT_TYPE = 'PRIMARY KEY')
    BEGIN
        DECLARE @pkName NVARCHAR(255)
        SELECT @pkName = CONSTRAINT_NAME FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE TABLE_NAME = '$tableName' AND CONSTRAINT_TYPE = 'PRIMARY KEY'
        EXEC('ALTER TABLE EPS.$tableName DROP CONSTRAINT ' + @pkName)
    END
    
    -- Create partitioned PK
    ALTER TABLE EPS.$tableName ADD CONSTRAINT PK_$tableName PRIMARY KEY CLUSTERED (CHAIN_ID, [$($table.SecondaryKey)]) ON ps_ChainID_EPS(CHAIN_ID);
    
    COMMIT TRANSACTION;
    SELECT 'SUCCESS: $tableName partitioned' as Result;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    SELECT 'FAILED: ' + ERROR_MESSAGE() as Result;
END CATCH
"@

    # Execute
    try {
        $result = .\scripts\Connect-ToDatabase.ps1 -Query $sql 2>&1
        
        if ($result -match "SUCCESS") {
            LogWrite "  ✓ Partitioning completed" "Green"
            $successCount++
        } else {
            LogWrite "  ✗ Failed or status unknown" "Red"
            LogWrite "  Output: $result" "Red"
            $failureCount++
        }
    } catch {
        LogWrite "  ✗ Exception: $_" "Red"
        $failureCount++
    }
    
    # Verify
    Start-Sleep -Seconds 1
    $verify = .\scripts\Connect-ToDatabase.ps1 -Query "SELECT COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.$tableName') AND index_id=1"
    
    if ($verify -match ":\s*6\s*$") {
        LogWrite "  ✓ Verified: 6 partitions" "Green"
    } else {
        LogWrite "  ⚠ Partitions: $($verify -match ':\s*(\d+)' | ForEach-Object { $matches[1] })" "Yellow"
    }
}

LogWrite ""
LogWrite "==== SUMMARY ====" "Cyan"
LogWrite "Successful: $successCount / 7" "Green"
LogWrite "Failed: $failureCount / 7" "Red"
LogWrite "Log saved to: $logFile"

# Show last 20 lines of log
Write-Host "`n--- Log File Preview (Last 20 lines) ---" -ForegroundColor Gray
Get-Content $logFile -Tail 20 | ForEach-Object { Write-Host $_ }
