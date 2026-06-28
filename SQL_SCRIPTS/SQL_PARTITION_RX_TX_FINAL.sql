-- ============================================================================
-- RX_TX TABLE PARTITIONING (Following PATIENT Success Pattern)
-- Database: sqldb-epr-qa (Azure SQL)
-- Date: June 28, 2026
-- Strategy: Same approach as successful PATIENT partitioning
-- ============================================================================

PRINT '===== RX_TX PARTITIONING START =====' 

-- ============================================================================
-- STEP 1: Drop existing non-clustered indexes
-- ============================================================================

PRINT '--- STEP 1: Drop existing non-clustered indexes ---'

DECLARE @sql NVARCHAR(MAX) = '';

SELECT @sql += 'DROP INDEX ' + QUOTENAME(i.name) + ' ON EPS.RX_TX;' + CHAR(10)
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('EPS.RX_TX')
  AND i.type > 1;  -- type > 1 means not CLUSTERED

IF @sql <> ''
BEGIN
    PRINT 'Dropping indexes...'
    EXEC sp_executesql @sql;
    PRINT 'Indexes dropped.'
END
ELSE
BEGIN
    PRINT 'No indexes to drop.'
END;

-- ============================================================================
-- STEP 2: Drop PRIMARY KEY constraint
-- ============================================================================

PRINT '--- STEP 2: Drop primary key ---'

DECLARE @PK_Name NVARCHAR(128);
SELECT @PK_Name = CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'EPS' 
  AND TABLE_NAME = 'RX_TX'
  AND CONSTRAINT_TYPE = 'PRIMARY KEY';

IF @PK_Name IS NOT NULL
BEGIN
    DECLARE @DropPK NVARCHAR(256) = 'ALTER TABLE EPS.RX_TX DROP CONSTRAINT ' + QUOTENAME(@PK_Name);
    PRINT 'Executing: ' + @DropPK;
    EXEC sp_executesql @DropPK;
    PRINT 'Primary key ' + @PK_Name + ' dropped.';
END
ELSE
BEGIN
    PRINT 'No primary key found.';
END;

-- ============================================================================
-- STEP 3: Create NEW PRIMARY KEY on partition scheme
-- ============================================================================

PRINT '--- STEP 3: Create new primary key on partition scheme ---'

-- For RX_TX, PK is on (CHAIN_ID, ID)
-- CHAIN_ID is the partition column
ALTER TABLE EPS.RX_TX
ADD CONSTRAINT RX_TX_PK PRIMARY KEY CLUSTERED (CHAIN_ID, ID)
ON ps_ChainID_EPS(CHAIN_ID);

PRINT 'Primary key RX_TX_PK created on partition scheme ps_ChainID_EPS';

-- ============================================================================
-- STEP 4: Recreate nonclustered indexes on partition scheme
-- ============================================================================

PRINT '--- STEP 4: Recreate nonclustered indexes ---'

-- Index 1: CHAIN_ID lookup
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_rx_tx_chain_id' AND object_id = OBJECT_ID('EPS.RX_TX'))
BEGIN
    CREATE NONCLUSTERED INDEX idx_rx_tx_chain_id
    ON EPS.RX_TX (CHAIN_ID)
    ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'Created index idx_rx_tx_chain_id';
END

-- Index 2: CHAIN_ID + ID composite
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_rx_tx_chain_patient_composite' AND object_id = OBJECT_ID('EPS.RX_TX'))
BEGIN
    CREATE NONCLUSTERED INDEX idx_rx_tx_chain_patient_composite
    ON EPS.RX_TX (CHAIN_ID, ID)
    ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'Created index idx_rx_tx_chain_patient_composite';
END

-- Index 3: ID lookup
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_rx_tx_id_patient' AND object_id = OBJECT_ID('EPS.RX_TX'))
BEGIN
    CREATE NONCLUSTERED INDEX idx_rx_tx_id_patient
    ON EPS.RX_TX (ID)
    ON ps_ChainID_EPS(CHAIN_ID);
    PRINT 'Created index idx_rx_tx_id_patient';
END

-- ============================================================================
-- STEP 5: VERIFICATION
-- ============================================================================

PRINT '--- STEP 5: Verification ---'

-- Verify partitions created
SELECT 
    'RX_TX Partition Status' AS [Check],
    p.partition_number AS [Partition #],
    p.rows AS [Row Count]
FROM sys.partitions p
WHERE p.object_id = OBJECT_ID('EPS.RX_TX')
    AND p.index_id = 1  -- Clustered index only
ORDER BY p.partition_number;

-- Verify partition scheme applied
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

-- Verify indexes recreated
SELECT 
    i.name AS [Index],
    i.type_desc AS [Type],
    ps.name AS [Partition Scheme]
FROM sys.indexes i
LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
WHERE i.object_id = OBJECT_ID('EPS.RX_TX')
ORDER BY i.name;

PRINT '===== RX_TX PARTITIONING COMPLETE =====' 
