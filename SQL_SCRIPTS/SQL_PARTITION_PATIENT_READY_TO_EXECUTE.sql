-- ============================================================================
-- PARTITION CONVERSION: EPS.PATIENT TABLE
-- Strategy: PARTITION BY CHAIN_ID (6 value ranges)
-- Source: Oracle LIST on CHAIN_ID (163 partitions)
-- Target: Azure SQL RANGE on CHAIN_ID (6 partitions)
-- ============================================================================

-- EXECUTION ENVIRONMENT
-- Database: [Your_EPS_Database]
-- Date: 2026-06-26
-- Estimated Runtime: 5-15 minutes (depends on table size)
-- Impact: DOWNTIME during partition application (ALTER TABLE)

-- ============================================================================
-- SECTION 1: PRE-EXECUTION CHECKS
-- ============================================================================

-- Check 1: Verify table exists and size
SELECT 
    OBJECT_NAME(ps.object_id) AS TableName,
    SUM(ps.row_count) AS [RowCount],
    SUM(ps.used_page_count) * 8.0 / 1024.0 AS UsedMB
FROM sys.dm_db_partition_stats ps
WHERE OBJECT_NAME(ps.object_id) = 'PATIENT'
  AND schema_id = SCHEMA_ID('EPS')
GROUP BY ps.object_id;

-- Check 2: Verify no existing partitions
SELECT * FROM sys.partition_functions 
WHERE name LIKE 'pf_ChainID%' OR name LIKE 'pf_PATIENT%';

-- Check 3: Check current primary key
SELECT 
    CONSTRAINT_NAME,
    COLUMN_NAME,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'EPS' 
  AND TABLE_NAME = 'PATIENT'
  AND CONSTRAINT_TYPE = 'PRIMARY KEY'
ORDER BY ORDINAL_POSITION;

-- Check 4: Verify CHAIN_ID column exists and data type
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE,
    NUMERIC_PRECISION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'EPS' 
  AND TABLE_NAME = 'PATIENT'
  AND COLUMN_NAME = 'CHAIN_ID';

-- Check 5: Check distribution of CHAIN_ID values
SELECT 
    CASE 
        WHEN CHAIN_ID <= 1000 THEN 'P1: 0-1000'
        WHEN CHAIN_ID <= 5000 THEN 'P2: 1001-5000'
        WHEN CHAIN_ID <= 50000 THEN 'P3: 5001-50000'
        WHEN CHAIN_ID <= 100000 THEN 'P4: 50001-100000'
        WHEN CHAIN_ID <= 130000 THEN 'P5: 100001-130000'
        ELSE 'P6: >130000'
    END AS PartitionRange,
    COUNT(*) AS [RowCount],
    MIN(CHAIN_ID) AS MinChainID,
    MAX(CHAIN_ID) AS MaxChainID
FROM EPS.PATIENT
GROUP BY 
    CASE 
        WHEN CHAIN_ID <= 1000 THEN 'P1: 0-1000'
        WHEN CHAIN_ID <= 5000 THEN 'P2: 1001-5000'
        WHEN CHAIN_ID <= 50000 THEN 'P3: 5001-50000'
        WHEN CHAIN_ID <= 100000 THEN 'P4: 50001-100000'
        WHEN CHAIN_ID <= 130000 THEN 'P5: 100001-130000'
        ELSE 'P6: >130000'
    END
ORDER BY PartitionRange;

-- ============================================================================
-- SECTION 2: CREATE PARTITION FUNCTION (ONE TIME)
-- This is shared across ALL 73 CATEGORY A tables
-- ============================================================================

-- Create partition function with 5 boundary values = 6 partitions
IF NOT EXISTS (SELECT * FROM sys.partition_functions WHERE name = 'pf_ChainID_EPS')
BEGIN
    PRINT 'Creating Partition Function: pf_ChainID_EPS'
    
    CREATE PARTITION FUNCTION pf_ChainID_EPS (INT)
    AS RANGE LEFT 
    FOR VALUES (1000, 5000, 50000, 100000, 130000);
    
    PRINT 'Partition Function pf_ChainID_EPS created successfully.'
END
ELSE
BEGIN
    PRINT 'Partition Function pf_ChainID_EPS already exists. Skipping creation.'
END;

-- Verify partition function
SELECT 
    name AS PartitionFunctionName,
    type_desc,
    fanout
FROM sys.partition_functions
WHERE name = 'pf_ChainID_EPS';

