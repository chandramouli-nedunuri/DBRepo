# Simplified execution script - RX_TX only for testing
$ErrorActionPreference = "Continue"

Write-Host "====== RX_TX PARTITIONING TEST ======`n" -ForegroundColor Cyan

# Step 1: Check current partition count
Write-Host "STEP 1: Current RX_TX partition count..." -ForegroundColor Yellow
$sql1 = "SELECT COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.RX_TX') AND index_id=1"
$result1 = .\scripts\Connect-ToDatabase.ps1 -Query $sql1 2>&1
Write-Host $result1 | Out-String
$beforeCount = $result1 -split "`n" | Select-String "^\d" | ForEach-Object { $_.ToString().Trim() }
Write-Host "Before: $beforeCount partitions`n"

# Step 2: Drop child FKs
Write-Host "STEP 2: Dropping child table FKs that reference RX_TX..." -ForegroundColor Yellow

$fks = @(
    "ALTER TABLE EPS.PACKAGE_INFO DROP CONSTRAINT PACKAGE_INFO_FK_RX_TX",
    "ALTER TABLE EPS.RX_TX_DIAGNOSIS_CODES DROP CONSTRAINT RX_TX_DIAGNOSIS_CODES_FK2",
    "ALTER TABLE EPS.RX_TX_DUR_LIST DROP CONSTRAINT RX_TX_DUR_LIST_FK_IDRXTX",
    "ALTER TABLE EPS.TX_CRED DROP CONSTRAINT TX_CRED_FK_RX_TX",
    "ALTER TABLE EPS.TX_LOT DROP CONSTRAINT TX_LOT_FK_RX_TX",
    "ALTER TABLE EPS.TX_TP DROP CONSTRAINT TX_TP_FK_RX_TX",
    "ALTER TABLE EPS.VIAL_INFO DROP CONSTRAINT VIAL_INFO_FK_RX_TX",
    "ALTER TABLE EPS.COMPOUND_INGREDIENTS DROP CONSTRAINT COMPOUND_INGREDIENTS_FK2",
    "ALTER TABLE EPS.RX_TX_SIG_STRUCTURED_PART DROP CONSTRAINT RX_TX_SIG_STR_PRT_FK_RX_TX"
)

$fkSql = "USE [sqldb-epr-qa];" + [Environment]::NewLine
$fkSql += "BEGIN TRY`n"
foreach ($fk in $fks) {
    $fkSql += "    $fk;`n"
}
$fkSql += "    PRINT 'Child FKs dropped successfully'`n"
$fkSql += "END TRY`n"
$fkSql += "BEGIN CATCH`n"
$fkSql += "    PRINT 'Error: ' + ERROR_MESSAGE()`n"
$fkSql += "END CATCH"

$result2 = .\scripts\Connect-ToDatabase.ps1 -Query $fkSql 2>&1
Write-Host $result2 | Out-String

# Step 3: Drop outbound FKs from RX_TX
Write-Host "STEP 3: Dropping outbound FKs from RX_TX..." -ForegroundColor Yellow

$outboundFks = @(
    "RX_TX_FK_ALT_PRESCRIBER",
    "RX_TX_FK_ESCHAIN",
    "RX_TX_FK_ESSTORE",
    "RX_TX_FK_MOD_PCM",
    "RX_TX_FK_PRESCRIBER"
)

$outboundSql = "USE [sqldb-epr-qa];" + [Environment]::NewLine
$outboundSql += "BEGIN TRY`n"
foreach ($fk in $outboundFks) {
    $outboundSql += "    ALTER TABLE EPS.RX_TX DROP CONSTRAINT $fk;`n"
}
$outboundSql += "    PRINT 'Outbound FKs dropped successfully'`n"
$outboundSql += "END TRY`n"
$outboundSql += "BEGIN CATCH`n"
$outboundSql += "    PRINT 'Error: ' + ERROR_MESSAGE()`n"
$outboundSql += "END CATCH"

$result3 = .\scripts\Connect-ToDatabase.ps1 -Query $outboundSql 2>&1
Write-Host $result3 | Out-String

# Step 4: Drop original PK
Write-Host "STEP 4: Dropping original RX_TX primary key..." -ForegroundColor Yellow

$dropPkSql = @"
USE [sqldb-epr-qa];
BEGIN TRY
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_PK;
    PRINT 'Original PK dropped'
END TRY
BEGIN CATCH
    PRINT 'Error: ' + ERROR_MESSAGE()
END CATCH
"@

$result4 = .\scripts\Connect-ToDatabase.ps1 -Query $dropPkSql 2>&1
Write-Host $result4 | Out-String

# Step 5: Create partitioned PK
Write-Host "STEP 5: Creating partitioned composite PK (CHAIN_ID, RX_TX_ID)..." -ForegroundColor Yellow

$createPkSql = @"
USE [sqldb-epr-qa];
BEGIN TRY
    ALTER TABLE EPS.RX_TX ADD CONSTRAINT PK_RX_TX PRIMARY KEY CLUSTERED (CHAIN_ID, [RX_TX_ID]) ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'Partitioned PK created'
END TRY
BEGIN CATCH
    PRINT 'Error: ' + ERROR_MESSAGE()
END CATCH
"@

$result5 = .\scripts\Connect-ToDatabase.ps1 -Query $createPkSql 2>&1
Write-Host $result5 | Out-String

# Step 6: Verify
Write-Host "STEP 6: Verifying partition count..." -ForegroundColor Yellow
$sql6 = "SELECT COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.RX_TX') AND index_id=1"
$result6 = .\scripts\Connect-ToDatabase.ps1 -Query $sql6 2>&1
Write-Host $result6 | Out-String
$afterCount = $result6 -split "`n" | Select-String "^\d" | ForEach-Object { $_.ToString().Trim() }
Write-Host "After: $afterCount partitions`n"

if ($afterCount -eq "6") {
    Write-Host "====== SUCCESS! RX_TX now has 6 partitions ======" -ForegroundColor Green
} else {
    Write-Host "====== FAILED! RX_TX still has $afterCount partitions ======" -ForegroundColor Red
}
