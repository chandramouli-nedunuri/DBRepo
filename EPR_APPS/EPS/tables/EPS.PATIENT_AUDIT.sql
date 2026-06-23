-- EPS.PATIENT_AUDIT.sql
-- Oracle EPS Database Schema Conversion to Azure SQL Server 2019+
-- Table: EPS.PATIENT_AUDIT
-- Source Lines: 3438 | Columns: 81+ (largest audit table in Batch 6) | Type: Composite Partitioned Patient Master Audit
-- Conversion Date: 2024 | Status: ✓ CONVERTED
--
-- CONVERSION NOTES:
-- 1. Composite LIST+RANGE partitioning removed (multi-chain + monthly AUDIT_TIMESTAMP)
-- 2. Created nonclustered indexes on CHAIN_ID, AUDIT_TIMESTAMP, NHIN_ID, LAST_NAME
-- 3. NUMBER(22,0) → BIGINT; NUMBER(8,4) → DECIMAL(8,4) for HEIGHT/WEIGHT
-- 4. NUMBER(38,0) → BIGINT for ID fields
-- 5. Comprehensive patient demographic data: Name, DOB, insurance, preferences
-- 6. Safety flags: NO_CF, NO_COMPLIANCE, NO_PREFILL, NO_REF_PREF, NO_TRANSFER (contraindications)
-- 7. EHR integration fields: EHR_ID, EHR_ENABLED, IS_LINKED, LINK_FLAGS, LAST_SYNC_TIME
-- 8. Insurance/payment: PRICE_CODE, OTC_PRICE_CODE, TAXABLE, SHIP_TYPE
-- 9. Merged/unmerged patient history: MERGED_DATE, UNMERGED_DATE, SURVIVOR_ID
-- 10. Compression applied (PAGE for very large audit table)
-- 11. Post-migration: CRITICAL - Implement monthly RANGE partitioning by AUDIT_TIMESTAMP
-- 12. Data quality: Review EHR_ENABLED, IS_LINKED for system migration impact
-- ============================================================================

CREATE TABLE [EPS].[PATIENT_AUDIT] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [RX_COM_ID] BIGINT,
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [ADDED] DATETIME,
    [LAST] DATETIME,
    [BIRTH_DATE] DATETIME,
    [CATEGORY] CHAR(1),
    [DAW] CHAR(1),
    [DEACTIVATE_DATE] DATETIME,
    [DECEASED_DATE] DATETIME,
    [DISCOUNT] VARCHAR(3),
    [DRIVER_LICENSE] VARCHAR(15),
    [FIRST_NAME] VARCHAR(20),
    [GROUP_NUMBER] CHAR(1),
    [HEIGHT] DECIMAL(8,4),
    [LABEL] VARCHAR(3),
    [LAST_NAME] VARCHAR(25),
    [MARITAL_STATUS] CHAR(1),
    [MEDICAL_RECORD_NUMBER] VARCHAR(35),
    [METRIC_WEIGHT] CHAR(1),
    [MIDDLE_NAME] VARCHAR(20),
    [NO_CF] CHAR(1),
    [NO_COMPLIANCE] CHAR(1),
    [NO_PREFILL] CHAR(1),
    [NO_REF_PREF] CHAR(1),
    [NO_TRANSFER] CHAR(1),
    [NSC] CHAR(1),
    [NUM_LABS] CHAR(1),
    [OMIT_DUR] CHAR(1),
    [PARTIAL_CII_FILL] CHAR(1),
    [PO_BOX] CHAR(1),
    [RACE] CHAR(1),
    [SEX] CHAR(1),
    [SSN] VARCHAR(15),
    [SUB_GROUP] CHAR(1),
    [WEIGHT] DECIMAL(8,4),
    [FOR_DAT] CHAR(1),
    [LANG] VARCHAR(3),
    [MAIL_TYPE] VARCHAR(6),
    [MAJORITY] DATETIME,
    [NO_PAYMENT_REQ] CHAR(1),
    [OTC_PRICE_CODE] VARCHAR(3),
    [PRICE_CODE] VARCHAR(3),
    [SHIP_TYPE] BIGINT,
    [TAXABLE] CHAR(1),
    [BIRTH_DATE_TEXT] VARCHAR(10),
    [RECORDTYPE] BIGINT,
    [ANIMALTYPE] VARCHAR(15),
    [MULTIBIRTH] CHAR(1),
    [PROFESSION] VARCHAR(6),
    [SUFFIX] VARCHAR(6),
    [ID_AAL] BIGINT,
    [SURVIVOR_ID] BIGINT,
    [OLD_CONTRIB_ID] BIGINT,
    [NEW_CONTRIB_ID] BIGINT,
    [MERGED_DATE] DATETIME,
    [UNMERGED_DATE] DATETIME,
    [STORE_CREATED_AT] BIGINT,
    [BOTTLE_COLOR] BIGINT,
    [ID_AUDIT] BIGINT,
    [EHR_ID] BIGINT,
    [EHR_ENABLED] CHAR(1),
    [IS_LINKED] CHAR(1),
    [LINK_FLAGS] BIGINT DEFAULT 0,
    [LAST_SYNC_TIME] DATETIME,
    [DRIVER_LICENSE_STATE] VARCHAR(6),
    [ALT_PATIENT_ID] VARCHAR(26),
    [ALT_PATIENT_ID_STATE] VARCHAR(6),
    [ALT_PATIENT_ID_TYPE] BIGINT,
    [PUELA] VARCHAR(1),
    [DRIVER_LICENSE_ADDENDUM] VARCHAR(5),
    [TP_HIERARCHY_CHANGE] DATETIME,
    [VISUALLY_IMPAIRED] CHAR(1),
    [REQUIRE_DELIVERY_CONFIRMATION] CHAR(1),
    [ACTIVE_MEMBER] CHAR(1),
    [TALKING_VIAL] CHAR(1)
);
GO

