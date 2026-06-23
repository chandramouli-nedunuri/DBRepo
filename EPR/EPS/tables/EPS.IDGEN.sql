-- =====================================================================
-- TABLE: EPS.IDGEN
-- =====================================================================
-- Conversion: Oracle → Azure SQL Server
-- Source: EPS.IDGEN.sql (1,920 lines)
-- 
-- ⚠️  CRITICAL ISSUE: FK DEFERRABILITY ⚠️
-- This table contains DEFERRABLE INITIALLY DEFERRED foreign key constraints
-- that are NOT supported in Azure SQL Server (enforced immediately).
-- See: output/project1/CRITICAL_FIX_SCRIPTS.sql - BATCH5-SCRIPT 1
--
-- CONVERSION NOTES:
-- ├─ LIST partitioning by CHAIN_ID removed (10+ named partitions)
-- ├─ ⚠️ DEFERRABLE INITIALLY DEFERRED FK converted to immediate enforcement
-- ├─ Created nonclustered index on CHAIN_ID for partition elimination
-- ├─ Oracle storage parameters removed (PCTFREE, TABLESPACE, INITIAL/NEXT, etc.)
-- ├─ Data type mappings: NUMBER→BIGINT, VARCHAR2→VARCHAR
-- ├─ Mixed SEGMENT CREATION (DEFERRED/IMMEDIATE) removed
-- └─ Post-deployment: See BATCH5-SCRIPT 1 for FK validation and testing
--
-- PARTITIONING STRATEGY REMOVED:
--   Previous: LIST (CHAIN_ID) with 10 partitions: GEAGLE, ECOM, HANNAF, MEIJER, RXCOM, 
--            SHOPKO, STLUKE, FREDS, GUNDER, WEBSCR, DUMMY
--            with mixed SEGMENT CREATION and variable STORAGE clauses
--   Replacement: Nonclustered indexes for partition elimination
--
-- FOREIGN KEY ISSUE:
--   ├─ Oracle: IDGEN_FK_ESCHAIN DEFERRABLE INITIALLY DEFERRED
--   │   Allowed child records without parent at transaction start
--   │   Parent must exist before transaction COMMIT
--   └─ Azure SQL: FK enforced immediately
--       All FKs checked at INSERT time (no deferral possible)
--       Application code must verify parent exists BEFORE insert
--
-- IMPACT: INSERT statements into IDGEN must verify CHAIN_ID in SEC_ADMIN.EPS_SEC_CHAIN FIRST
-- =====================================================================

CREATE TABLE [EPS].[IDGEN] (
    [CHAIN_ID] BIGINT,
    [NAME] VARCHAR(100),
    [NEXT_ID] BIGINT,
    CONSTRAINT [FK_IDGEN_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
    -- NOTE: Oracle had DEFERRABLE INITIALLY DEFERRED - Azure SQL enforces immediately
);
GO

-- Create index for partition key column
CREATE NONCLUSTERED INDEX [IDX_IDGEN_CHAIN_ID] 
    ON [EPS].[IDGEN]([CHAIN_ID])
    INCLUDE ([NAME], [NEXT_ID])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression (ROW for small ID generation table)
ALTER TABLE [EPS].[IDGEN] 
    WITH (DATA_COMPRESSION = ROW);
GO

-- =====================================================================
-- CRITICAL FIX IMPLEMENTATION
-- =====================================================================
-- Execute script: output/project1/CRITICAL_FIX_SCRIPTS.sql - BATCH5-SCRIPT 1
--
-- Steps:
-- 1. Run FK violation detection queries (identify orphaned CHAIN_IDs)
-- 2. Run FK constraint status verification (confirm immediate enforcement)
-- 3. Run transaction test with parent record validation
-- 4. Update application code to verify CHAIN_ID before INSERT
--
-- Timeline: 1-2 hours for validation + application code updates
-- =====================================================================

-- Post-deployment actions:
-- 1. Execute BATCH5-SCRIPT 1 for comprehensive FK validation
-- 2. Identify all application code that inserts into IDGEN
-- 3. Add parent record validation before all INSERT statements:
--    BEGIN TRANSACTION
--    IF EXISTS (SELECT 1 FROM SEC_ADMIN.EPS_SEC_CHAIN WHERE ...)
--        INSERT INTO IDGEN ...
--    ELSE
--        ROLLBACK
--    COMMIT
-- 4. Test with production-like data volumes
-- 5. Monitor first month of transactions for FK constraint violations
-- 6. Update documentation on FK enforcement changes
