-- EPS.MATCH_KEY_AUDIT.sql
-- Oracle EPS Database Schema Conversion to Azure SQL Server 2019+
-- Table: EPS.MATCH_KEY_AUDIT
-- Source Lines: 3278 | Columns: 9 | Type: Composite Partitioned Audit
-- Conversion Date: 2024 | Status: ✓ CONVERTED
--
-- CONVERSION NOTES:
-- 1. Composite LIST+RANGE partitioning removed (4 chains: GEAGLE, ECOM, HANNAF, MEIJER)
--    with monthly AUDIT_TIMESTAMP subpartitions (2026-04/05/06)
-- 2. Created nonclustered indexes on CHAIN_ID, AUDIT_TIMESTAMP, MATCH_TYPE
-- 3. SUPPLEMENTAL LOG DATA clause removed (not applicable)
-- 4. Compression applied (PAGE for large audit)
-- 5. No FK constraints present
-- 6. MATCH_TYPE and MATCH_VALUE appear to be fingerprint/key data - validate semantics
-- 7. Post-migration: Implement monthly RANGE partitioning by AUDIT_TIMESTAMP
-- ============================================================================

CREATE TABLE [EPS].[MATCH_KEY_AUDIT] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [MATCH_TYPE] BIGINT,
    [MATCH_VALUE] VARCHAR(16),
    [ID_PATIENT] BIGINT,
    [ID_AAL] BIGINT,
    [LAST_UPDATED] DATETIME,
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);
GO

-- Create indexes for audit queries
CREATE NONCLUSTERED INDEX [IDX_MATCH_KEY_AUDIT_CHAIN_ID]
    ON [EPS].[MATCH_KEY_AUDIT]([CHAIN_ID])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_MATCH_KEY_AUDIT_TIMESTAMP]
    ON [EPS].[MATCH_KEY_AUDIT]([AUDIT_TIMESTAMP])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_MATCH_KEY_AUDIT_MATCH_TYPE]
    ON [EPS].[MATCH_KEY_AUDIT]([MATCH_TYPE], [MATCH_VALUE])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_MATCH_KEY_AUDIT_PATIENT_ID]
    ON [EPS].[MATCH_KEY_AUDIT]([ID_PATIENT])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression
ALTER TABLE [EPS].[MATCH_KEY_AUDIT]
    WITH (DATA_COMPRESSION = PAGE);
GO

-- Post-deployment actions:
-- 1. Verify row count: SELECT COUNT(*) FROM [EPS].[MATCH_KEY_AUDIT];
-- 2. Analyze MATCH_TYPE values: SELECT DISTINCT [MATCH_TYPE] FROM [EPS].[MATCH_KEY_AUDIT];
-- 3. Implement monthly RANGE partitioning by AUDIT_TIMESTAMP
-- 4. Archive records > 24 months using sliding window approach
-- 5. Validate MATCH_VALUE format consistency (max length 16)
-- 6. Consider clustered index on (CHAIN_ID, ID_PATIENT, AUDIT_TIMESTAMP)
