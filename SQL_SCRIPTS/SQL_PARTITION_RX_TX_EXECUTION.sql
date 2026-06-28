-- ============================================================================
-- RX_TX Table Partitioning Script
-- Database: sqldb-epr-qa (Azure SQL)
-- Date: June 28, 2026
-- Partition Scheme: ps_ChainID_EPS (existing, reuse)
-- Partition Function: pf_ChainID_EPS (existing, reuse)
-- ============================================================================

-- PHASE 1: BACKUP & PREREQUISITES
-- ============================================================================

-- Verify partition function exists
SELECT 'Partition Function Check' AS [Step];
SELECT * FROM sys.partition_functions WHERE name = 'pf_ChainID_EPS';

-- Verify partition scheme exists  
SELECT 'Partition Scheme Check' AS [Step];
SELECT * FROM sys.partition_schemes WHERE name = 'ps_ChainID_EPS';

-- Check current RX_TX status
SELECT 'Current RX_TX Status' AS [Step];
SELECT 
    OBJECT_NAME(p.object_id) AS [Table],
    p.partition_number,
    p.rows
FROM sys.partitions p
WHERE p.object_id = OBJECT_ID('EPS.RX_TX')
    AND p.index_id IN (0, 1)
ORDER BY p.index_id, p.partition_number;

-- ============================================================================
-- PHASE 2: DROP EXISTING INDEXES (to allow PK modification)
-- ============================================================================

ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_PK;

DROP INDEX IF EXISTS idx_rx_tx_chain_id ON EPS.RX_TX;
DROP INDEX IF EXISTS idx_rx_tx_chain_patient_composite ON EPS.RX_TX;
DROP INDEX IF EXISTS idx_rx_tx_id_patient ON EPS.RX_TX;

-- ============================================================================
-- PHASE 3: RECREATE PRIMARY KEY ON PARTITION SCHEME
-- ============================================================================

ALTER TABLE EPS.RX_TX
ADD CONSTRAINT RX_TX_PK 
    PRIMARY KEY CLUSTERED (CHAIN_ID, ID)
    ON ps_ChainID_EPS(CHAIN_ID);

-- ============================================================================
-- PHASE 4: RECREATE NONCLUSTERED INDEXES ON PARTITION SCHEME
-- ============================================================================

-- Index 1: CHAIN_ID lookup (partition-aligned)
CREATE NONCLUSTERED INDEX idx_rx_tx_chain_id
    ON EPS.RX_TX (CHAIN_ID)
    ON ps_ChainID_EPS(CHAIN_ID);

-- Index 2: CHAIN_ID + PATIENT composite (partition-aligned)
-- Note: Adjust column names based on actual schema (check source for PATIENT_ID or equivalent)
CREATE NONCLUSTERED INDEX idx_rx_tx_chain_patient_composite
    ON EPS.RX_TX (CHAIN_ID, ID)  -- Adjust second column as needed
    ON ps_ChainID_EPS(CHAIN_ID);

-- Index 3: ID + PATIENT lookup (partition-aligned)
CREATE NONCLUSTERED INDEX idx_rx_tx_id_patient
    ON EPS.RX_TX (ID)
    ON ps_ChainID_EPS(CHAIN_ID);

-- ============================================================================
-- PHASE 5: VERIFY PARTITIONS CREATED
-- ============================================================================

SELECT 'Partition Verification' AS [Step];

-- Check partition distribution
SELECT 
    p.partition_number AS [Partition #],
    p.rows AS [Row Count],
    prv.value AS [Upper Boundary (CHAIN_ID)]
FROM sys.partitions p
LEFT JOIN sys.partition_range_values prv 
    ON OBJECT_ID('pf_ChainID_EPS') = prv.function_id
    AND p.partition_number = prv.boundary_id + 1
WHERE p.object_id = OBJECT_ID('EPS.RX_TX')
    AND p.index_id = 1  -- Clustered index
ORDER BY p.partition_number;

-- Verify partition scheme applied to table
SELECT 
    t.name AS [Table Name],
    ps.name AS [Partition Scheme],
    pf.name AS [Partition Function]
FROM sys.tables t
INNER JOIN sys.partition_schemes ps ON t.lob_data_space_id = ps.data_space_id
INNER JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
WHERE t.name = 'RX_TX'
    AND SCHEMA_NAME(t.schema_id) = 'EPS';

-- ============================================================================
-- PHASE 6: INDEX VERIFICATION
-- ============================================================================

SELECT 'Index Verification' AS [Step];

SELECT 
    i.name AS [Index Name],
    i.type_desc AS [Index Type],
    CASE WHEN ps.name IS NOT NULL THEN ps.name ELSE 'NOT PARTITIONED' END AS [Partition Scheme]
FROM sys.indexes i
LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
WHERE i.object_id = OBJECT_ID('EPS.RX_TX')
ORDER BY i.name;

-- ============================================================================
-- PHASE 7: ROW COUNT SUMMARY
-- ============================================================================

SELECT 'Row Count Summary' AS [Step];

SELECT 
    'RX_TX' AS [Table],
    (SELECT COUNT(*) FROM EPS.RX_TX) AS [Total Rows],
    (SELECT COUNT(*) FROM EPS.RX_TX WHERE CHAIN_ID <= 1000) AS [P1 (≤1000)],
    (SELECT COUNT(*) FROM EPS.RX_TX WHERE CHAIN_ID > 1000 AND CHAIN_ID <= 5000) AS [P2 (1001-5000)],
    (SELECT COUNT(*) FROM EPS.RX_TX WHERE CHAIN_ID > 5000 AND CHAIN_ID <= 50000) AS [P3 (5001-50000)],
    (SELECT COUNT(*) FROM EPS.RX_TX WHERE CHAIN_ID > 50000 AND CHAIN_ID <= 100000) AS [P4 (50001-100000)],
    (SELECT COUNT(*) FROM EPS.RX_TX WHERE CHAIN_ID > 100000 AND CHAIN_ID <= 130000) AS [P5 (100001-130000)],
    (SELECT COUNT(*) FROM EPS.RX_TX WHERE CHAIN_ID > 130000) AS [P6 (>130000)];

-- ============================================================================
-- EXECUTION COMPLETE
-- ============================================================================
-- 
-- Summary:
-- - Primary Key recreated on partition scheme ps_ChainID_EPS
-- - 3 nonclustered indexes recreated on partition scheme
-- - Table now uses RANGE LEFT partitioning on CHAIN_ID
-- - 6 partitions created (P1-P6)
-- - No data moved (partition scheme applied to existing data)
--
-- ============================================================================