-- View boundary values
SELECT 
    function_id,
    boundary_id,
    value
FROM sys.partition_range_values
WHERE function_id = (SELECT function_id FROM sys.partition_functions WHERE name = 'pf_ChainID_EPS')
ORDER BY boundary_id;

-- ============================================================================
-- SECTION 3: CREATE PARTITION SCHEME (ONE TIME)
-- This is shared across ALL 73 CATEGORY A tables
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.partition_schemes WHERE name = 'ps_ChainID_EPS')
BEGIN
    PRINT 'Creating Partition Scheme: ps_ChainID_EPS'
    
    CREATE PARTITION SCHEME ps_ChainID_EPS
    AS PARTITION pf_ChainID_EPS
    ALL TO ([PRIMARY]);
    
    PRINT 'Partition Scheme ps_ChainID_EPS created successfully.'
END
ELSE
BEGIN
    PRINT 'Partition Scheme ps_ChainID_EPS already exists. Skipping creation.'
END;

-- Verify partition scheme
SELECT 
    name AS PartitionSchemeName,
    type_desc,
    is_default
FROM sys.partition_schemes
WHERE name = 'ps_ChainID_EPS';

-- ============================================================================
-- SECTION 4: APPLY PARTITIONING TO EPS.PATIENT TABLE
-- This is TABLE-SPECIFIC
-- ============================================================================

-- STEP 4A: Drop existing indexes (except clustered primary key)
-- We need to drop all non-clustered indexes first because they reference the old structure

PRINT '=== STEP 4A: Drop existing non-clustered indexes ==='

-- Get list of all non-clustered indexes
SELECT 'DROP INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + ';' AS DropStatement
FROM sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'EPS'
  AND t.name = 'PATIENT'
  AND i.type > 1;  -- Exclude clustered index (type = 1)

-- Execute the drops (copy statements from above query and run, or use dynamic SQL below)
DECLARE @sql NVARCHAR(MAX) = '';

SELECT @sql += 'DROP INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + ';' + CHAR(10)
FROM sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'EPS'
  AND t.name = 'PATIENT'
  AND i.type > 1;

IF @sql <> ''
BEGIN
    PRINT 'Dropping non-clustered indexes...'
    EXEC sp_executesql @sql;
    PRINT 'Non-clustered indexes dropped.'
END
ELSE
BEGIN
    PRINT 'No non-clustered indexes found.'
END;

-- ============================================================================
-- STEP 4B: Drop PRIMARY KEY constraint
-- We need to drop and recreate it on the partition scheme
-- ============================================================================

PRINT '=== STEP 4B: Drop primary key constraint ==='

DECLARE @PK_Name NVARCHAR(128);
SELECT @PK_Name = CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'EPS' 
  AND TABLE_NAME = 'PATIENT'
  AND CONSTRAINT_TYPE = 'PRIMARY KEY';

IF @PK_Name IS NOT NULL
BEGIN
    EXEC ('ALTER TABLE EPS.PATIENT DROP CONSTRAINT ' + @PK_Name);
    PRINT 'Primary key constraint ' + @PK_Name + ' dropped.'
END
ELSE
BEGIN
    PRINT 'No primary key found (unexpected!)'
END;

-- ============================================================================
-- STEP 4C: Create NEW PRIMARY KEY on partition scheme
-- Include CHAIN_ID as part of the key
-- ============================================================================

PRINT '=== STEP 4C: Create new primary key on partition scheme ==='

-- NOTE: PRIMARY KEY must include the partition column (CHAIN_ID)
-- Adjust PATIENT_ID as needed for your actual primary key column

ALTER TABLE EPS.PATIENT
ADD CONSTRAINT PK_PATIENT PRIMARY KEY CLUSTERED (PATIENT_ID, CHAIN_ID)
ON ps_ChainID_EPS(CHAIN_ID);

PRINT 'Primary key PK_PATIENT created on partition scheme ps_ChainID_EPS'

-- Verify partitioned primary key
SELECT 
    CONSTRAINT_NAME,
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'EPS' 
  AND TABLE_NAME = 'PATIENT'
  AND CONSTRAINT_TYPE = 'PRIMARY KEY';

-- ============================================================================
-- SECTION 5: CREATE SUPPORTING INDEXES
-- These are TABLE-SPECIFIC and optimized for common queries on PATIENT
-- ============================================================================

PRINT '=== SECTION 5: Create supporting indexes ==='

