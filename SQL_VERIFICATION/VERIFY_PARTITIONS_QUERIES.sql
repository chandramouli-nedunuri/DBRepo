-- ============================================================================
-- PARTITION VERIFICATION QUERIES FOR EPS.PATIENT
-- Run these to confirm partitioning applied successfully
-- ============================================================================

-- ============================================================================
-- QUERY 1: Verify Partition Function Exists
-- ============================================================================
SELECT 
    name AS PartitionFunctionName,
    type_desc,
    boundary_value_on_right
FROM sys.partition_functions
WHERE name = 'pf_ChainID_EPS';

-- Expected Output:
-- PartitionFunctionName: pf_ChainID_EPS
-- type_desc: RANGE
-- boundary_value_on_right: 0 (indicates RANGE LEFT)


-- ============================================================================
-- QUERY 2: View Partition Function Boundaries
-- ============================================================================
SELECT 
    pf.name AS PartitionFunctionName,
    prv.boundary_id,
    prv.boundary_value,
    CASE 
        WHEN prv.boundary_id = 1 THEN 'P1: <= ' + CAST(prv.boundary_value AS VARCHAR(20))
        WHEN prv.boundary_id = 2 THEN 'P2: > ' + CAST((SELECT boundary_value FROM sys.partition_range_values WHERE function_id = pf.function_id AND boundary_id = 1) AS VARCHAR(20)) + ' AND <= ' + CAST(prv.boundary_value AS VARCHAR(20))
        WHEN prv.boundary_id = 3 THEN 'P3: > ' + CAST((SELECT boundary_value FROM sys.partition_range_values WHERE function_id = pf.function_id AND boundary_id = 2) AS VARCHAR(20)) + ' AND <= ' + CAST(prv.boundary_value AS VARCHAR(20))
        WHEN prv.boundary_id = 4 THEN 'P4: > ' + CAST((SELECT boundary_value FROM sys.partition_range_values WHERE function_id = pf.function_id AND boundary_id = 3) AS VARCHAR(20)) + ' AND <= ' + CAST(prv.boundary_value AS VARCHAR(20))
        WHEN prv.boundary_id = 5 THEN 'P5: > ' + CAST((SELECT boundary_value FROM sys.partition_range_values WHERE function_id = pf.function_id AND boundary_id = 4) AS VARCHAR(20)) + ' AND <= ' + CAST(prv.boundary_value AS VARCHAR(20))
        WHEN prv.boundary_id = 6 THEN 'P6: > ' + CAST((SELECT boundary_value FROM sys.partition_range_values WHERE function_id = pf.function_id AND boundary_id = 5) AS VARCHAR(20))
    END AS PartitionRange
FROM sys.partition_functions pf
JOIN sys.partition_range_values prv ON pf.function_id = prv.function_id
WHERE pf.name = 'pf_ChainID_EPS'
ORDER BY prv.boundary_id;

-- Expected Output:
-- boundary_id 1: 1000      (P1: <= 1000)
-- boundary_id 2: 5000      (P2: > 1000 AND <= 5000)
-- boundary_id 3: 50000     (P3: > 5000 AND <= 50000)
-- boundary_id 4: 100000    (P4: > 50000 AND <= 100000)
-- boundary_id 5: 130000    (P5: > 100000 AND <= 130000)
-- (P6 implicitly: > 130000)


-- ============================================================================
-- QUERY 3: Verify Partition Scheme Exists
-- ============================================================================
SELECT 
    ps.name AS PartitionSchemeName,
    pf.name AS PartitionFunctionName,
    ds.name AS FilegroupName
FROM sys.partition_schemes ps
JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
JOIN sys.destination_data_spaces dds ON ps.data_space_id = dds.partition_scheme_id
JOIN sys.data_spaces ds ON dds.data_space_id = ds.data_space_id
WHERE ps.name = 'ps_ChainID_EPS'
ORDER BY dds.destination_id;

-- Expected Output:
-- PartitionSchemeName: ps_ChainID_EPS
-- PartitionFunctionName: pf_ChainID_EPS
-- FilegroupName: PRIMARY (6 rows, one per partition)


-- ============================================================================
-- QUERY 4: Verify Table is Using Partition Scheme
-- ============================================================================
SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    ps.name AS PartitionSchemeName,
    i.index_id
FROM sys.tables t
JOIN sys.indexes i ON t.object_id = i.object_id
LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
WHERE t.schema_id = SCHEMA_ID('EPS') 
  AND t.name = 'PATIENT'
ORDER BY i.index_id;

-- Expected Output:
-- TableName: PATIENT
-- IndexName: PK_PATIENT (index_id: 1)
-- IndexType: CLUSTERED
-- PartitionSchemeName: ps_ChainID_EPS   <-- Must show partition scheme


-- ============================================================================
-- QUERY 5: Verify All 6 Partitions Are Allocated
-- ============================================================================
SELECT 
    partition_number AS PartitionNum,
    [rows] AS RowCount,
    CASE partition_number
        WHEN 1 THEN 'P1: CHAIN_ID <= 1000'
        WHEN 2 THEN 'P2: 1001 <= CHAIN_ID <= 5000'
        WHEN 3 THEN 'P3: 5001 <= CHAIN_ID <= 50000'
        WHEN 4 THEN 'P4: 50001 <= CHAIN_ID <= 100000'
        WHEN 5 THEN 'P5: 100001 <= CHAIN_ID <= 130000'
        WHEN 6 THEN 'P6: CHAIN_ID > 130000'
    END AS PartitionRange
