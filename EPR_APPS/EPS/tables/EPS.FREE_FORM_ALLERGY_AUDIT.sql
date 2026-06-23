-- =====================================================================
-- TABLE: EPS.FREE_FORM_ALLERGY_AUDIT
-- =====================================================================
-- Conversion: Oracle → Azure SQL Server
-- Source: EPS.FREE_FORM_ALLERGY_AUDIT.sql (3,284 lines)
-- 
-- CONVERSION NOTES:
-- ├─ Composite partitioning removed (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP)
-- ├─ Created indexes on CHAIN_ID, AUDIT_TIMESTAMP, and ID_PATIENT
-- ├─ Oracle storage parameters removed (PCTFREE, TABLESPACE, etc.)
-- ├─ Data type mappings: NUMBER→BIGINT, TIMESTAMP(6)→DATETIME2(6), VARCHAR2→VARCHAR
-- ├─ SUPPLEMENTAL LOG DATA clause removed (Oracle-specific)
-- └─ Post-deployment: Implement RANGE partitioning by AUDIT_TIMESTAMP
--
-- PARTITIONING STRATEGY REMOVED:
--   Previous: LIST (CHAIN_ID) with 4 partitions (GEAGLE, ECOM, HANNAF, MEIJER)
--            SUBPARTITION by RANGE (AUDIT_TIMESTAMP) - monthly boundaries
--   Replacement: Nonclustered indexes on (CHAIN_ID), (AUDIT_TIMESTAMP), (ID_PATIENT)
--   Note: Free-form text allergies are high-cardinality - audit history critical
-- =====================================================================

CREATE TABLE [EPS].[FREE_FORM_ALLERGY_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [DESCRIPTION] VARCHAR(255) NOT NULL,
    [SEVERITY] VARCHAR(255),
    [ALLERGY_CLASSIFICATION] VARCHAR(255),
    [ALLERGY_COMMENT] VARCHAR(300),
    [ADDED_BY] VARCHAR(255),
    [NHIN_ID] BIGINT,
    [ID_AAL] BIGINT,
    [LAST_UPDATED] DATETIME,
    [DELETED] VARCHAR(1),
    [ID_AUDIT] BIGINT,
    [ADD_DATE] DATETIME2(6),
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [PK_FREE_FORM_ALLERGY_AUDIT] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP])
);
GO

-- Create indexes for partition keys and patient lookup
CREATE NONCLUSTERED INDEX [IDX_FREE_FORM_ALLERGY_AUDIT_CHAIN_ID] 
    ON [EPS].[FREE_FORM_ALLERGY_AUDIT]([CHAIN_ID])
    INCLUDE ([ID_PATIENT], [AUDIT_TIMESTAMP])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_FREE_FORM_ALLERGY_AUDIT_PATIENT] 
    ON [EPS].[FREE_FORM_ALLERGY_AUDIT]([ID_PATIENT], [CHAIN_ID])
    INCLUDE ([DESCRIPTION], [SEVERITY], [AUDIT_TIMESTAMP])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_FREE_FORM_ALLERGY_AUDIT_TIMESTAMP] 
    ON [EPS].[FREE_FORM_ALLERGY_AUDIT]([AUDIT_TIMESTAMP])
    INCLUDE ([CHAIN_ID], [ID_PATIENT])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression (PAGE for text-heavy audit tables)
ALTER TABLE [EPS].[FREE_FORM_ALLERGY_AUDIT] 
    WITH (DATA_COMPRESSION = PAGE);
GO

-- Post-deployment actions:
-- 1. Create RANGE partition function by AUDIT_TIMESTAMP (monthly boundaries)
-- 2. Establish full-text search on [DESCRIPTION] for allergy text matching
-- 3. Monitor [DESCRIPTION] varchar(255) truncation issues during migration
-- 4. Validate patient allergy audit trail completeness (all changes captured)
-- 5. Create archival jobs for 24+ month old audit partitions
-- 6. Implement change audit triggers if not already captured via ID_AUDIT
