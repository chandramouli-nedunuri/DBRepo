-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_CARE_PROVIDER
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_CARE_PROVIDER
-- Type: Master Transaction Table (Patient Clinician Assignment)
-- Oracle Partitions: LIST by CHAIN_ID (~20+ chains)
-- Purpose: Active patient care provider (prescriber/clinician) registry

CREATE TABLE [EPS].[PATIENT_CARE_PROVIDER] (
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
    [DELETED] [varchar](1) NULL,
    [PROVIDER_IDENTIFIER] [int] NULL,
    [DEA] [varchar](35) NULL,
    [STATE_IDENTIFIER] [varchar](15) NULL,
    [ADDRESS_LINE1] [varchar](255) NULL,
    [TYPE] [varchar](30) NULL,
    
    CONSTRAINT [PATIENT_CARE_PROVIDER_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Patient Provider Lookup (care team assignment)
CREATE NONCLUSTERED INDEX [IX_PATIENT_CARE_PROVIDER_PATIENT] 
ON [EPS].[PATIENT_CARE_PROVIDER] ([ID_PATIENT], [PRIMARY], [CHAIN_ID])
INCLUDE ([ID], [PHYSICIAN_LAST_NAME], [PHYSICIAN_NPI], [RN_CONTACT_LAST_NAME])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- NPI Lookup (provider credentialing)
CREATE NONCLUSTERED INDEX [IX_PATIENT_CARE_PROVIDER_NPI] 
ON [EPS].[PATIENT_CARE_PROVIDER] ([PHYSICIAN_NPI], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [PHYSICIAN_LAST_NAME], [PHYSICIAN_FIRST_NAME])
WHERE [PHYSICIAN_NPI] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- DEA Credential Lookup (controlled substance authorization)
CREATE NONCLUSTERED INDEX [IX_PATIENT_CARE_PROVIDER_DEA] 
ON [EPS].[PATIENT_CARE_PROVIDER] ([DEA], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [PHYSICIAN_LAST_NAME], [STATE_IDENTIFIER])
WHERE [DEA] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- ROW compression for provider registry
ALTER TABLE [EPS].[PATIENT_CARE_PROVIDER] 
SET (COMPRESSION = ROW);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[PRIMARY_KEY] Composite key: (CHAIN_ID, ID)
  Ensures one unique provider assignment per chain

[CARE_TEAM_STRUCTURE] Patient may have multiple care providers:
  - PRIMARY physician (PHYSICIAN_*)
  - RN coordinator (RN_CONTACT_*, clinical phone support)
  - Secondary providers (TYPE field distinguishes)
  
  PRIMARY flag identifies lead clinician for Rx authorizations

[CLINICIAN_IDENTIFIERS]
  [PHYSICIAN_NPI]: National Provider Identifier (HIPAA standard, 10-digit)
  [DEA]: DEA registration (prescribing authority for controlled substances)
  [STATE_IDENTIFIER]: State board of pharmacy license number
  [PROVIDER_IDENTIFIER]: Internal provider ID (EPS system)
  
  All critical for HIPAA compliance and controlled substance tracking

[RN_COORDINATOR_ROLE]
  Hospital/clinic nursing staff (not prescribing, but clinical support):
  - Phone contact for patient questions (RN_PHONE_NUMBER, RN_AREA_CODE)
  - Clinical coordination (RN_EMAIL_ADDRESS for care updates)
  - Name fields (RN_CONTACT_LAST_NAME, RN_CONTACT_FIRST_NAME)
  
  Example: Patient calls pharmacy, clinic RN coordinates refill pre-authorization

[CLINIC_INFORMATION]
  [CLINIC_IDENTIFIER]: Clinic/practice code
  [CLINIC_FAX_*]: Fax number for Rx authorization requests
  [ADDRESS_LINE1]: Prescriber practice address
  
  Used for: Rx routing, prior authorization faxing, compliance records

[PRIMARY_PROVIDER_QUERY]
  SELECT [ID_PATIENT], [PHYSICIAN_NPI], [PHYSICIAN_LAST_NAME], [PHYSICIAN_FIRST_NAME]
  FROM [EPS].[PATIENT_CARE_PROVIDER]
  WHERE [PRIMARY] = 'Y' AND [ID_PATIENT] = @patientID;
  
  Returns patient's lead prescriber for Rx authorization

[CONTROLLED_SUBSTANCE_COMPLIANCE]
  DEA registration required for all controlled substance prescriptions
  
  Validation: Ensure all prescribers have DEA before filling narcotics
  
  Pre-fill check:
  SELECT [ID_PATIENT], COUNT(*)
  FROM [EPS].[PATIENT_CARE_PROVIDER]
  WHERE [DEA] IS NULL AND [PRIMARY] = 'Y'  -- Missing DEA on primary
  GROUP BY [ID_PATIENT];

[PARTITIONING_REMOVED] Oracle LIST partitioning by CHAIN_ID removed
  Note: PATIENT_CARE_PROVIDER has ~20+ chains (more than standard 13)
  This indicates multi-customer base (acquired chains, special programs)

[SIZE_ESTIMATE] ~100-200 MB (provider registry relatively static, high read)

[DELETED_FLAG_SOFT_DELETE] DELETED = 'Y' indicates:
  - Provider no longer treats patient
  - Provider left practice/retired
  - Care relationship terminated
  
  Preserved in audit table, not removed from current table

[TYPE_FIELD_VALUES] (hypothesis):
  'PHYSICIAN', 'RN', 'NP' (Nurse Practitioner), 'PA' (Physician Assistant)
  
  Distinguish clinician types for workflow routing
  
  Validate:
  SELECT DISTINCT [TYPE], COUNT(*)
  FROM [EPS].[PATIENT_CARE_PROVIDER]
  GROUP BY [TYPE];

[DATA_QUALITY_VALIDATION]
  ✓ PRIMARY = 'Y' uniquely per patient (only one primary)
  ✓ NPI non-null for physicians
  ✓ DEA non-null for controlled substance prescribers
  ✓ Phone/Fax format validity
  ✓ Email format validity
  ✓ No orphaned patients (ID_PATIENT must exist in PATIENT table)

[CLINICAL_COORDINATION_WORKFLOW]
  1. Rx submitted by physician (use PHYSICIAN_NPI for validation)
  2. Pharmacy reviews DEA/State license expiration
  3. If questions, call RN coordinator (RN_PHONE_NUMBER)
  4. If prior auth needed, fax clinic (CLINIC_FAX_*)
  5. Update audit on every care team change

[MULTI-CHAIN_PARTITIONS] ~20+ chains expected:
  Larger partition set than standard 13-chain base
  Suggests recent acquisition or special programs
  Requires investigation: Consolidation strategy post-migration?

[SYNC_WITH_AUDIT]
  Verify audit table contains complete history:
  SELECT MAX([AUDIT_TIMESTAMP])
  FROM [EPS].[PATIENT_CARE_PROVIDER_AUDIT]
  WHERE [ID_PATIENT] = @patientID;
  
  Confirms all provider changes tracked for compliance
*/
