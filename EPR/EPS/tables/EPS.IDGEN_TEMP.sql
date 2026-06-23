-- =====================================================================
-- TABLE: EPS.IDGEN_TEMP
-- =====================================================================
-- Conversion: Oracle → Azure SQL Server
-- Source: EPS.IDGEN_TEMP.sql (12 lines)
-- 
-- CONVERSION NOTES:
-- ├─ Simple temporary working table for ID generation
-- ├─ SEGMENT CREATION DEFERRED removed (Oracle-specific)
-- ├─ Oracle storage parameters removed (PCTFREE, TABLESPACE, etc.)
-- ├─ Data type mappings: NUMBER→BIGINT, VARCHAR2→VARCHAR
-- ├─ Minimal structure: 3 columns (CHAIN_ID, NAME, NEXT_ID)
-- └─ SUPPLEMENTAL LOG DATA clause removed (Oracle-specific)
--
-- STRUCTURE NOTES:
--   Purpose: Temporary/working table for ID sequence generation
--   Columns: CHAIN_ID (chain identifier), NAME (sequence name), NEXT_ID (next value)
--   Flexibility: Structure allows for per-chain, per-sequence ID management
--
-- DESIGN DECISIONS:
--   ├─ No primary key defined (allows flexible session-scoped use)
--   ├─ No constraints (temporary table, manual cleanup expected)
--   └─ No NOT NULL enforcements (values can be sparse)
-- =====================================================================

CREATE TABLE [EPS].[IDGEN_TEMP] (
    [CHAIN_ID] BIGINT,
    [NAME] VARCHAR(100),
    [NEXT_ID] BIGINT
);
GO

-- Post-deployment actions:
-- 1. Clarify usage: Is this session-scoped or permanent staging table?
-- 2. If session-scoped: Convert to #IDGEN_TEMP (temp table) with TRUNCATE after use
-- 3. If permanent: Add primary key constraint: PK ([CHAIN_ID], [NAME])
-- 4. Review cleanup strategy: Manual truncate, scheduled archival, or auto-expire?
-- 5. Monitor growth - implement retention policy if used for audit trail
-- 6. Validate [NEXT_ID] sequence logic in application code
-- 7. Create index on [CHAIN_ID], [NAME] if frequent lookups occur
