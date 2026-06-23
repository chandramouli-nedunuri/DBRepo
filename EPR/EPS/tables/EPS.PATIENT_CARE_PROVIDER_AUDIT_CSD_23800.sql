-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_CARE_PROVIDER_AUDIT_CSD_23800
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_CARE_PROVIDER_AUDIT_CSD_23800
-- Type: Composite Partitioned Audit Table (CSD Variant - Conflict-Sensitive Data)
-- Oracle Partitions: LIST by CHAIN_ID (~20+ different chains than standard)
-- Purpose: Audit trail for patient care provider assignments (CSD variant for data sync control)

-- NOTE: CSD_23800 suffix indicates CONFLICT-SENSITIVE DATA variant
-- This is a duplicate/parallel table containing SAME LOGICAL DATA as PATIENT_CARE_PROVIDER_AUDIT
-- but with different chain partition values (multi-tenant data segregation strategy)

CREATE TABLE [EPS].[PATIENT_CARE_PROVIDER_AUDIT_CSD_23800] (
    [CHAIN_ID] [int] NOT NULL,
    [ID] [int] NOT NULL,
    [ID_AAL] [int] NULL,
    [LAST_UPDATED] [datetime] NULL,
    [ID_PATIENT] [int] NOT NULL,
    [PHYSICIAN_LAST_NAME] [varchar](35) NULL,
    [PHYSICIAN_FIRST_NAME] [varchar](35) NULL,
    [PHYSICIAN_NPI] [varchar](10) NULL,
    [RN_CONTACT_LAST_NAME] [varchar](35) NULL,
    [RN_CONTACT_FIRST_NAME] [varchar](35) NULL,
    [RN_AREA_CODE] [varchar](3) NULL,
    [RN_PHONE_NUMBER] [varchar](7) NULL,
    [RN_EMAIL_ADDRESS] [varchar](120) NULL,
    [CLINIC_IDENTIFIER] [varchar](10) NULL,
    [CLINIC_FAX_AREA_CODE] [varchar](3) NULL,
    [CLINIC_FAX_PHONE_NUMBER] [varchar](7) NULL,
    [PRIMARY] [varchar](1) NULL,
    [ID_AUDIT] [int] NULL,
    [AUDIT_TIMESTAMP] [datetime2](6) NULL,
    [DELETED] [varchar](1) NULL,
    [PROVIDER_IDENTIFIER] [int] NULL,
    [DEA] [varchar](35) NULL,
    [STATE_IDENTIFIER] [varchar](15) NULL,
    [ADDRESS_LINE1] [varchar](255) NULL,
    [TYPE] [varchar](30) NULL
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Audit Timestamp Range (NOTE: Nullable AUDIT_TIMESTAMP for CSD variant)
CREATE NONCLUSTERED INDEX [IX_PATIENT_CARE_PROVIDER_AUDIT_CSD_TIMESTAMP] 
ON [EPS].[PATIENT_CARE_PROVIDER_AUDIT_CSD_23800] ([AUDIT_TIMESTAMP], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [PHYSICIAN_LAST_NAME], [PHYSICIAN_NPI])
WHERE [AUDIT_TIMESTAMP] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- DEA Provider Lookup (prescriber credentials)
CREATE NONCLUSTERED INDEX [IX_PATIENT_CARE_PROVIDER_AUDIT_CSD_DEA] 
ON [EPS].[PATIENT_CARE_PROVIDER_AUDIT_CSD_23800] ([DEA], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [PHYSICIAN_LAST_NAME], [NPI])
WHERE [DEA] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- PAGE compression for audit table
ALTER TABLE [EPS].[PATIENT_CARE_PROVIDER_AUDIT_CSD_23800] 
SET (COMPRESSION = PAGE);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[CSD_VARIANT_EXPLANATION] This table is a CONFLICT-SENSITIVE DATA (CSD) variant:
  
  CSD_23800 = Conflict-Sensitive Data variant #23800
  (23800 likely = issue tracking number OR configuration version)
  
  Purpose: Parallel data table for distributed/multi-tenant environments
  - Standard PATIENT_CARE_PROVIDER_AUDIT contains data for 13 main chains
  - CSD_23800 variant contains data for 20+ different/subset chains
  - Enables: Data isolation, legal hold, conflicts of interest management
  
  Example scenario in healthcare:
  - Company acquires competing pharmacy chain (conflict of interest)
  - Provider data segregated: separate tables (STANDARD vs. CSD_23800)
  - Prevents data leakage/conflict resolution compliance
  - Can be archived/deleted without affecting main healthcare database

[CSD_VARIANT_MIGRATION] Post-migration decision required:
  a) KEEP BOTH tables (maintain data separation, ~2x storage overhead)
  b) MERGE into standard table (consolidate, lose segregation)
  c) ARCHIVE CSD variant (compliance hold, move to cold storage)
  d) DELETE CSD variant (if retention period expired)
  
  Recommendation: Discuss with data steward + legal team before proceeding

