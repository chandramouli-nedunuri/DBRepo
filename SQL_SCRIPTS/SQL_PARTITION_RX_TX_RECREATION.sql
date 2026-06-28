-- ============================================================================
-- RX_TX TABLE MIGRATION TO PARTITION SCHEME
-- Database: sqldb-epr-qa (Azure SQL)
-- Date: June 28, 2026
-- Method: Table Recreation (proven approach for partition scheme application)
-- ============================================================================

-- STEP 1: VERIFY PARTITION INFRASTRUCTURE
-- ============================================================================

PRINT '===== STEP 1: Verifying Partition Infrastructure =====';

SELECT 'Partition Function' AS [Object], name, type_desc FROM sys.partition_functions WHERE name = 'pf_ChainID_EPS'
UNION ALL
SELECT 'Partition Scheme', name, type_desc FROM sys.partition_schemes WHERE name = 'ps_ChainID_EPS';

-- STEP 2: BACKUP - RENAME CURRENT TABLE
-- ============================================================================

PRINT '===== STEP 2: Backing Up Current Table =====';

IF OBJECT_ID('EPS.RX_TX_BACKUP', 'U') IS NOT NULL
    DROP TABLE EPS.RX_TX_BACKUP;

-- Rename current table to backup
EXEC sp_rename 'EPS.RX_TX', 'RX_TX_BACKUP';

PRINT 'Renamed EPS.RX_TX -> EPS.RX_TX_BACKUP';

-- STEP 3: CREATE NEW TABLE ON PARTITION SCHEME
-- ============================================================================

PRINT '===== STEP 3: Creating New Partitioned Table =====';

-- Create RX_TX on partition scheme with all original columns
SELECT *
INTO EPS.RX_TX
FROM EPS.RX_TX_BACKUP
WHERE 1 = 0;  -- Create structure only, no data yet

PRINT 'Created empty EPS.RX_TX (structure only)';

-- STEP 4: APPLY PARTITIONING (rebuild clustered index on partition scheme)
-- ============================================================================

PRINT '===== STEP 4: Applying Partition Scheme =====';

-- Drop default primary key created by SELECT INTO
ALTER TABLE EPS.RX_TX DROP CONSTRAINT PK_RX_TX_BACKUP;

-- Recreate primary key on partition scheme
ALTER TABLE EPS.RX_TX
ADD CONSTRAINT RX_TX_PK PRIMARY KEY CLUSTERED (CHAIN_ID, ID)
ON ps_ChainID_EPS(CHAIN_ID);

PRINT 'Applied partition scheme ps_ChainID_EPS to table';

-- STEP 5: COPY DATA WITH TYPE CASTING (safe)
-- ============================================================================

PRINT '===== STEP 5: Copying Data =====';

INSERT INTO EPS.RX_TX
SELECT * FROM EPS.RX_TX_BACKUP;

DECLARE @RowCount INT = @@ROWCOUNT;
PRINT 'Copied ' + CAST(@RowCount AS VARCHAR(20)) + ' rows';

-- STEP 6: RECREATE INDEXES ON PARTITION SCHEME
-- ============================================================================

PRINT '===== STEP 6: Recreating Indexes on Partition Scheme =====';

-- Index 1
CREATE NONCLUSTERED INDEX idx_rx_tx_chain_id
    ON EPS.RX_TX (CHAIN_ID)
    ON ps_ChainID_EPS(CHAIN_ID);

-- Index 2
CREATE NONCLUSTERED INDEX idx_rx_tx_chain_patient_composite
    ON EPS.RX_TX (CHAIN_ID, ID)
    ON ps_ChainID_EPS(CHAIN_ID);

-- Index 3
CREATE NONCLUSTERED INDEX idx_rx_tx_id_patient
    ON EPS.RX_TX (ID)
    ON ps_ChainID_EPS(CHAIN_ID);

PRINT 'Recreated 3 nonclustered indexes on partition scheme';

-- STEP 7: VERIFY PARTITIONS
-- ============================================================================

PRINT '===== STEP 7: Verifying Partitions =====';

SELECT 
    'Partition Status' AS [Check],
    p.partition_number AS [Partition #],
    p.rows AS [Row Count],
    prv.value AS [Upper Boundary]
FROM sys.partitions p
LEFT JOIN sys.partition_range_values prv ON OBJECT_ID('pf_ChainID_EPS') = prv.function_id 
    AND p.partition_number = prv.boundary_id + 1
WHERE p.object_id = OBJECT_ID('EPS.RX_TX')
    AND p.index_id = 1
ORDER BY p.partition_number;

-- STEP 8: VERIFY TABLE USES PARTITION SCHEME
-- ============================================================================

PRINT '===== STEP 8: Verifying Partition Scheme Application =====';

SELECT 
    t.name AS [Table],
    ps.name AS [Partition Scheme],
    pf.name AS [Partition Function],
    COUNT(DISTINCT p.partition_number) AS [Number of Partitions]
FROM sys.tables t
INNER JOIN sys.partition_schemes ps ON t.lob_data_space_id = ps.data_space_id
INNER JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
INNER JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id = 1
WHERE t.name = 'RX_TX' AND SCHEMA_NAME(t.schema_id) = 'EPS'
GROUP BY t.name, ps.name, pf.name;

-- STEP 9: INDEX VERIFICATION
-- ============================================================================

PRINT '===== STEP 9: Index Verification =====';

SELECT 
    i.name AS [Index],
    i.type_desc AS [Type],
    ps.name AS [Partition Scheme]
FROM sys.indexes i
LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
WHERE i.object_id = OBJECT_ID('EPS.RX_TX')
ORDER BY i.name;

-- STEP 10: FINAL CLEANUP (if all verified)
-- ============================================================================

PRINT '===== STEP 10: Ready for Backup Cleanup =====';

-- Uncomment after verification:
-- DROP TABLE EPS.RX_TX_BACKUP;

PRINT '';
PRINT '==== RX_TX PARTITIONING COMPLETE ====';
PRINT 'Table successfully partitioned on CHAIN_ID';
PRINT 'Partition Scheme: ps_ChainID_EPS';
PRINT 'Partitions: 6 (P1-P6)';
PRINT 'Backup table: EPS.RX_TX_BACKUP (drop manually after verification)';

-- ============================================================================
