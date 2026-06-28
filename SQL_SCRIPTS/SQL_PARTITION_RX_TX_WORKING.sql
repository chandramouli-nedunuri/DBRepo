-- ============================================================================
-- RX_TX TABLE PARTITIONING - EXACT PATTERN FROM PATIENT SUCCESS
-- Database: sqldb-epr-qa (Azure SQL)
-- Date: June 28, 2026
-- ============================================================================

-- STEP 1: Drop existing non-clustered indexes
PRINT '=== STEP 1: Drop existing non-clustered indexes ==='

DECLARE @sql NVARCHAR(MAX) = '';

SELECT @sql += 'DROP INDEX ' + QUOTENAME(i.name) + ' ON EPS.RX_TX;' + CHAR(10)
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('EPS.RX_TX')
  AND i.type > 1;  -- Exclude clustered index (type = 1)

IF @sql <> ''
BEGIN
    PRINT 'Dropping indexes...'
    EXEC sp_executesql @sql;
    PRINT 'Non-clustered indexes dropped.'
END
ELSE
BEGIN
    PRINT 'No non-clustered indexes found.'
END;

-- ============================================================================
-- STEP 2: Drop PRIMARY KEY constraint
-- ============================================================================

PRINT '=== STEP 2: Drop primary key constraint ==='

DECLARE @PK_Name NVARCHAR(128);
SELECT @PK_Name = CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'EPS' 
  AND TABLE_NAME = 'RX_TX'
  AND CONSTRAINT_TYPE = 'PRIMARY KEY';

IF @PK_Name IS NOT NULL
BEGIN
    DECLARE @DropPK NVARCHAR(256) = 'ALTER TABLE EPS.RX_TX DROP CONSTRAINT ' + QUOTENAME(@PK_Name);
    EXEC sp_executesql @DropPK;
    PRINT 'Primary key constraint ' + @PK_Name + ' dropped.'
END
ELSE
BEGIN
    PRINT 'No primary key found (unexpected!)'
END;

-- ============================================================================
-- STEP 3: Create NEW PRIMARY KEY on partition scheme
-- Pattern: (original_pk_columns, CHAIN_ID) ON ps_ChainID_EPS(CHAIN_ID)
-- ============================================================================

PRINT '=== STEP 3: Create new primary key on partition scheme ==='

-- For RX_TX: primary key is (ID, CHAIN_ID) where CHAIN_ID is partition column
ALTER TABLE EPS.RX_TX
ADD CONSTRAINT RX_TX_PK PRIMARY KEY CLUSTERED (ID, CHAIN_ID)
ON ps_ChainID_EPS(CHAIN_ID);

PRINT 'Primary key RX_TX_PK created on partition scheme ps_ChainID_EPS'

-- ============================================================================
-- STEP 4: Create supporting indexes on partition scheme
-- ============================================================================

PRINT '=== STEP 4: Create supporting indexes ==='

CREATE NONCLUSTERED INDEX idx_rx_tx_chain_id
ON EPS.RX_TX (CHAIN_ID)
ON ps_ChainID_EPS(CHAIN_ID);

CREATE NONCLUSTERED INDEX idx_rx_tx_chain_patient_composite
ON EPS.RX_TX (CHAIN_ID, ID)
ON ps_ChainID_EPS(CHAIN_ID);

CREATE NONCLUSTERED INDEX idx_rx_tx_id_patient
ON EPS.RX_TX (ID)
ON ps_ChainID_EPS(CHAIN_ID);

PRINT 'Indexes created on partition scheme.'

-- ============================================================================
-- STEP 5: VERIFICATION
-- ============================================================================

PRINT '=== STEP 5: VERIFICATION ==='

-- Verify partitions created
SELECT 
    'Partitions for RX_TX' AS [Check],
    COUNT(*) AS [Count]
FROM sys.partitions
WHERE object_id = OBJECT_ID('EPS.RX_TX')
  AND index_id = 1;

-- Verify table uses partition scheme
SELECT 
    t.name AS [Table],
    ps.name AS [Partition Scheme],
    pf.name AS [Partition Function],
    COUNT(DISTINCT p.partition_number) AS [Partition Count]
FROM sys.tables t
INNER JOIN sys.partition_schemes ps ON t.lob_data_space_id = ps.data_space_id
INNER JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
INNER JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id = 1
WHERE t.name = 'RX_TX' AND SCHEMA_NAME(t.schema_id) = 'EPS'
GROUP BY t.name, ps.name, pf.name;

-- Verify index details
SELECT 
    i.name AS [Index],
    i.type_desc AS [Type],
    CASE WHEN ps.name IS NOT NULL THEN ps.name ELSE 'NOT PARTITIONED' END AS [Partition Scheme]
FROM sys.indexes i
LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
WHERE i.object_id = OBJECT_ID('EPS.RX_TX')
ORDER BY i.name;

PRINT '=== RX_TX PARTITIONING COMPLETE ==='
