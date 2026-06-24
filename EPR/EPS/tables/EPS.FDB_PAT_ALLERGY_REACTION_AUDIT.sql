-- =====================================================================
-- TABLE: EPS.FDB_PAT_ALLERGY_REACTION_AUDIT
-- =====================================================================
-- Conversion: Oracle → Azure SQL Server
-- Source: EPS.FDB_PAT_ALLERGY_REACTION_AUDIT.sql (3,278 lines)
-- 
-- CONVERSION NOTES:
-- ├─ Composite partitioning removed (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP)
-- ├─ Created indexes on CHAIN_ID and AUDIT_TIMESTAMP for query optimization
-- ├─ Oracle storage parameters removed (PCTFREE, TABLESPACE, etc.)
-- ├─ Data type mappings: NUMBER(22,0)→BIGINT, TIMESTAMP(6)→DATETIME2(6)
-- ├─ SUPPLEMENTAL LOG DATA clause removed (Oracle-specific)
-- └─ Post-deployment: Consider RANGE partitioning by AUDIT_TIMESTAMP for audit log performance
--
-- PARTITIONING STRATEGY REMOVED:
--   Previous: LIST (CHAIN_ID) with 4 partitions (GEAGLE, ECOM, HANNAF, MEIJER)
--            SUBPARTITION by RANGE (AUDIT_TIMESTAMP) - monthly boundaries
--   Replacement: Nonclustered indexes on (CHAIN_ID, AUDIT_TIMESTAMP)
--   Note: Monthly partitioning by AUDIT_TIMESTAMP recommended post-migration
-- =====================================================================

CREATE TABLE [EPS].[FDB_PAT_ALLERGY_REACTION_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [FDB_ALLERGY_ID] BIGINT NOT NULL,
    [REACTION_DESCRIPTION] VARCHAR(255) NOT NULL,
    [LAST_UPDATED] DATETIME,
    [DELETED] VARCHAR(1),
    [ID_AAL] BIGINT,
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [PK_FDB_PAT_ALLERGY_REACTION_AUDIT] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP])
);
GO

-- Create indexes for partition key columns and audit timestamp for separation of concerns
CREATE NONCLUSTERED INDEX [IDX_FDB_PAT_ALLERGY_REACTION_AUDIT_CHAIN_ID] 
    ON [EPS].[FDB_PAT_ALLERGY_REACTION_AUDIT]([CHAIN_ID])
    INCLUDE ([ID], [FDB_ALLERGY_ID])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_FDB_PAT_ALLERGY_REACTION_AUDIT_TIMESTAMP] 
    ON [EPS].[FDB_PAT_ALLERGY_REACTION_AUDIT]([AUDIT_TIMESTAMP])
    INCLUDE ([CHAIN_ID], [ID])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression (PAGE for audit tables with high volume)
ALTER TABLE [EPS].[FDB_PAT_ALLERGY_REACTION_AUDIT] 
    WITH (DATA_COMPRESSION = PAGE);
GO

-- Post-deployment actions:
-- 1. Consider RANGE partitioning by AUDIT_TIMESTAMP with monthly boundaries
-- 2. Establish retention policy (e.g., 24-month rolling window)
-- 3. Archive expired partitions to cold storage
-- 4. Monitor query performance - compare against Oracle source
-- 5. Validate AUDIT_TIMESTAMP distribution for even partition loading