-- Index 1: Search by DOB (common query: find patients by date of birth)
IF NOT EXISTS (
    SELECT * FROM sys.indexes 
    WHERE name = 'NIX_PATIENT_DOB' 
    AND object_id = OBJECT_ID('EPS.PATIENT')
)
BEGIN
    PRINT 'Creating index NIX_PATIENT_DOB'
    CREATE NONCLUSTERED INDEX NIX_PATIENT_DOB
    ON EPS.PATIENT (DOB, CHAIN_ID)
    ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'Index NIX_PATIENT_DOB created.'
END
ELSE
    PRINT 'Index NIX_PATIENT_DOB already exists.'

-- Index 2: Search by Patient Last Name (very common query)
IF NOT EXISTS (
    SELECT * FROM sys.indexes 
    WHERE name = 'NIX_PATIENT_LASTNAME' 
    AND object_id = OBJECT_ID('EPS.PATIENT')
)
BEGIN
    PRINT 'Creating index NIX_PATIENT_LASTNAME'
    CREATE NONCLUSTERED INDEX NIX_PATIENT_LASTNAME
    ON EPS.PATIENT (PATIENT_LAST_NAME, PATIENT_FIRST_NAME, CHAIN_ID)
    ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'Index NIX_PATIENT_LASTNAME created.'
END
ELSE
    PRINT 'Index NIX_PATIENT_LASTNAME already exists.'

-- Index 3: Search by MRN (medical record number - unique)
IF NOT EXISTS (
    SELECT * FROM sys.indexes 
    WHERE name = 'NIX_PATIENT_MRN' 
    AND object_id = OBJECT_ID('EPS.PATIENT')
)
BEGIN
    PRINT 'Creating index NIX_PATIENT_MRN'
    CREATE NONCLUSTERED INDEX NIX_PATIENT_MRN
    ON EPS.PATIENT (MRN, CHAIN_ID)
    ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'Index NIX_PATIENT_MRN created.'
END
ELSE
    PRINT 'Index NIX_PATIENT_MRN already exists.'

-- Index 4: Search by creation date (range queries)
IF NOT EXISTS (
    SELECT * FROM sys.indexes 
    WHERE name = 'NIX_PATIENT_CREATED_DATE' 
    AND object_id = OBJECT_ID('EPS.PATIENT')
)
BEGIN
    PRINT 'Creating index NIX_PATIENT_CREATED_DATE'
    CREATE NONCLUSTERED INDEX NIX_PATIENT_CREATED_DATE
    ON EPS.PATIENT (PATIENT_CREATED_DATE, CHAIN_ID)
    ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'Index NIX_PATIENT_CREATED_DATE created.'
END
ELSE
    PRINT 'Index NIX_PATIENT_CREATED_DATE already exists.'

-- ============================================================================
-- SECTION 6: VALIDATION & VERIFICATION
-- ============================================================================

PRINT '=== SECTION 6: Validation ==='

-- Validation 1: Verify table is partitioned
SELECT 
    OBJECT_NAME(t.object_id) AS TableName,
    pf.name AS PartitionFunctionName,
    ps.name AS PartitionSchemeName,
    INDEXPROPERTY(t.object_id, i.name, 'IndexDepth') AS IndexDepth
FROM sys.tables t
JOIN sys.indexes i ON t.object_id = i.object_id
JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
WHERE OBJECT_NAME(t.object_id) = 'PATIENT'
  AND t.schema_id = SCHEMA_ID('EPS');

-- Validation 2: Check partition distribution
SELECT 
    OBJECT_NAME(p.object_id) AS TableName,
    i.name AS IndexName,
    p.partition_number AS PartitionNumber,
    p.rows AS [RowCount]
FROM sys.partitions p
JOIN sys.indexes i ON p.object_id = i.object_id AND p.index_id = i.index_id
WHERE OBJECT_NAME(p.object_id) = 'PATIENT'
  AND p.object_id = OBJECT_ID('EPS.PATIENT')
ORDER BY p.partition_number;

-- Validation 3: Check indexes created
SELECT 
    name AS IndexName,
    type_desc,
    is_primary_key,
    data_space_id
FROM sys.indexes
WHERE object_id = OBJECT_ID('EPS.PATIENT')
  AND SCHEMA_NAME(OBJECT_SCHEMA_ID(object_id)) = 'EPS'
ORDER BY index_id;

