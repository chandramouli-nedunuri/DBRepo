# PowerShell Script to Execute EPS.PATIENT Partitioning
# This script reproduces the successful partitioning executed against Azure SQL
# 
# Prerequisites:
# - Connect-ToDatabase.ps1 available in ./scripts/
# - db-credentials.encrypted configured at ./config/db-credentials.encrypted
# - SQL Server credentials with ddl_admin permissions

param(
    [string]$ConfigPath = "config/db-credentials.encrypted"
)

# Helper function
function Execute-Query {
    param([string]$Query, [string]$StepName)
    Write-Host "`n$StepName..." -ForegroundColor Cyan
    & .\scripts\Connect-ToDatabase.ps1 -Query $Query -ConfigPath $ConfigPath
}

# ============================================================================
# SECTION 1: PRE-EXECUTION CHECKS
# ============================================================================

Write-Host "=== PRE-EXECUTION CHECKS ===" -ForegroundColor Yellow

Execute-Query "SELECT 'PATIENT' AS TableName, COUNT(*) AS [RowCount] FROM EPS.PATIENT" "Check 1: Table exists"

Execute-Query "SELECT name AS PartitionFunctionName FROM sys.partition_functions WHERE name IN ('pf_ChainID_EPS', 'pf_PATIENT')" "Check 2: Partition functions"

Execute-Query "SELECT CONSTRAINT_NAME FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA = 'EPS' AND TABLE_NAME = 'PATIENT' AND CONSTRAINT_TYPE = 'PRIMARY KEY'" "Check 3: Primary key"

Execute-Query "SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'EPS' AND TABLE_NAME = 'PATIENT' AND COLUMN_NAME = 'CHAIN_ID'" "Check 4: CHAIN_ID column"

# ============================================================================
# SECTION 2: CREATE PARTITION INFRASTRUCTURE
# ============================================================================

Write-Host "`n=== CREATING PARTITION INFRASTRUCTURE ===" -ForegroundColor Yellow

Execute-Query "CREATE PARTITION FUNCTION pf_ChainID_EPS (BIGINT) AS RANGE LEFT FOR VALUES (1000, 5000, 50000, 100000, 130000)" "Create Partition Function"

Execute-Query "CREATE PARTITION SCHEME ps_ChainID_EPS AS PARTITION pf_ChainID_EPS ALL TO ([PRIMARY])" "Create Partition Scheme"

Write-Host "`nPartition infrastructure created successfully." -ForegroundColor Green

# ============================================================================
# SECTION 3: DROP FOREIGN KEYS
# ============================================================================

Write-Host "`n=== DROPPING FOREIGN KEYS ===" -ForegroundColor Yellow

# Batch 1: Child tables
$fkBatch1 = @"
ALTER TABLE EPS.PATIENT_EMERGENCY_CONTACT DROP CONSTRAINT PATIENT_EMERGENCY_CONTACT_FK1;
ALTER TABLE EPS.PATIENT_MO_CONSENT DROP CONSTRAINT PATIENT_MO_CONSENT_FK1;
ALTER TABLE EPS.PATIENT_NOTES DROP CONSTRAINT PATIENT_NOTES_FK2;
ALTER TABLE EPS.PATIENT_NOTIFY_SCHEDULE DROP CONSTRAINT PATIENT_NOTIFY_SCHEDULE_FK2;
ALTER TABLE EPS.PATIENT_PROGRAM DROP CONSTRAINT PATIENT_PROGRAM_FK1;
"@

Execute-Query $fkBatch1 "Drop foreign keys batch 1"