FROM sys.partitions
WHERE object_id = OBJECT_ID('EPS.PATIENT')
  AND index_id = 1  -- Clustered index only
ORDER BY partition_number;

-- Expected Output: 6 rows (one per partition), all showing RowCount = 0 initially


-- ============================================================================
-- QUERY 6: Verify Primary Key Structure
-- ============================================================================
SELECT 
    c.name AS ColumnName,
    c.column_id,
    t.name AS DataType,
    c.max_length
FROM sys.index_columns ic
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE ic.object_id = OBJECT_ID('EPS.PATIENT')
  AND ic.index_id = 1  -- Primary key
ORDER BY ic.key_ordinal;

-- Expected Output:
-- ColumnName: CHAIN_ID (column_id: 1, key_ordinal: 1)
-- ColumnName: ID (column_id: 2, key_ordinal: 2)
-- DataType: bigint (CHAIN_ID), int (ID)


-- ============================================================================
-- QUERY 7: Verify Partition Key Column
-- ============================================================================
SELECT 
    i.name AS IndexName,
    ic.partition_ordinal,
    c.name AS PartitionKeyColumn,
    t.name AS DataType
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE i.object_id = OBJECT_ID('EPS.PATIENT')
  AND i.index_id = 1
  AND ic.partition_ordinal > 0;

-- Expected Output:
-- IndexName: PK_PATIENT
-- partition_ordinal: 1
-- PartitionKeyColumn: CHAIN_ID
-- DataType: bigint


-- ============================================================================
-- QUERY 8: Test Partition Elimination (Sample Query)
-- ============================================================================
-- Run this with STATISTICS IO ON to see partition usage
SET STATISTICS IO ON;

SELECT TOP 10 PATIENT_ID, CHAIN_ID, LAST_NAME, FIRST_NAME
FROM EPS.PATIENT
WHERE CHAIN_ID = 102;  -- GEAGLE chain (should route to P2)

SET STATISTICS IO OFF;

-- Look in Messages tab for:
-- Table 'PATIENT'. Scan count 1, logical reads: X
-- (If properly partitioned, should show scan count 1 for ONE partition only)


-- ============================================================================
-- QUERY 9: View All Indexes on PATIENT Table
-- ============================================================================
SELECT 
    i.name AS IndexName,
    i.type_desc,
    ps.name AS PartitionSchemeName,
    COUNT(ic.column_id) AS IncludedColumns
FROM sys.indexes i
LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
LEFT JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = i.index_id
WHERE i.object_id = OBJECT_ID('EPS.PATIENT')
GROUP BY i.name, i.type_desc, ps.name, i.index_id
ORDER BY i.index_id;

-- Expected Output:
-- PK_PATIENT (Clustered): ps_ChainID_EPS ✅
-- Other indexes: NULL (not yet partitioned) ⏳


-- ============================================================================
-- QUERY 10: Comprehensive Partitioning Status Report
-- ============================================================================
SELECT 
    'Partition Function' AS Component,
    'pf_ChainID_EPS' AS [Name],
    CASE WHEN EXISTS(SELECT 1 FROM sys.partition_functions WHERE name = 'pf_ChainID_EPS') THEN '✅ EXISTS' ELSE '❌ MISSING' END AS Status
UNION ALL
SELECT 
    'Partition Scheme',
    'ps_ChainID_EPS',
    CASE WHEN EXISTS(SELECT 1 FROM sys.partition_schemes WHERE name = 'ps_ChainID_EPS') THEN '✅ EXISTS' ELSE '❌ MISSING' END
UNION ALL
SELECT 
    'Primary Key',
    'PK_PATIENT',
    CASE WHEN EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('EPS.PATIENT') AND name = 'PK_PATIENT') THEN '✅ EXISTS' ELSE '❌ MISSING' END
UNION ALL
SELECT 
    'Partition Count',
    'Partitions Created',
    CAST((SELECT COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id = OBJECT_ID('EPS.PATIENT') AND index_id = 1) AS VARCHAR(5))
UNION ALL
SELECT 
    'Table Rows',
    'Total Count',
    CAST((SELECT SUM([rows]) FROM sys.partitions WHERE object_id = OBJECT_ID('EPS.PATIENT') AND index_id = 1) AS VARCHAR(20));


-- ============================================================================
-- SUMMARY: Quick Validation Checklist
-- ============================================================================
-- Run queries 1-7 and verify:
-- ✅ Query 1: pf_ChainID_EPS exists with boundary_value_on_right = 0
-- ✅ Query 2: 5 boundary values shown (1000, 5000, 50000, 100000, 130000)
-- ✅ Query 3: ps_ChainID_EPS exists, mapped to PRIMARY filegroup (6 rows)
-- ✅ Query 4: PK_PATIENT shows PartitionSchemeName = ps_ChainID_EPS
-- ✅ Query 5: Shows 6 partitions with 0 rows each
-- ✅ Query 6: PK columns are CHAIN_ID, ID
-- ✅ Query 7: CHAIN_ID is partition key (partition_ordinal = 1)
--
-- If all 7 checks pass → PARTITIONING VERIFIED ✅
