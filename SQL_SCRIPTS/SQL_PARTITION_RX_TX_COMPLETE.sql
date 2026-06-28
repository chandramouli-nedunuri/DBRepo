-- ============================================================================
-- RX_TX TABLE PARTITIONING WITH FK HANDLING
-- Database: sqldb-epr-qa (Azure SQL)
-- Date: June 28, 2026
-- Pattern: Replicate exact PATIENT success
-- ============================================================================

PRINT '===== RX_TX PARTITIONING WITH FK HANDLING START ====='

-- ============================================================================
-- STEP 1: DROP ALL FOREIGN KEYS REFERENCING RX_TX (8 total)
-- ============================================================================

PRINT '=== STEP 1: Drop 8 foreign keys referencing RX_TX ==='

ALTER TABLE EPS.COMPOUND_INGREDIENTS DROP CONSTRAINT COMPOUND_INGREDIENTS_FK2;
ALTER TABLE EPS.RX_TX_DIAGNOSIS_CODES DROP CONSTRAINT RX_TX_DIAGNOSIS_CODES_FK2;
ALTER TABLE EPS.RX_TX_DUR_LIST DROP CONSTRAINT RX_TX_DUR_LIST_FK_IDRXTX;
ALTER TABLE EPS.RX_TX_SIG_STRUCTURED_PART DROP CONSTRAINT RX_TX_SIG_STR_PRT_FK_RX_TX;
ALTER TABLE EPS.TX_CRED DROP CONSTRAINT TX_CRED_FK_RX_TX;
ALTER TABLE EPS.TX_LOT DROP CONSTRAINT TX_LOT_FK_RX_TX;
ALTER TABLE EPS.TX_TP DROP CONSTRAINT TX_TP_FK_RX_TX;
ALTER TABLE EPS.VIAL_INFO DROP CONSTRAINT VIAL_INFO_FK_RX_TX;

PRINT 'All 8 foreign keys dropped successfully.'

-- ============================================================================
-- STEP 2: Drop existing non-clustered indexes on RX_TX
-- ============================================================================

PRINT '=== STEP 2: Drop existing non-clustered indexes ==='

DECLARE @sql NVARCHAR(MAX) = '';

SELECT @sql += 'DROP INDEX ' + QUOTENAME(i.name) + ' ON EPS.RX_TX;' + CHAR(10)
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('EPS.RX_TX')
  AND i.type > 1;  -- Exclude clustered (type = 1)

IF @sql <> ''
BEGIN
    PRINT 'Dropping indexes...'
    EXEC sp_executesql @sql;
    PRINT 'Indexes dropped.'
END
ELSE
BEGIN
    PRINT 'No non-clustered indexes found.'
END;

-- ============================================================================
-- STEP 3: Drop PRIMARY KEY constraint
-- ============================================================================

PRINT '=== STEP 3: Drop primary key constraint ==='

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
    PRINT 'Primary key ' + @PK_Name + ' dropped.'
END
ELSE
BEGIN
    PRINT 'No primary key found.'
END;

-- ============================================================================
-- STEP 4: Create NEW PRIMARY KEY on partition scheme
-- Pattern: (original_pk_id, CHAIN_ID) ON ps_ChainID_EPS(CHAIN_ID)
-- ============================================================================

PRINT '=== STEP 4: Create new primary key on partition scheme ==='

ALTER TABLE EPS.RX_TX
ADD CONSTRAINT RX_TX_PK PRIMARY KEY CLUSTERED (ID, CHAIN_ID)
ON ps_ChainID_EPS(CHAIN_ID);

PRINT 'Primary key RX_TX_PK created on partition scheme ps_ChainID_EPS'

-- ============================================================================
-- STEP 5: Create supporting indexes on partition scheme
-- ============================================================================

PRINT '=== STEP 5: Create supporting indexes ==='

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
-- STEP 6: RECREATE FOREIGN KEYS
-- ============================================================================

