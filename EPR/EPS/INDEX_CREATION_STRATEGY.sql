-- ============================================================================
-- AZURE SQL INDEX CREATION STRATEGY
-- EPR Database Migration - Phase 4c
-- ============================================================================
-- This script creates recommended indexes for the EPR database
-- Priorities: Foreign Key columns > Search columns > Filtered indexes
-- ============================================================================

PRINT '════════════════════════════════════════════════════════';
PRINT 'INDEX CREATION STRATEGY - EPR DATABASE';
PRINT 'Time: ' + CONVERT(VARCHAR(19), GETDATE(), 120);
PRINT '════════════════════════════════════════════════════════';
PRINT '';

-- ============================================================================
-- PHASE 1: COUNT EXISTING INDEXES
-- ============================================================================

DECLARE @indexCountBefore INT = (
    SELECT COUNT(*) FROM sys.indexes 
    WHERE object_id IN (SELECT object_id FROM sys.objects WHERE type = 'U')
);

PRINT 'Existing Clustered Indexes: ' + CAST(@indexCountBefore AS VARCHAR(10));
PRINT '';

-- ============================================================================
-- PHASE 2: FOREIGN KEY COLUMN INDEXES (HIGH PRIORITY)
-- These dramatically improve JOIN performance (30+ tables need these)
-- ============================================================================

PRINT 'CATEGORY 1: FOREIGN KEY COLUMN INDEXES (High Priority)';
PRINT '════════════════════════════════════════════════════════';
PRINT '';

-- INDEX 1: CHAIN_ID indexes (appears in 50+ tables)
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('EPS.ADDRESS') AND name = 'idx_address_chain_id')
BEGIN
    CREATE NONCLUSTERED INDEX [idx_address_chain_id] 
    ON [EPS].[ADDRESS] ([CHAIN_ID] ASC)
    WITH (FILLFACTOR = 90);
    PRINT '✅ Created: idx_address_chain_id';
END;

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('EPS.PATIENT') AND name = 'idx_patient_chain_id')
BEGIN
    CREATE NONCLUSTERED INDEX [idx_patient_chain_id] 
    ON [EPS].[PATIENT] ([CHAIN_ID] ASC)
    WITH (FILLFACTOR = 90);
    PRINT '✅ Created: idx_patient_chain_id';
END;

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('EPS.RX_TX') AND name = 'idx_rx_tx_chain_id')
BEGIN
    CREATE NONCLUSTERED INDEX [idx_rx_tx_chain_id] 
    ON [EPS].[RX_TX] ([CHAIN_ID] ASC)
    WITH (FILLFACTOR = 90);
    PRINT '✅ Created: idx_rx_tx_chain_id';
END;

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('EPS.PRESCRIBER') AND name = 'idx_prescriber_chain_id')
BEGIN
    CREATE NONCLUSTERED INDEX [idx_prescriber_chain_id] 
    ON [EPS].[PRESCRIBER] ([CHAIN_ID] ASC)
    WITH (FILLFACTOR = 90);
    PRINT '✅ Created: idx_prescriber_chain_id';
END;

PRINT '';

-- INDEX 2: ID_PATIENT indexes (appears in 30+ tables, main FK)
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('EPS.ADDRESS') AND name = 'idx_address_id_patient')
BEGIN
    CREATE NONCLUSTERED INDEX [idx_address_id_patient] 
    ON [EPS].[ADDRESS] ([ID_PATIENT] ASC)
    WITH (FILLFACTOR = 90);
    PRINT '✅ Created: idx_address_id_patient';
END;

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('EPS.ALLERGY') AND name = 'idx_allergy_id_patient')
BEGIN
    CREATE NONCLUSTERED INDEX [idx_allergy_id_patient] 
    ON [EPS].[ALLERGY] ([ID_PATIENT] ASC)
    WITH (FILLFACTOR = 90);
    PRINT '✅ Created: idx_allergy_id_patient';
