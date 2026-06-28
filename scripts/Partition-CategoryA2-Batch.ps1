# Category A2 Batch Partitioning Script
# Executes PARTITION_CREATION_PROMPT.md pattern on all remaining A2 tables

param(
    [string]$ServerName = "sql-epr-qa-eastus2.database.windows.net",
    [string]$DatabaseName = "sqldb-epr-qa"
)

$tables = @(
    "FDB_PATIENT_ALLERGY",
    "COMPOUND_INGREDIENTS",
    "PACKAGE_INFO",
    "SIGNATURE",
    "PATIENT_EMERGENCY_CONTACT",
    "PATIENT_CREDIT_CARD",
    "PATIENT_DOCUMENT",
    "PATIENT_PROGRAM",
    "PATIENT_PROGRAM_CONTACT",
    "PRIOR_ADVERSE_REACTION",
    "ALT_PRESCRIBER",
    "FOLLOW_UP_PRESCRIBER",
    "COUNSELING_NOTES",
    "PATIENT_NOTES",
    "VIAL_INFO",
    "TX_LOT",
    "KP_RXNUM_REF",
    "TP_LINK",
    "INTAKE_SOURCES",
    "MATCH_KEY",
    "IDGEN",
    "RENAL_MEASUREMENT"
)

$results = @()

foreach ($table in $tables) {
    Write-Host "Processing: $table"
    
    # Load credentials from encrypted file
    $credFile = "$PSScriptRoot\..\config\db-credentials.encrypted"
    if (!(Test-Path $credFile)) {
        Write-Error "Credentials file not found: $credFile"
        exit 1
    }
    
    $credData = Import-Clixml -Path $credFile
    $userId = $credData.UserName
    $password = $credData.Password | ConvertFrom-SecureString -AsPlainText
    
    # Build connection string
    $connString = "Server=tcp:$ServerName,1433;Initial Catalog=$DatabaseName;Persist Security Info=False;User ID=$userId;Password=$password;Encrypt=True;Connection Timeout=30;"
    
    try {
        $conn = New-Object System.Data.SqlClient.SqlConnection($connString)
        $conn.Open()
        $cmd = $conn.CreateCommand()
        
        # Get FKs to drop
        $cmd.CommandText = "SELECT fk.name FROM sys.foreign_keys fk WHERE OBJECT_NAME(fk.parent_object_id) = '$table'"
        $reader = $cmd.ExecuteReader()
        $fks = @()
        while ($reader.Read()) {
            $fks += $reader["name"]
        }
        $reader.Close()
        
        # Build DROP FK statements
        $dropFKs = ""
        foreach ($fk in $fks) {
            $dropFKs += "ALTER TABLE EPS.$table DROP CONSTRAINT $fk;`n"
        }
        
        # Get PK name
        $cmd.CommandText = "SELECT name FROM sys.indexes WHERE object_id = OBJECT_ID('EPS.$table') AND index_id = 1"
        $pkName = $cmd.ExecuteScalar()
        
        # Get nullable status
        $cmd.CommandText = "SELECT is_nullable FROM sys.columns WHERE object_id = OBJECT_ID('EPS.$table') AND name = 'CHAIN_ID'"
        $chainNullable = $cmd.ExecuteScalar()
        
        # Build execution script
        $script = ""
        $script += $dropFKs
        
        # If CHAIN_ID nullable, fix it
        if ($chainNullable) {
            $script += "ALTER TABLE EPS.$table ALTER COLUMN CHAIN_ID bigint NOT NULL;`n"
            $script += "ALTER TABLE EPS.$table ALTER COLUMN ID bigint NOT NULL;`n"
        }
        
        # Drop PK if exists
        if ($pkName) {
            $script += "ALTER TABLE EPS.$table DROP CONSTRAINT $pkName;`n"
        }
        
        # Create partitioned PK
        $script += "ALTER TABLE EPS.$table ADD CONSTRAINT $pkName PRIMARY KEY CLUSTERED (CHAIN_ID, ID) ON ps_ChainID_EPS(CHAIN_ID);`n"
        
        # Execute full script
        $cmd.CommandText = $script
        $cmd.ExecuteNonQuery() | Out-Null
        
        # Verify partitions
        $cmd.CommandText = "SELECT COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id = OBJECT_ID('EPS.$table') AND index_id = 1"
        $partCount = $cmd.ExecuteScalar()
        
        $results += @{
            Table = $table
            Status = "✅ COMPLETE"
            Partitions = $partCount
            FKsDropped = $fks.Count
            Error = $null
        }
        
        Write-Host "  ✅ $table: $partCount partitions created ($($fks.Count) FKs dropped)"
        
        $conn.Close()
    }
    catch {
        $results += @{
            Table = $table
            Status = "❌ FAILED"
            Partitions = 0
            FKsDropped = 0
            Error = $_.Exception.Message
        }
        Write-Host "  ❌ $table: $($_.Exception.Message)"
    }
}

# Summary
Write-Host "`n=== BATCH EXECUTION SUMMARY ==="
$completed = ($results | Where-Object { $_.Status -match "COMPLETE" }).Count
Write-Host "Completed: $completed / $($tables.Count)"
Write-Host ""
$results | Format-Table -Property Table, Status, Partitions, FKsDropped
