-- =====================================================================
-- TABLE: EPS.FDB_PATIENT_ALLERGY_AUDIT
-- =====================================================================
-- Conversion: Oracle → Azure SQL Server
-- Source: EPS.FDB_PATIENT_ALLERGY_AUDIT.sql (3,286 lines)
-- 
-- CONVERSION NOTES:
-- ├─ Composite partitioning removed (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP)
-- ├─ Created indexes on CHAIN_ID, AUDIT_TIMESTAMP, and patient/allergy lookups
-- ├─ Oracle storage parameters removed (PCTFREE, TABLESPACE, etc.)
-- ├─ Data type mappings: NUMBER(22,0)→BIGINT, TIMESTAMP(6)→DATETIME2(6), NUMBER(10,0)→INT
-- ├─ SUPPLEMENTAL LOG DATA clause removed (Oracle-specific)
-- └─ Post-deployment: Consider RANGE partitioning by AUDIT_TIMESTAMP for 24-month rolling window
--
-- PARTITIONING STRATEGY REMOVED:
--   Previous: LIST (CHAIN_ID) with 4 partitions (GEAGLE, ECOM, HANNAF, MEIJER)
--            SUBPARTITION by RANGE (AUDIT_TIMESTAMP) - monthly boundaries
--   Replacement: Nonclustered indexes on partition keys for query optimization
--   Note: Monthly archival policy recommended for audit data > 24 months
-- =====================================================================

CREATE TABLE [EPS].[FDB_PATIENT_ALLERGY_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [ALLERGY_TYPE] VARCHAR(20) NOT NULL,
    [ALLERGY_IDENTIFIER] INT NOT NULL,
    [SEVERITY] VARCHAR(255),
    [ALLERGY_CLASSIFICATION] VARCHAR(255),
    [ALLERGY_COMMENT] VARCHAR(300),
    [NHIN_ID] BIGINT,
    [ID_AAL] BIGINT,
    [LAST_UPDATED] DATETIME,
    [DELETED] VARCHAR(1),
    [ADDED_BY] VARCHAR(255),
    [ID_AUDIT] BIGINT,
    [ALLERGEN_DESCRIPTION] VARCHAR(255),
    [ADD_DATE] DATETIME2(6),
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [PK_FDB_PATIENT_ALLERGY_AUDIT] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP])
);
GO

-- Create indexes for partition keys and common query patterns
CREATE NONCLUSTERED INDEX [IDX_FDB_PATIENT_ALLERGY_AUDIT_CHAIN_ID] 
    ON [EPS].[FDB_PATIENT_ALLERGY_AUDIT]([CHAIN_ID])
    INCLUDE ([ID_PATIENT], [AUDIT_TIMESTAMP])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_FDB_PATIENT_ALLERGY_AUDIT_PATIENT] 
    ON [EPS].[FDB_PATIENT_ALLERGY_AUDIT]([ID_PATIENT], [CHAIN_ID])
    INCLUDE ([ALLERGY_TYPE], [SEVERITY])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_FDB_PATIENT_ALLERGY_AUDIT_TIMESTAMP] 
    ON [EPS].[FDB_PATIENT_ALLERGY_AUDIT]([AUDIT_TIMESTAMP])
    INCLUDE ([CHAIN_ID], [ID_PATIENT])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression (PAGE for large audit tables)
ALTER TABLE [EPS].[FDB_PATIENT_ALLERGY_AUDIT] 
    WITH (DATA_COMPRESSION = PAGE);
GO

-- Post-deployment actions:
-- 1. Establish RANGE partitioning by AUDIT_TIMESTAMP (monthly boundaries)
-- 2. Create archival jobs to move 24+ month old partitions to cold storage
-- 3. Monitor [ID_PATIENT] query performance for patient allergy lookups
-- 4. Validate index usage via sys.dm_db_index_usage_stats
-- 5. Consider indexed view for common aggregations (allergy summary by patient)