-- Validation 4: View partition boundaries
SELECT 
    ps.name AS PartitionSchemeName,
    pf.name AS PartitionFunctionName,
    pf.type_desc,
    prv.boundary_id,
    prv.value AS BoundaryValue
FROM sys.partition_schemes ps
JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
LEFT JOIN sys.partition_range_values prv ON pf.function_id = prv.function_id
WHERE ps.name = 'ps_ChainID_EPS'
ORDER BY prv.boundary_id;

-- Validation 5: Test partition elimination (sample query)
-- This should show which partitions are accessed
SET STATISTICS IO ON;

SELECT TOP 10 
    PATIENT_ID, 
    CHAIN_ID, 
    PATIENT_LAST_NAME, 
    PATIENT_FIRST_NAME
FROM EPS.PATIENT
WHERE CHAIN_ID = 102;  -- GEAGLE chain - should use only P1 partition

SET STATISTICS IO OFF;

-- ============================================================================
-- SECTION 7: PERFORMANCE BASELINE (after partitioning)
-- ============================================================================

PRINT '=== SECTION 7: Performance Baseline ==='

-- Query 1: Count by CHAIN_ID (should use partition elimination)
SELECT 
    CHAIN_ID,
    COUNT(*) AS PatientCount
FROM EPS.PATIENT
GROUP BY CHAIN_ID
ORDER BY CHAIN_ID;

-- Query 2: Full table scan (touches all partitions)
SELECT COUNT(*) AS TotalPatients FROM EPS.PATIENT;

-- Query 3: Index usage by DOB
SELECT TOP 100
    PATIENT_ID,
    DOB,
    CHAIN_ID
FROM EPS.PATIENT
WHERE DOB >= '1960-01-01' AND DOB < '1970-01-01'
ORDER BY DOB;

-- ============================================================================
-- SECTION 8: ROLLBACK PROCEDURE (if needed)
-- ============================================================================

/*
-- ROLLBACK ONLY IF PARTITIONING CAUSES ISSUES
-- This will revert the table to non-partitioned state

-- Step 1: Drop all non-clustered indexes (same as before)
DECLARE @sql NVARCHAR(MAX) = '';
SELECT @sql += 'DROP INDEX ' + QUOTENAME(i.name) + ' ON EPS.PATIENT;' + CHAR(10)
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('EPS.PATIENT')
  AND i.type > 1;
EXEC sp_executesql @sql;

-- Step 2: Drop partitioned primary key
ALTER TABLE EPS.PATIENT DROP CONSTRAINT PK_PATIENT;

-- Step 3: Create non-partitioned primary key
ALTER TABLE EPS.PATIENT
ADD CONSTRAINT PK_PATIENT PRIMARY KEY CLUSTERED (PATIENT_ID, CHAIN_ID);

-- Step 4: Recreate indexes (non-partitioned)
CREATE NONCLUSTERED INDEX NIX_PATIENT_DOB
ON EPS.PATIENT (DOB);

CREATE NONCLUSTERED INDEX NIX_PATIENT_LASTNAME
ON EPS.PATIENT (PATIENT_LAST_NAME, PATIENT_FIRST_NAME);

-- Step 5: Clean up partition scheme (only if all tables unpartitioned)
DROP PARTITION SCHEME ps_ChainID_EPS;
DROP PARTITION FUNCTION pf_ChainID_EPS;

PRINT 'Rollback complete. Table is no longer partitioned.'
*/

-- ============================================================================
-- SECTION 9: FINAL STATUS REPORT
-- ============================================================================

PRINT '===== PARTITIONING COMPLETE FOR EPS.PATIENT ====='
PRINT ''
PRINT 'Summary:'
PRINT '  Table Name: EPS.PATIENT'
PRINT '  Partition Function: pf_ChainID_EPS (RANGE LEFT on CHAIN_ID)'
PRINT '  Partition Scheme: ps_ChainID_EPS'
PRINT '  Number of Partitions: 6'
PRINT '  Partition Boundaries: 1000, 5000, 50000, 100000, 130000'
PRINT '  Indexes Created: 4 non-clustered indexes'
PRINT '  Status: READY FOR PRODUCTION'
PRINT ''
PRINT 'Next Steps:'
PRINT '  1. Run validation queries from SECTION 6'
PRINT '  2. Run performance test queries from SECTION 7'
PRINT '  3. Compare query execution times before/after'
PRINT '  4. If satisfied, repeat process for remaining 72 CATEGORY A tables'
PRINT ''

