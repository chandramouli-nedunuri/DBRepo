-- EPS.PATIENT_CARE_PROVIDER_AUDIT.sql
-- Oracle EPS Database Schema Conversion to Azure SQL Server 2019+
-- Table: EPS.PATIENT_CARE_PROVIDER_AUDIT
-- Source Lines: 3293 | Columns: 25 | Type: Composite Partitioned Provider Contact Audit
-- Conversion Date: 2024 | Status: ✓ CONVERTED
--
-- CONVERSION NOTES:
-- 1. Composite LIST+RANGE partitioning removed (4 chains: GEAGLE, ECOM, HANNAF, etc.)
--    with monthly AUDIT_TIMESTAMP subpartitions (2026-04/05/06)
-- 2. Created nonclustered indexes on CHAIN_ID, AUDIT_TIMESTAMP, ID_PATIENT
-- 3. Physician/RN contact tracking - separate care providers (multi-specialty support)
-- 4. RN (Registered Nurse) contact information with phone/email/area code separate fields
-- 5. Clinic information: Identifier, FAX, address line tracking
-- 6. Provider identifiers: NPI (National Provider ID), DEA, STATE_IDENTIFIER
-- 7. TYPE field: Indicates provider role (e.g., PHYSICIAN, RN, CLINIC)
-- 8. PRIMARY flag: Indicates primary care provider for patient at chain
-- 9. DELETED flag: Logical delete (soft delete pattern)
-- 10. Compression applied (PAGE for large audit table)
-- 11. Post-migration: Implement monthly RANGE partitioning by AUDIT_TIMESTAMP
-- ============================================================================

CREATE TABLE [EPS].[PATIENT_CARE_PROVIDER_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_AAL] BIGINT,
    [LAST_UPDATED] DATETIME,
    [ID_PATIENT] BIGINT NOT NULL,
    [PHYSICIAN_LAST_NAME] VARCHAR(35),
    [PHYSICIAN_FIRST_NAME] VARCHAR(35),
    [PHYSICIAN_NPI] VARCHAR(10),
    [RN_CONTACT_LAST_NAME] VARCHAR(35),
    [RN_CONTACT_FIRST_NAME] VARCHAR(35),
    [RN_AREA_CODE] VARCHAR(3),
    [RN_PHONE_NUMBER] VARCHAR(7),
    [RN_EMAIL_ADDRESS] VARCHAR(120),
    [CLINIC_IDENTIFIER] VARCHAR(10),
    [CLINIC_FAX_AREA_CODE] VARCHAR(3),
    [CLINIC_FAX_PHONE_NUMBER] VARCHAR(7),
    [PRIMARY] VARCHAR(1),
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    [DELETED] VARCHAR(1),
    [PROVIDER_IDENTIFIER] BIGINT,
    [DEA] VARCHAR(35),
    [STATE_IDENTIFIER] VARCHAR(15),
    [ADDRESS_LINE1] VARCHAR(255),
    [TYPE] VARCHAR(30)
);
GO

-- Create indexes for provider audit queries
CREATE NONCLUSTERED INDEX [IDX_PATIENT_CARE_PROVIDER_AUDIT_CHAIN_ID]
    ON [EPS].[PATIENT_CARE_PROVIDER_AUDIT]([CHAIN_ID])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_PATIENT_CARE_PROVIDER_AUDIT_TIMESTAMP]
    ON [EPS].[PATIENT_CARE_PROVIDER_AUDIT]([AUDIT_TIMESTAMP])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_PATIENT_CARE_PROVIDER_AUDIT_PATIENT_ID]
    ON [EPS].[PATIENT_CARE_PROVIDER_AUDIT]([ID_PATIENT])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_PATIENT_CARE_PROVIDER_AUDIT_NPI]
    ON [EPS].[PATIENT_CARE_PROVIDER_AUDIT]([PHYSICIAN_NPI])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_PATIENT_CARE_PROVIDER_AUDIT_TYPE]
    ON [EPS].[PATIENT_CARE_PROVIDER_AUDIT]([TYPE])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression
ALTER TABLE [EPS].[PATIENT_CARE_PROVIDER_AUDIT]
    WITH (DATA_COMPRESSION = PAGE);
GO

-- Post-deployment actions:
-- 1. Verify audit records: SELECT COUNT(*) FROM [EPS].[PATIENT_CARE_PROVIDER_AUDIT];
-- 2. Analyze provider types: SELECT [TYPE], COUNT(*) FROM [EPS].[PATIENT_CARE_PROVIDER_AUDIT] GROUP BY [TYPE];
-- 3. Check primary provider distribution: SELECT [PRIMARY], COUNT(*) FROM [EPS].[PATIENT_CARE_PROVIDER_AUDIT] GROUP BY [PRIMARY];
-- 4. Validate NPI format: SELECT DISTINCT [PHYSICIAN_NPI] FROM [EPS].[PATIENT_CARE_PROVIDER_AUDIT] WHERE [PHYSICIAN_NPI] IS NOT NULL;
--    Expected: 10-digit numeric or null
-- 5. Validate DEA numbers: SELECT COUNT(*) FROM [EPS].[PATIENT_CARE_PROVIDER_AUDIT] WHERE [DEA] IS NOT NULL;
-- 6. Check contact information quality:
--    - SELECT COUNT(*) FROM [EPS].[PATIENT_CARE_PROVIDER_AUDIT] WHERE [RN_EMAIL_ADDRESS] LIKE '%@%';
--    - SELECT COUNT(*) FROM [EPS].[PATIENT_CARE_PROVIDER_AUDIT] WHERE [RN_PHONE_NUMBER] IS NOT NULL;
-- 7. Implement monthly RANGE partitioning by AUDIT_TIMESTAMP (SCD Type 2)
-- 8. Archive records > 24 months to compliance archive
-- 9. Create view for current active providers: WHERE [DELETED] IS NULL OR [DELETED] = 'N'
-- 10. PHI data: Ensure encryption and row-level security (RLS) for provider contact info
-- 11. Data quality on phone numbers: Validate (RN_AREA_CODE, RN_PHONE_NUMBER) as composite key
