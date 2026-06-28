-- Direct SQL: Drop child FKs and recreate partitioned PKs for all 7 remaining Category A1 tables
-- This script drops blocking child table FKs, then recreates PKs as partitioned

USE [sqldb-epr-qa];

-- ============================================================================
-- RX_TX
-- ============================================================================
PRINT 'Processing RX_TX...'
BEGIN TRY
    -- Drop child FKs (from tables that reference RX_TX)
    ALTER TABLE EPS.PACKAGE_INFO DROP CONSTRAINT PACKAGE_INFO_FK_RX_TX;
    ALTER TABLE EPS.RX_TX_DIAGNOSIS_CODES DROP CONSTRAINT RX_TX_DIAGNOSIS_CODES_FK2;
    ALTER TABLE EPS.RX_TX_DUR_LIST DROP CONSTRAINT RX_TX_DUR_LIST_FK_IDRXTX;
    ALTER TABLE EPS.TX_CRED DROP CONSTRAINT TX_CRED_FK_RX_TX;
    ALTER TABLE EPS.TX_LOT DROP CONSTRAINT TX_LOT_FK_RX_TX;
    ALTER TABLE EPS.TX_TP DROP CONSTRAINT TX_TP_FK_RX_TX;
    ALTER TABLE EPS.VIAL_INFO DROP CONSTRAINT VIAL_INFO_FK_RX_TX;
    ALTER TABLE EPS.COMPOUND_INGREDIENTS DROP CONSTRAINT COMPOUND_INGREDIENTS_FK2;
    ALTER TABLE EPS.RX_TX_SIG_STRUCTURED_PART DROP CONSTRAINT RX_TX_SIG_STR_PRT_FK_RX_TX;
    
    -- Drop outbound FKs
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_FK_ALT_PRESCRIBER;
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_FK_ESCHAIN;
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_FK_ESSTORE;
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_FK_MOD_PCM;
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_FK_PRESCRIBER;
    
    -- Drop PK
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_PK;
    
    -- Create partitioned PK
    ALTER TABLE EPS.RX_TX ADD CONSTRAINT PK_RX_TX PRIMARY KEY CLUSTERED (CHAIN_ID, [RX_TX_ID]) ON ps_ChainID_EPS(CHAIN_ID);
    
    PRINT 'RX_TX: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'RX_TX: ' + ERROR_MESSAGE()
END CATCH

-- ============================================================================
-- PRESCRIBER
-- ============================================================================
PRINT 'Processing PRESCRIBER...'
BEGIN TRY
    -- Drop child FKs
    ALTER TABLE EPS.RX_TX DROP CONSTRAINT RX_TX_FK_PRESCRIBER;
    
    -- Drop outbound FKs
    ALTER TABLE EPS.PRESCRIBER DROP CONSTRAINT PRESCRIBER_FK_ESCHAIN;
    ALTER TABLE EPS.PRESCRIBER DROP CONSTRAINT PRESCRIBER_FK_ESSTORE;
    
    -- Drop PK
    ALTER TABLE EPS.PRESCRIBER DROP CONSTRAINT PRESCRIBER_PK;
    
    -- Create partitioned PK
    ALTER TABLE EPS.PRESCRIBER ADD CONSTRAINT PK_PRESCRIBER PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    
    PRINT 'PRESCRIBER: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'PRESCRIBER: ' + ERROR_MESSAGE()
END CATCH

-- ============================================================================
-- MRN
-- ============================================================================
PRINT 'Processing MRN...'
BEGIN TRY
    -- Drop child FKs (none detected)
    
    -- Drop outbound FKs
    ALTER TABLE EPS.MRN DROP CONSTRAINT MRN_FK_ESCHAIN;
    ALTER TABLE EPS.MRN DROP CONSTRAINT MRN_FK_PATIENT;
    ALTER TABLE EPS.MRN DROP CONSTRAINT MRN_FK_ROOTID;
    
    -- Drop PK
    ALTER TABLE EPS.MRN DROP CONSTRAINT MRN_PK;
    
    -- Create partitioned PK
    ALTER TABLE EPS.MRN ADD CONSTRAINT PK_MRN PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    
    PRINT 'MRN: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'MRN: ' + ERROR_MESSAGE()
END CATCH

-- ============================================================================
-- CARD
-- ============================================================================
PRINT 'Processing CARD...'
BEGIN TRY
    -- Drop child FKs
    ALTER TABLE EPS.TP_LINK DROP CONSTRAINT TP_LINK_FK_CARD;
    ALTER TABLE EPS.WORKMANS_COMP DROP CONSTRAINT WORKCOMP_FK_CARD;
    
    -- Drop outbound FKs
    ALTER TABLE EPS.CARD DROP CONSTRAINT CARD_FK_ESCHAIN;
    ALTER TABLE EPS.CARD DROP CONSTRAINT CARD_FK_ESSTORE;
    
    -- Drop PK
    ALTER TABLE EPS.CARD DROP CONSTRAINT PK_CARD;
    
    -- Create partitioned PK
    ALTER TABLE EPS.CARD ADD CONSTRAINT PK_CARD PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    
    PRINT 'CARD: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'CARD: ' + ERROR_MESSAGE()
