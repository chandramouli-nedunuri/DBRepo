-- ============================================================================
-- RX_TX TABLE MIGRATION - PROPER TABLE RECREATION METHOD
-- ============================================================================

PRINT 'START: RX_TX Table Migration to Partition Scheme'

-- STEP 1: Verify partition infrastructure
SELECT name, type_desc FROM sys.partition_schemes WHERE name = 'ps_ChainID_EPS';
SELECT name, type_desc FROM sys.partition_functions WHERE name = 'pf_ChainID_EPS';

-- STEP 2: Get row count before migration
DECLARE @RowCount INT;
SELECT @RowCount = COUNT(*) FROM EPS.RX_TX;
PRINT 'Current row count: ' + CAST(@RowCount AS VARCHAR(20));

-- STEP 3: Rename current table to backup
IF OBJECT_ID('EPS.RX_TX_OLD', 'U') IS NOT NULL
    DROP TABLE EPS.RX_TX_OLD;

EXEC sp_rename 'EPS.RX_TX', 'RX_TX_OLD';
PRINT 'Renamed EPS.RX_TX to RX_TX_OLD';

-- STEP 4: Create new table on partition scheme
-- Using dynamic SQL to build CREATE TABLE from RX_TX_OLD structure
DECLARE @CreateTableSQL NVARCHAR(MAX) = 'CREATE TABLE EPS.RX_TX (' + CHAR(10);

SELECT @CreateTableSQL += '  [' + COLUMN_NAME + '] ' + DATA_TYPE +
    CASE WHEN CHARACTER_MAXIMUM_LENGTH > 0 THEN '(' + CAST(CHARACTER_MAXIMUM_LENGTH AS VARCHAR) + ')' 
         WHEN CHARACTER_MAXIMUM_LENGTH = -1 THEN '(MAX)' 
         WHEN NUMERIC_PRECISION IS NOT NULL THEN '(' + CAST(NUMERIC_PRECISION AS VARCHAR) + ',' + CAST(COALESCE(NUMERIC_SCALE, 0) AS VARCHAR) + ')'
         ELSE '' 
    END +
    CASE WHEN IS_NULLABLE = 'YES' THEN ' NULL' ELSE ' NOT NULL' END + ',' + CHAR(10)
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'EPS' AND TABLE_NAME = 'RX_TX_OLD'
ORDER BY ORDINAL_POSITION;

-- Remove trailing comma and close parenthesis
SET @CreateTableSQL = LEFT(@CreateTableSQL, LEN(@CreateTableSQL) - 3) + CHAR(10) + ') ON ps_ChainID_EPS(CHAIN_ID);';

-- Execute the CREATE TABLE
PRINT 'Executing dynamic CREATE TABLE...';
EXEC sp_executesql @CreateTableSQL;
PRINT 'Created EPS.RX_TX on partition scheme ps_ChainID_EPS';

-- STEP 5: Add primary key constraint
ALTER TABLE EPS.RX_TX
ADD CONSTRAINT RX_TX_PK PRIMARY KEY CLUSTERED (CHAIN_ID, ID)
ON ps_ChainID_EPS(CHAIN_ID);
PRINT 'Added partitioned primary key RX_TX_PK';

-- STEP 6: Copy data from backup table
PRINT 'Copying data from RX_TX_OLD...';
INSERT INTO EPS.RX_TX
SELECT * FROM EPS.RX_TX_OLD;

DECLARE @CopiedRows INT = @@ROWCOUNT;
PRINT 'Copied ' + CAST(@CopiedRows AS VARCHAR(20)) + ' rows';

-- STEP 7: Create indexes on partition scheme
PRINT 'Creating indexes on partition scheme...';

CREATE NONCLUSTERED INDEX idx_rx_tx_chain_id
ON EPS.RX_TX (CHAIN_ID)
ON ps_ChainID_EPS(CHAIN_ID);

CREATE NONCLUSTERED INDEX idx_rx_tx_chain_patient_composite
ON EPS.RX_TX (CHAIN_ID, ID)
ON ps_ChainID_EPS(CHAIN_ID);

CREATE NONCLUSTERED INDEX idx_rx_tx_id_patient
ON EPS.RX_TX (ID)
ON ps_ChainID_EPS(CHAIN_ID);

PRINT 'Created 3 nonclustered indexes';

-- STEP 8: Verification
PRINT '';
PRINT '===== VERIFICATION ====='

SELECT 
    'Partition Count' AS [Check],
    COUNT(DISTINCT p.partition_number) AS [Value]
FROM sys.partitions p
WHERE p.object_id = OBJECT_ID('EPS.RX_TX') AND p.index_id = 1;

SELECT 
    'Partition Status' AS [Check],
    p.partition_number,
    p.rows
FROM sys.partitions p
WHERE p.object_id = OBJECT_ID('EPS.RX_TX') AND p.index_id = 1
ORDER BY p.partition_number;

SELECT 
    ps.name AS [Partition Scheme Applied]
FROM sys.tables t
INNER JOIN sys.partition_schemes ps ON t.lob_data_space_id = ps.data_space_id
WHERE t.name = 'RX_TX' AND SCHEMA_NAME(t.schema_id) = 'EPS';

-- STEP 9: Cleanup (optional - manual after verification)
PRINT '';
PRINT 'MIGRATION COMPLETE';
PRINT 'Backup table: EPS.RX_TX_OLD (drop manually after verification)';
PRINT 'DROP TABLE EPS.RX_TX_OLD;  -- Execute this after verification';