PRINT '=== STEP 6: Recreate 8 foreign keys ==='

ALTER TABLE EPS.COMPOUND_INGREDIENTS 
ADD CONSTRAINT COMPOUND_INGREDIENTS_FK2 
FOREIGN KEY (CHAIN_ID, ID_RXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);

ALTER TABLE EPS.RX_TX_DIAGNOSIS_CODES 
ADD CONSTRAINT RX_TX_DIAGNOSIS_CODES_FK2 
FOREIGN KEY (CHAIN_ID, ID_RXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);

ALTER TABLE EPS.RX_TX_DUR_LIST 
ADD CONSTRAINT RX_TX_DUR_LIST_FK_IDRXTX 
FOREIGN KEY (CHAIN_ID, IDRXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);

ALTER TABLE EPS.RX_TX_SIG_STRUCTURED_PART 
ADD CONSTRAINT RX_TX_SIG_STR_PRT_FK_RX_TX 
FOREIGN KEY (CHAIN_ID, ID_RXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);

ALTER TABLE EPS.TX_CRED 
ADD CONSTRAINT TX_CRED_FK_RX_TX 
FOREIGN KEY (CHAIN_ID, IDRXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);

ALTER TABLE EPS.TX_LOT 
ADD CONSTRAINT TX_LOT_FK_RX_TX 
FOREIGN KEY (CHAIN_ID, IDRXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);

ALTER TABLE EPS.TX_TP 
ADD CONSTRAINT TX_TP_FK_RX_TX 
FOREIGN KEY (CHAIN_ID, IDRXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);

ALTER TABLE EPS.VIAL_INFO 
ADD CONSTRAINT VIAL_INFO_FK_RX_TX 
FOREIGN KEY (CHAIN_ID, IDRXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);

PRINT 'All 8 foreign keys recreated successfully.'

-- ============================================================================
-- STEP 7: VERIFICATION
-- ============================================================================

PRINT ''
PRINT '===== VERIFICATION ====='

-- Verify partitions created
SELECT 
    'RX_TX Partition Count' AS [Check],
    COUNT(*) AS [Value]
FROM sys.partitions
WHERE object_id = OBJECT_ID('EPS.RX_TX')
  AND index_id = 1;

-- Verify partition details
SELECT 
    'RX_TX Partitions' AS [Check],
    p.partition_number,
    p.rows AS [Row Count],
    prv.value AS [Upper Boundary]
FROM sys.partitions p
LEFT JOIN sys.partition_range_values prv ON OBJECT_ID('pf_ChainID_EPS') = prv.function_id
    AND p.partition_number = prv.boundary_id + 1
WHERE p.object_id = OBJECT_ID('EPS.RX_TX')
    AND p.index_id = 1
ORDER BY p.partition_number;

-- Verify table uses partition scheme
SELECT 
    t.name AS [Table],
    ps.name AS [Partition Scheme],
    pf.name AS [Partition Function]
FROM sys.tables t
INNER JOIN sys.partition_schemes ps ON t.lob_data_space_id = ps.data_space_id
INNER JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
WHERE t.name = 'RX_TX' AND SCHEMA_NAME(t.schema_id) = 'EPS';

-- Verify indexes on partition scheme
SELECT 
    i.name AS [Index],
    i.type_desc AS [Type],
    CASE WHEN ps.name IS NOT NULL THEN ps.name ELSE 'NOT PARTITIONED' END AS [Partition Scheme]
FROM sys.indexes i
LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
WHERE i.object_id = OBJECT_ID('EPS.RX_TX')
ORDER BY i.name;

PRINT ''
PRINT '===== RX_TX PARTITIONING COMPLETE ====='
PRINT 'Table: EPS.RX_TX'
PRINT 'Partition Scheme: ps_ChainID_EPS'
PRINT 'Partitions: 6 (P1-P6 on CHAIN_ID)'
PRINT 'Foreign Keys: 8 recreated'