END CATCH

-- ============================================================================
-- PAYMENT
-- ============================================================================
PRINT 'Processing PAYMENT...'
BEGIN TRY
    -- Drop child FKs
    ALTER TABLE EPS.RX_TX_PAYMENT DROP CONSTRAINT RX_TX_PAYMENT_FK_CHAIN_PAYID;
    
    -- Drop outbound FKs
    ALTER TABLE EPS.PAYMENT DROP CONSTRAINT PAYMENT_FK_ESCHAIN;
    ALTER TABLE EPS.PAYMENT DROP CONSTRAINT PAYMENT_FK_ESSTORE;
    
    -- Drop PK
    ALTER TABLE EPS.PAYMENT DROP CONSTRAINT PAYMENT_PK;
    
    -- Create partitioned PK
    ALTER TABLE EPS.PAYMENT ADD CONSTRAINT PK_PAYMENT PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    
    PRINT 'PAYMENT: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'PAYMENT: ' + ERROR_MESSAGE()
END CATCH

-- ============================================================================
-- LINE_ITEM
-- ============================================================================
PRINT 'Processing LINE_ITEM...'
BEGIN TRY
    -- Drop child FKs (none detected)
    
    -- Drop outbound FKs
    ALTER TABLE EPS.LINE_ITEM DROP CONSTRAINT LINE_ITEM_FK_PATIENT;
    ALTER TABLE EPS.LINE_ITEM DROP CONSTRAINT LINE_ITEM_FK_ESCHAIN;
    ALTER TABLE EPS.LINE_ITEM DROP CONSTRAINT LINE_ITEM_FK_ESSTORE;
    
    -- Drop PK
    ALTER TABLE EPS.LINE_ITEM DROP CONSTRAINT PK_LINE_ITEM;
    
    -- Create partitioned PK
    ALTER TABLE EPS.LINE_ITEM ADD CONSTRAINT PK_LINE_ITEM PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    
    PRINT 'LINE_ITEM: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'LINE_ITEM: ' + ERROR_MESSAGE()
END CATCH

-- ============================================================================
-- ALLERGY
-- ============================================================================
PRINT 'Processing ALLERGY...'
BEGIN TRY
    -- Drop child FKs (none detected)
    
    -- Drop outbound FKs
    ALTER TABLE EPS.ALLERGY DROP CONSTRAINT ALLERGY_FK_ESCHAIN;
    ALTER TABLE EPS.ALLERGY DROP CONSTRAINT ALLERGY_FK_ESSTORE;
    ALTER TABLE EPS.ALLERGY DROP CONSTRAINT ALLERGY_FK_PATIENT;
    
    -- Drop PK
    ALTER TABLE EPS.ALLERGY DROP CONSTRAINT PK_ALLERGY;
    
    -- Create partitioned PK
    ALTER TABLE EPS.ALLERGY ADD CONSTRAINT PK_ALLERGY PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    
    PRINT 'ALLERGY: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'ALLERGY: ' + ERROR_MESSAGE()
END CATCH

-- ============================================================================
-- DISEASE
-- ============================================================================
PRINT 'Processing DISEASE...'
BEGIN TRY
    -- Drop child FKs (none detected)
    
    -- Drop outbound FKs
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT DISEASE_FK_ESCHAIN;
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT DISEASE_FK_ESSTORE;
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT DISEASE_FK_PATIENT;
    
    -- Drop PK
    ALTER TABLE EPS.DISEASE DROP CONSTRAINT PK_DISEASE;
    
    -- Create partitioned PK
    ALTER TABLE EPS.DISEASE ADD CONSTRAINT PK_DISEASE PRIMARY KEY CLUSTERED (CHAIN_ID, [ID]) ON ps_ChainID_EPS(CHAIN_ID);
    
    PRINT 'DISEASE: SUCCESS'
END TRY
BEGIN CATCH
    PRINT 'DISEASE: ' + ERROR_MESSAGE()
END CATCH

-- ============================================================================
-- VERIFICATION
-- ============================================================================
PRINT ''
PRINT '========== VERIFICATION =========='

SELECT 
    'RX_TX' as [Table],
    COUNT(DISTINCT partition_number) as [Partitions]
FROM sys.partitions
WHERE object_id=OBJECT_ID('EPS.RX_TX') AND index_id=1
UNION ALL
SELECT 'PRESCRIBER', COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.PRESCRIBER') AND index_id=1
UNION ALL
SELECT 'MRN', COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.MRN') AND index_id=1
UNION ALL
SELECT 'CARD', COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.CARD') AND index_id=1
UNION ALL
SELECT 'PAYMENT', COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.PAYMENT') AND index_id=1
UNION ALL
SELECT 'LINE_ITEM', COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.LINE_ITEM') AND index_id=1
UNION ALL
SELECT 'ALLERGY', COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.ALLERGY') AND index_id=1
UNION ALL
SELECT 'DISEASE', COUNT(DISTINCT partition_number) FROM sys.partitions WHERE object_id=OBJECT_ID('EPS.DISEASE') AND index_id=1
ORDER BY [Table];

PRINT 'Execution Complete'
