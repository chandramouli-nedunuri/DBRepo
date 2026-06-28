-- CATEGORY A1 BATCH PARTITIONING - ALL REMAINING TABLES
-- Created: 2026-06-26
-- Tables: RX_TX, PRESCRIBER, MRN, CARD, PAYMENT, LINE_ITEM, ALLERGY, DISEASE

USE sqldb-epr-qa;

-- ============================================================================
-- RX_TX
-- ============================================================================
PRINT '========== PARTITIONING: RX_TX =========='
ALTER TABLE EPS.RX_TX ADD CONSTRAINT PK_RX_TX PRIMARY KEY CLUSTERED (CHAIN_ID, [RX_TX_ID]) ON ps_ChainID_EPS(CHAIN_ID);
PRINT 'RX_TX: OK'

-- ============================================================================
-- PRESCRIBER
-- ============================================================================
PRINT '========== PARTITIONING: PRESCRIBER =========='
ALTER TABLE EPS.PRESCRIBER ADD CONSTRAINT PK_PRESCRIBER PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
PRINT 'PRESCRIBER: OK'

-- ============================================================================
-- MRN
-- ============================================================================
PRINT '========== PARTITIONING: MRN =========='
ALTER TABLE EPS.MRN ADD CONSTRAINT PK_MRN PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
PRINT 'MRN: OK'

-- ============================================================================
-- CARD
-- ============================================================================
PRINT '========== PARTITIONING: CARD =========='
ALTER TABLE EPS.CARD ADD CONSTRAINT PK_CARD PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
PRINT 'CARD: OK'

-- ============================================================================
-- PAYMENT
-- ============================================================================
PRINT '========== PARTITIONING: PAYMENT =========='
ALTER TABLE EPS.PAYMENT ADD CONSTRAINT PK_PAYMENT PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
PRINT 'PAYMENT: OK'

-- ============================================================================
-- LINE_ITEM
-- ============================================================================
PRINT '========== PARTITIONING: LINE_ITEM =========='
ALTER TABLE EPS.LINE_ITEM ADD CONSTRAINT PK_LINE_ITEM PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
PRINT 'LINE_ITEM: OK'

-- ============================================================================
-- ALLERGY
-- ============================================================================
PRINT '========== PARTITIONING: ALLERGY =========='
ALTER TABLE EPS.ALLERGY ADD CONSTRAINT PK_ALLERGY PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
PRINT 'ALLERGY: OK'

-- ============================================================================
-- DISEASE
-- ============================================================================
PRINT '========== PARTITIONING: DISEASE =========='
ALTER TABLE EPS.DISEASE ADD CONSTRAINT PK_DISEASE PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
PRINT 'DISEASE: OK'

-- ============================================================================
-- VERIFICATION
-- ============================================================================
PRINT '========== VERIFICATION =========='
SELECT 
    name,
    COUNT(DISTINCT partition_number) as Partitions
FROM (
    SELECT 'RX_TX' as name, partition_number FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.RX_TX') AND index_id=1
    UNION ALL
    SELECT 'PRESCRIBER', partition_number FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.PRESCRIBER') AND index_id=1
    UNION ALL
    SELECT 'MRN', partition_number FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.MRN') AND index_id=1
    UNION ALL
    SELECT 'CARD', partition_number FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.CARD') AND index_id=1
    UNION ALL
    SELECT 'PAYMENT', partition_number FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.PAYMENT') AND index_id=1
    UNION ALL
    SELECT 'LINE_ITEM', partition_number FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.LINE_ITEM') AND index_id=1
    UNION ALL
    SELECT 'ALLERGY', partition_number FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.ALLERGY') AND index_id=1
    UNION ALL
    SELECT 'DISEASE', partition_number FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.DISEASE') AND index_id=1
)
GROUP BY name
ORDER BY name;

PRINT '========== COMPLETE =========='