[NOTABLE_DIFFERENCES_FROM_STANDARD]
  - AUDIT_TIMESTAMP nullable (vs. NOT NULL in main audit table)
  - Different chain partitions (suggesting separate customer base)
  - May have different data load schedule (asynchronous sync)
  - Potential data lag vs. primary chain data

[CLINICIAN_REFERENCE] Patient care provider master data:
  - Physician/prescriber (PHYSICIAN_LAST_NAME, PHYSICIAN_FIRST_NAME, PHYSICIAN_NPI)
  - RN coordinator (RN_CONTACT_, RN_AREA_CODE, RN_PHONE_NUMBER, RN_EMAIL_ADDRESS)
  - DEA credential (DEA, STATE_IDENTIFIER for license)
  - Clinic information (CLINIC_IDENTIFIER, FAX, ADDRESS)
  - PRIMARY flag: Identifies primary prescriber for patient
  
  Used for: Rx authorization, clinical coordination, compliance reporting (DEA, board of pharmacy)

[NPI_VALIDATION] National Provider Identifier (NPI):
  - 10-digit unique healthcare provider identifier (HIPAA requirement)
  - PHYSICIAN_NPI validates prescriber identity
  
  Validate during migration:
  SELECT DISTINCT [PHYSICIAN_NPI], COUNT(*)
  FROM [EPS].[PATIENT_CARE_PROVIDER_AUDIT_CSD_23800]
  WHERE [PHYSICIAN_NPI] IS NOT NULL
  GROUP BY [PHYSICIAN_NPI]
  ORDER BY COUNT(*) DESC;

[DEA_CREDENTIAL_TRACKING]
  [DEA]: DEA registration number (prescribing authority)
  [STATE_IDENTIFIER]: State pharmacy board license number
  Both critical for controlled substance authorization
  
  Compliance: Validate DEA expiration (if stored elsewhere), sync with DEA Diversion database

[SIZE_ESTIMATE] ~200-400 MB (depending on CSD chain count and volume)

[DATA_QUALITY_VALIDATION]
  ✓ NPI format: 10 numeric digits
  ✓ DEA format: State code + numbers (variable format)
  ✓ Phone numbers: Valid format (XXX) XXX-XXXX
  ✓ Email: Standard format validation
  ✓ PRIMARY flag: Only 1 per patient (logical constraint)

[RETENTION_REQUIREMENTS] Healthcare records:
  - Federal: 3-7 years (HIPAA minimum)
  - State: Varies (CA 7 years, TX 5 years, etc.)
  - DEA audits: 2+ years on prescriber credentials
  
  CSD variant may have different retention due to conflict sensitivity

[COMPLIANCE_CONSIDERATIONS]
  - State board of pharmacy licensing requirements
  - DEA controlled substance prescribing oversight
  - HIPAA provider credentials handling
  - Data governance for conflict segregation

[DATA_SYNC] If this is a mirrored/sync table:
  Monitor for data lag between standard and CSD_23800 tables
  Expect eventual consistency (delay is acceptable if documented)
  
  Post-migration: Implement sync validation/reconciliation job

[ORPHANED_RECORD_CHECK]
  SELECT COUNT(*) as [OrphanRecords]
  FROM [EPS].[PATIENT_CARE_PROVIDER_AUDIT_CSD_23800] PC
  LEFT JOIN [EPS].[PATIENT] P ON PC.[ID_PATIENT] = P.[ID]
  WHERE P.[ID] IS NULL;
*/
