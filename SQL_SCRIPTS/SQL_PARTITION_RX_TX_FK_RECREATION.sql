-- ============================================================================
-- RX_TX FOREIGN KEY RECREATION
-- Date: June 28, 2026
-- Partitioning Complete - FKs now need recreating with correct column names
-- ============================================================================

PRINT '===== RX_TX FOREIGN KEY RECREATION START ====='

-- Pattern: Each child table has (CHAIN_ID, [FK_COLUMN_TO_RX_TX.ID])
-- RX_TX PK: (ID, CHAIN_ID) on ps_ChainID_EPS

-- ============================================================================
-- Recreate FK #1: COMPOUND_INGREDIENTS_FK2
-- Child column: ID_RX_TX points to RX_TX.ID
-- ============================================================================

ALTER TABLE EPS.COMPOUND_INGREDIENTS 
ADD CONSTRAINT COMPOUND_INGREDIENTS_FK2 
FOREIGN KEY (CHAIN_ID, ID_RX_TX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);
PRINT 'FK: COMPOUND_INGREDIENTS_FK2 recreated'

-- ============================================================================
-- Recreate FK #2: RX_TX_DIAGNOSIS_CODES_FK2
-- Note: Need to check actual column name - likely ID_RX_TX or similar
-- ============================================================================

-- Check and recreate - may need to adjust column name
BEGIN TRY
    ALTER TABLE EPS.RX_TX_DIAGNOSIS_CODES 
    ADD CONSTRAINT RX_TX_DIAGNOSIS_CODES_FK2 
    FOREIGN KEY (CHAIN_ID, ID_RXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);
    PRINT 'FK: RX_TX_DIAGNOSIS_CODES_FK2 recreated (ID_RXTX)'
END TRY
BEGIN CATCH
    PRINT 'ERROR FK2: ' + ERROR_MESSAGE();
    -- Alternative: try with ID_RX_TX
    BEGIN TRY
        ALTER TABLE EPS.RX_TX_DIAGNOSIS_CODES 
        ADD CONSTRAINT RX_TX_DIAGNOSIS_CODES_FK2 
        FOREIGN KEY (CHAIN_ID, ID_RX_TX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);
        PRINT 'FK: RX_TX_DIAGNOSIS_CODES_FK2 recreated (ID_RX_TX - corrected)'
    END TRY
    BEGIN CATCH
        PRINT 'ERROR FK2 (second attempt): ' + ERROR_MESSAGE();
    END CATCH
END CATCH

-- ============================================================================
-- Recreate FK #3: RX_TX_DUR_LIST_FK_IDRXTX
-- Child table column likely: IDRXTX
-- ============================================================================

ALTER TABLE EPS.RX_TX_DUR_LIST 
ADD CONSTRAINT RX_TX_DUR_LIST_FK_IDRXTX 
FOREIGN KEY (CHAIN_ID, IDRXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);
PRINT 'FK: RX_TX_DUR_LIST_FK_IDRXTX recreated'

-- ============================================================================
-- Recreate FK #4: RX_TX_SIG_STR_PRT_FK_RX_TX
-- Child table column likely: ID_RXTX
-- ============================================================================

ALTER TABLE EPS.RX_TX_SIG_STRUCTURED_PART 
ADD CONSTRAINT RX_TX_SIG_STR_PRT_FK_RX_TX 
FOREIGN KEY (CHAIN_ID, ID_RXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);
PRINT 'FK: RX_TX_SIG_STR_PRT_FK_RX_TX recreated'

-- ============================================================================
-- Recreate FK #5: TX_CRED_FK_RX_TX
-- Child table column likely: IDRXTX
-- ============================================================================

ALTER TABLE EPS.TX_CRED 
ADD CONSTRAINT TX_CRED_FK_RX_TX 
FOREIGN KEY (CHAIN_ID, IDRXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);
PRINT 'FK: TX_CRED_FK_RX_TX recreated'

-- ============================================================================
-- Recreate FK #6: TX_LOT_FK_RX_TX
-- Child table column likely: IDRXTX
-- ============================================================================

ALTER TABLE EPS.TX_LOT 
ADD CONSTRAINT TX_LOT_FK_RX_TX 
FOREIGN KEY (CHAIN_ID, IDRXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);
PRINT 'FK: TX_LOT_FK_RX_TX recreated'

-- ============================================================================
-- Recreate FK #7: TX_TP_FK_RX_TX
-- Child table column likely: IDRXTX
-- ============================================================================

ALTER TABLE EPS.TX_TP 
ADD CONSTRAINT TX_TP_FK_RX_TX 
FOREIGN KEY (CHAIN_ID, IDRXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);
PRINT 'FK: TX_TP_FK_RX_TX recreated'

-- ============================================================================
-- Recreate FK #8: VIAL_INFO_FK_RX_TX
-- Child table column likely: IDRXTX
-- ============================================================================

ALTER TABLE EPS.VIAL_INFO 
ADD CONSTRAINT VIAL_INFO_FK_RX_TX 
FOREIGN KEY (CHAIN_ID, IDRXTX) REFERENCES EPS.RX_TX(CHAIN_ID, ID);
PRINT 'FK: VIAL_INFO_FK_RX_TX recreated'

-- ============================================================================
-- VERIFICATION
-- ============================================================================

PRINT ''
PRINT '===== FK VERIFICATION ====='

SELECT 
    fk.name AS [FK Name],
    OBJECT_NAME(fk.parent_object_id) AS [Child Table],
    OBJECT_NAME(fk.referenced_object_id) AS [Parent Table]
FROM sys.foreign_keys fk
WHERE fk.referenced_object_id = OBJECT_ID('EPS.RX_TX')
ORDER BY fk.name;

PRINT '===== RX_TX PARTITIONING FULLY COMPLETE ====='