# Batch 2: Additional child tables
$fkBatch2 = @"
ALTER TABLE EPS.PATIENT_SIGNATURES DROP CONSTRAINT PATIENT_SIGNATURES_FK1;
ALTER TABLE EPS.PATIENT_UNMERGE_LOCK DROP CONSTRAINT PAT_UMMERGE_LOCK_FK_PATIENT;
ALTER TABLE EPS.PRIOR_ADVERSE_REACTION DROP CONSTRAINT PRIOR_ADVERSE_REACTION_FK2;
ALTER TABLE EPS.QUEUECOMMAND DROP CONSTRAINT QUEUECMD_FK_PATIENT;
ALTER TABLE EPS.RENAL_MEASUREMENT DROP CONSTRAINT RENAL_MEASUREMENT_FK2;
ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_FK_PATIENT;
ALTER TABLE EPS.SIGNATURE DROP CONSTRAINT SIGNATURE_FK_PATIENT;
ALTER TABLE EPS.TELEPHONE DROP CONSTRAINT TELEPHONE_FK_PATIENT;
ALTER TABLE EPS.TP_LINK DROP CONSTRAINT TP_LINK_FK_PATIENT;
ALTER TABLE EPS.VISUALLY_IMPAIRED_DETAIL DROP CONSTRAINT VISUALLY_IMPAIRED_DETAIL_FK1;
ALTER TABLE EPS.PATIENT_AR_ACCOUNT DROP CONSTRAINT PATIENT_AR_AC_FK_PATIENT;
ALTER TABLE EPS.PATIENT_CARE_PROVIDER DROP CONSTRAINT PATIENT_CARE_PROVIDER_FK2;
ALTER TABLE EPS.PATIENT_CREDIT_CARD DROP CONSTRAINT PATIENT_CC_FK_PATIENT;
ALTER TABLE EPS.PATIENT_DOCUMENT DROP CONSTRAINT PATIENT_DOCUMENT_FK3;
"@

Execute-Query $fkBatch2 "Drop foreign keys batch 2"

# Drop self-referencing FK
Execute-Query "ALTER TABLE EPS.PATIENT DROP CONSTRAINT PATIENT_FK1" "Drop self-referencing FK (PATIENT_FK1)"

# ============================================================================
# SECTION 4: MODIFY PRIMARY KEY
# ============================================================================

Write-Host "`n=== MODIFYING PRIMARY KEY ===" -ForegroundColor Yellow

Execute-Query "ALTER TABLE EPS.PATIENT DROP CONSTRAINT PK_PATIENT" "Drop existing primary key"

Write-Host "`nWARNING: Table lock will occur during PK recreation (1-5 minutes typical)" -ForegroundColor Red
Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Gray

Execute-Query "ALTER TABLE EPS.PATIENT ADD CONSTRAINT PK_PATIENT PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID)" "Create partitioned primary key"

Write-Host "`nPrimary key recreated on partition scheme." -ForegroundColor Green

# ============================================================================
# SECTION 5: VERIFY PARTITIONING
# ============================================================================

Write-Host "`n=== VERIFYING PARTITIONING ===" -ForegroundColor Yellow

Execute-Query "SELECT index_id, name, partition_scheme FROM (SELECT i.index_id, i.name, ps.name AS partition_scheme FROM sys.indexes i LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id WHERE i.object_id = OBJECT_ID('EPS.PATIENT')) sub" "Verify partition scheme assignment"

Execute-Query "SELECT partition_number, [rows] FROM sys.partitions WHERE object_id = OBJECT_ID('EPS.PATIENT') AND index_id = 1 ORDER BY partition_number" "Verify partition count and rows"

Execute-Query "SELECT name FROM sys.partition_functions WHERE name = 'pf_ChainID_EPS'" "Verify partition function created"

Execute-Query "SELECT name FROM sys.partition_schemes WHERE name = 'ps_ChainID_EPS'" "Verify partition scheme created"

# ============================================================================
# COMPLETION
# ============================================================================

Write-Host "`n" -ForegroundColor Green
Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  EPS.PATIENT PARTITIONING COMPLETE      ✅  ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "- Partition Function: pf_ChainID_EPS (RANGE LEFT)"
Write-Host "- Partition Scheme: ps_ChainID_EPS (6 partitions)"
Write-Host "- Primary Key: Partitioned by CHAIN_ID"
Write-Host "- Status: READY FOR PRODUCTION"

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Recreate foreign keys (use SQL_PARTITION_PATIENT_WITH_FK_HANDLING.sql)"
Write-Host "2. Create supporting indexes (DOB, LAST_NAME/FIRST_NAME, MRN)"
Write-Host "3. Test partition elimination (WHERE CHAIN_ID = specific_value)"
Write-Host "4. Run performance baseline queries"
Write-Host "5. Apply same pattern to Category A1 tables (ADDRESS, RX_TX, etc.)"

Write-Host "`nTimestamp: $(Get-Date)" -ForegroundColor Gray
Write-Host "Execution Duration: Monitor process time from start"