END;

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('EPS.RX_TX') AND name = 'idx_rx_tx_id_patient')
BEGIN
    CREATE NONCLUSTERED INDEX [idx_rx_tx_id_patient] 
    ON [EPS].[RX_TX] ([ID_PATIENT] ASC)
    WITH (FILLFACTOR = 90);
    PRINT '✅ Created: idx_rx_tx_id_patient';
END;

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('EPS.PATIENT_NOTES') AND name = 'idx_patient_notes_id_patient')
BEGIN
    CREATE NONCLUSTERED INDEX [idx_patient_notes_id_patient] 
    ON [EPS].[PATIENT_NOTES] ([ID_PATIENT] ASC)
    WITH (FILLFACTOR = 90);
    PRINT '✅ Created: idx_patient_notes_id_patient';
END;

PRINT '';

-- ============================================================================
-- PHASE 3: COMPOSITE FK INDEXES (HIGH PRIORITY)
-- These handle multi-column FK constraints efficiently
-- ============================================================================

PRINT 'CATEGORY 2: COMPOSITE FOREIGN KEY INDEXES (High Priority)';
PRINT '════════════════════════════════════════════════════════';
PRINT '';

-- COMPOSITE INDEX 1: (CHAIN_ID, ID_PATIENT) on RX_TX-related tables
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('EPS.RX_TX') AND name = 'idx_rx_tx_chain_patient_composite')
BEGIN
    CREATE NONCLUSTERED INDEX [idx_rx_tx_chain_patient_composite] 
    ON [EPS].[RX_TX] ([CHAIN_ID] ASC, [ID_PATIENT] ASC)
    WITH (FILLFACTOR = 90);
    PRINT '✅ Created: idx_rx_tx_chain_patient_composite';
END;

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('EPS.TP_LINK') AND name = 'idx_tp_link_chain_patient_composite')
BEGIN
    CREATE NONCLUSTERED INDEX [idx_tp_link_chain_patient_composite] 
    ON [EPS].[TP_LINK] ([CHAIN_ID] ASC, [ID_PATIENT] ASC)
    WITH (FILLFACTOR = 90);
    PRINT '✅ Created: idx_tp_link_chain_patient_composite';
END;

PRINT '';

-- ============================================================================
-- PHASE 4: ADDITIONAL VERIFICATION
-- ============================================================================

PRINT 'CATEGORY 3: VERIFICATION';
PRINT '════════════════════════════════════════════════════════';
PRINT '';

-- ============================================================================
-- PHASE 5: STATISTICS & VALIDATION
-- ============================================================================

DECLARE @indexCountAfter INT = (
    SELECT COUNT(*) FROM sys.indexes 
    WHERE object_id IN (SELECT object_id FROM sys.objects WHERE type = 'U')
);

PRINT '════════════════════════════════════════════════════════';
PRINT 'INDEX CREATION SUMMARY';
PRINT '════════════════════════════════════════════════════════';
PRINT 'Indexes Before: ' + CAST(@indexCountBefore AS VARCHAR(10));
PRINT 'Indexes After:  ' + CAST(@indexCountAfter AS VARCHAR(10));
PRINT 'Indexes Added:  ' + CAST((@indexCountAfter - @indexCountBefore) AS VARCHAR(10));
PRINT '';
PRINT 'Recommendation: Monitor query performance over 1 week';
PRINT 'Add filtered indexes based on actual usage patterns';
PRINT '';

-- ============================================================================
-- PHASE 7: INDEX STATISTICS REFRESH
-- ============================================================================

PRINT 'Updating index statistics...';
EXEC sp_updatestats;
PRINT '✅ Statistics updated';
PRINT '';

PRINT '════════════════════════════════════════════════════════';
PRINT 'INDEX DEPLOYMENT COMPLETE';
PRINT 'Time: ' + CONVERT(VARCHAR(19), GETDATE(), 120);
PRINT '════════════════════════════════════════════════════════';