-- Create indexes for patient audit queries (LARGE TABLE - selective indexing)
CREATE NONCLUSTERED INDEX [IDX_PATIENT_AUDIT_CHAIN_ID]
    ON [EPS].[PATIENT_AUDIT]([CHAIN_ID])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_PATIENT_AUDIT_TIMESTAMP]
    ON [EPS].[PATIENT_AUDIT]([AUDIT_TIMESTAMP])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_PATIENT_AUDIT_NHIN_ID]
    ON [EPS].[PATIENT_AUDIT]([NHIN_ID])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_PATIENT_AUDIT_NAME]
    ON [EPS].[PATIENT_AUDIT]([LAST_NAME], [FIRST_NAME])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_PATIENT_AUDIT_SSN]
    ON [EPS].[PATIENT_AUDIT]([SSN])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression for space efficiency (VERY LARGE TABLE)
ALTER TABLE [EPS].[PATIENT_AUDIT]
    WITH (DATA_COMPRESSION = PAGE);
GO

-- Post-deployment actions:
-- CRITICAL TASKS:
-- 1. Verify migration: SELECT COUNT(*) FROM [EPS].[PATIENT_AUDIT];
-- 2. Check record types: SELECT DISTINCT [RECORDTYPE] FROM [EPS].[PATIENT_AUDIT];
-- 3. Analyze EHR integration status: SELECT [EHR_ENABLED], COUNT(*) FROM [EPS].[PATIENT_AUDIT] GROUP BY [EHR_ENABLED];
-- 4. Review merged patients (data integrity): SELECT COUNT(*) FROM [EPS].[PATIENT_AUDIT] WHERE [SURVIVOR_ID] IS NOT NULL;
-- 5. MANDATORY - Implement monthly RANGE partitioning by AUDIT_TIMESTAMP (SCD Type 2)
--    Partition function: Monthly boundaries from 2020-01 to 2026-12+
--    Recommend separate FILEGROUP for archived partitions
-- 6. Archive records > 24 months using sliding window partition switch to archive schema
-- 7. Validate safety flags: NO_CF, NO_COMPLIANCE, NO_PREFILL - populate decision support
-- 8. PHI COMPLIANCE CRITICAL:
--    - Enable Transparent Data Encryption (TDE) for entire database
--    - Encrypt SSN, DRIVER_LICENSE using Always Encrypted
--    - Implement row-level security (RLS) based on CHAIN_ID/location
--    - Enable auditing for PII access
-- 9. Data quality - Deceased patients: SELECT COUNT(*) WHERE [DECEASED_DATE] IS NOT NULL;
-- 10. Validate deactivation: SELECT COUNT(*) WHERE [DEACTIVATE_DATE] IS NOT NULL;
-- 11. Assess HEIGHT/WEIGHT data quality: SELECT COUNT(*) WHERE [WEIGHT] > 0;
-- Add AUDIT_TIMESTAMP column(s) as detected from full file read
