-- EPS.MEDICAL_CONDITION_AUDIT.sql
-- Oracle EPS Database Schema Conversion to Azure SQL Server 2019+
-- Table: EPS.MEDICAL_CONDITION_AUDIT
-- Source Lines: 3282 | Columns: 14 | Type: Composite Partitioned Clinical Audit
-- Conversion Date: 2024 | Status: ✓ CONVERTED
--
-- CONVERSION NOTES:
-- 1. Composite LIST+RANGE partitioning removed (4 chains: GEAGLE, ECOM, HANNAF, MEIJER)
--    with monthly AUDIT_TIMESTAMP subpartitions (2026-04/05/06)
-- 2. Created nonclustered indexes on CHAIN_ID, AUDIT_TIMESTAMP, ICD10
-- 3. NUMBER(7,0) → BIGINT for MEDICAL_CONDITION_CODE
-- 4. Clinical date tracking: LAST (condition valid from), STOP (condition ended)
-- 5. TABLESPACE mappings removed (EPS_D → default filegroup)
-- 6. Compression applied (PAGE for clinical audit data)
-- 7. No FK constraints present
-- 8. DELETED flag indicates logical deletion - consider soft-delete patterns
-- 9. Post-migration: Implement monthly RANGE partitioning by AUDIT_TIMESTAMP, archival > 24 months
-- ============================================================================

CREATE TABLE [EPS].[MEDICAL_CONDITION_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [NHIN_ID] BIGINT,
    [LAST_UPDATED] DATETIME2(6),
    [MEDICAL_CONDITION_CODE] BIGINT,
    [ICD10] VARCHAR(15),
    [LAST] DATETIME2(6),
    [STOP] DATETIME2(6),
    [DELETED] VARCHAR(1),
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    [ID_AAL] BIGINT,
    [DURATION] VARCHAR(1)
);
GO

-- Create indexes for clinical queries and audit retrieval
CREATE NONCLUSTERED INDEX [IDX_MEDICAL_CONDITION_AUDIT_CHAIN_ID]
    ON [EPS].[MEDICAL_CONDITION_AUDIT]([CHAIN_ID])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_MEDICAL_CONDITION_AUDIT_TIMESTAMP]
    ON [EPS].[MEDICAL_CONDITION_AUDIT]([AUDIT_TIMESTAMP])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_MEDICAL_CONDITION_AUDIT_ICD10]
    ON [EPS].[MEDICAL_CONDITION_AUDIT]([ICD10])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_MEDICAL_CONDITION_AUDIT_PATIENT_ID]
    ON [EPS].[MEDICAL_CONDITION_AUDIT]([ID_PATIENT])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression for space efficiency
ALTER TABLE [EPS].[MEDICAL_CONDITION_AUDIT]
    WITH (DATA_COMPRESSION = PAGE);
GO

-- Post-deployment actions:
-- 1. Verify clinical data: SELECT COUNT(*) FROM [EPS].[MEDICAL_CONDITION_AUDIT];
-- 2. Validate ICD10 codes: SELECT DISTINCT [ICD10] FROM [EPS].[MEDICAL_CONDITION_AUDIT] WHERE [ICD10] IS NOT NULL;
-- 3. Check deletion patterns: SELECT [DELETED], COUNT(*) FROM [EPS].[MEDICAL_CONDITION_AUDIT] GROUP BY [DELETED];
-- 4. Implement monthly RANGE partitioning by AUDIT_TIMESTAMP (SCD Type 2 audit pattern)
-- 5. Archive records > 24 months to compliance archive
-- 6. Validate DURATION values: SELECT DISTINCT [DURATION] FROM [EPS].[MEDICAL_CONDITION_AUDIT];
-- 7. Create view for current active conditions: WHERE [DELETED] IS NULL OR [DELETED] = 'N'
-- 8. PHI data: Ensure row-level security (RLS) policies in place
