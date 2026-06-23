-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_NOTES_AUDIT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_NOTES_AUDIT
-- Type: Composite Partitioned Audit Table (Clinical Notes)
-- Oracle Partitions: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
-- Purpose: Audit trail for patient pharmacy notes (clinical documentation)

CREATE TABLE [EPS].[PATIENT_NOTES_AUDIT] (
    [CHAIN_ID] [int] NOT NULL,
    [ID] [int] NOT NULL,
    [ID_AAL] [int] NOT NULL,
    [LAST_UPDATED] [date] NOT NULL,
    [DEACTIVATE_DATE] [datetime2](6) NULL,
    [DEACTIVATE_USER] [varchar](255) NULL,
    [ID_PATIENT] [int] NOT NULL,
    [GUID] [varchar](36) NOT NULL,
    [NOTE] [varchar](2000) NULL,
    [DISPLAY_DE] [varchar](1) NULL,
    [DISPLAY_DE_QA] [varchar](1) NULL,
    [DISPLAY_FILL] [varchar](1) NULL,
    [DISPLAY_OE] [varchar](1) NULL,
    [DISPLAY_QA] [varchar](1) NULL,
    [DISPLAY_WC] [varchar](1) NULL,
    [DISPLAY_NEW_RX] [varchar](1) NULL,
    [DISPLAY_CALL] [varchar](1) NULL,
    [ID_AUDIT] [int] NULL,
    [AUDIT_TIMESTAMP] [datetime2](6) NOT NULL,
    [CREATE_DATE] [datetime2](6) NULL,
    [USER_ID] [varchar](255) NULL,
    [ELIGIBLE_TO_PRINT] [varchar](1) NULL,
    [EXPIRATION_DATE] [datetime2](6) NULL,
    [CREATED_STORE_NHINID] [numeric](22, 0) NULL,
    [DISPLAY_PAE] [varchar](1) NULL,
    [DISPLAY_RPH_PATIENT_NOTE_IN_DV] [varchar](1) NULL
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Audit Timestamp Range (quarterly note analysis)
CREATE NONCLUSTERED INDEX [IX_PATIENT_NOTES_AUDIT_TIMESTAMP] 
ON [EPS].[PATIENT_NOTES_AUDIT] ([AUDIT_TIMESTAMP], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [GUID], [NOTE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Patient Notes History (patient clinical notes timeline)
CREATE NONCLUSTERED INDEX [IX_PATIENT_NOTES_AUDIT_PATIENT] 
ON [EPS].[PATIENT_NOTES_AUDIT] ([ID_PATIENT], [AUDIT_TIMESTAMP], [CHAIN_ID])
INCLUDE ([ID], [GUID], [NOTE], [CREATE_DATE], [USER_ID])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- GUID Lookup (unique note identifier)
CREATE NONCLUSTERED INDEX [IX_PATIENT_NOTES_AUDIT_GUID] 
ON [EPS].[PATIENT_NOTES_AUDIT] ([GUID], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [AUDIT_TIMESTAMP])
WHERE [GUID] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- PAGE compression for audit table
ALTER TABLE [EPS].[PATIENT_NOTES_AUDIT] 
SET (COMPRESSION = PAGE);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[COMPOSITE_PARTITIONING] Oracle: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
  Recommendation: Post-migration monthly RANGE partitioning:
  
  CREATE PARTITION FUNCTION [PF_PATIENT_NOTES_AUDIT_MONTHLY](datetime2)
  AS RANGE RIGHT FOR VALUES ('2024-07-01', '2024-08-01', ... '2026-09-01');

[CLINICAL_NOTES_DOMAIN]
  PATIENT_NOTES: Pharmacy clinical documentation:
  - [NOTE]: Free-text clinical observation (1-2000 characters)
  - [GUID]: Unique note identifier (UUID for deduplication)
  - [USER_ID]: Pharmacist/pharmacy technician who entered note
  - [CREATE_DATE]: When note originally created
  - [AUDIT_TIMESTAMP]: When note record changed (audit timestamp)
  
  Example notes:
    - "Patient called, refill request denied pending MD contact"
    - "OTC allergy medicine recommended, counseled on interactions"
    - "Patient transferred to new address, updated profile"
    - "Follow-up consult scheduled, patient education completed"

[DISPLAY_FLAGS] - Visibility Control:
  Pharmacy system has multiple views/modules with different visibility rules:
  - [DISPLAY_DE]: Data Entry module
  - [DISPLAY_DE_QA]: Data Entry QA review
  - [DISPLAY_FILL]: Filling module (technician perspective)
  - [DISPLAY_OE]: Order Entry (prescriber portal)
  - [DISPLAY_QA]: Quality Assurance review
  - [DISPLAY_WC]: Patient web portal display
  - [DISPLAY_NEW_RX]: New prescription alert
  - [DISPLAY_CALL]: Phone/caller display
  - [DISPLAY_PAE]: Pharmacy Account Entry
  - [DISPLAY_RPH_PATIENT_NOTE_IN_DV]: Pharmacist DV view
  
  Pattern: Each flag = 'Y' or NULL (default false)
  Example: Note visible to technicians (DISPLAY_FILL='Y') but not to patient (DISPLAY_WC=NULL)

[DEACTIVATION] DEACTIVATE_DATE + DEACTIVATE_USER:
  Note marked inactive (not deleted, archived):
  - [DEACTIVATE_DATE]: When note was deactivated
  - [DEACTIVATE_USER]: Who deactivated (employee ID or name)
  
  Reasons for deactivation:
    - Privacy request (patient ask to remove personal information)
    - Correction (new corrected note created, old marked obsolete)
    - Duplicate (consolidated to single note)
    - Confidentiality upgrade (note should not be visible to certain roles)

[GUID_USAGE] - Globally Unique Identifier:
  [GUID]: UUID (36-character format, e.g., 'A7F3E2B1-D4C9-4E6F-8A2C-5B7D1E3F4A6C')
  Purpose:
    - Deduplication (same GUID = duplicate note, ignore one)
    - Integration key (if notes exported/reimported)
    - Unique reference across systems (FDA audit trail requirement)
  
  Validation: GUID should be RFC 4122 format

[ELIGIBLE_TO_PRINT] - Patient Documentation:
  [ELIGIBLE_TO_PRINT]: Flag if note can be printed for patient copy
  Pharmacy may restrict certain notes (internal QA comments, prescriber negotiations)
  
  Example:
    Printable: "Patient counseled on new medication, took home information sheet"
    Not printable: "Patient's insurance denied coverage, discussing override with prescriber"

[SIZE_ESTIMATE] ~1.2-2.0 GB (clinical notes volume, 13 chains × 3 months rolling)

[AUDIT_TRAIL_FORENSICS]
  Complete note lifecycle audit:
  SELECT [CREATE_DATE], [AUDIT_TIMESTAMP], [DEACTIVATE_DATE], [NOTE], 
         [USER_ID], [DEACTIVATE_USER], [DISPLAY_DE], [DISPLAY_FILL]
  FROM [EPS].[PATIENT_NOTES_AUDIT]
  WHERE [ID_PATIENT] = @patientID
  AND [GUID] = @noteGUID
  ORDER BY [AUDIT_TIMESTAMP];
  
  Reveals: Who created, when, what changes, when deactivated, who deactivated

[DATA_QUALITY_VALIDATION]
  ✓ GUID non-null and unique (RFC 4122 format)
  ✓ LAST_UPDATED date (not future)
  ✓ CREATE_DATE <= AUDIT_TIMESTAMP (creation before audit log entry)
  ✓ DEACTIVATE_DATE >= CREATE_DATE (deactivation after creation)
  ✓ EXPIRATION_DATE > CREATE_DATE (expiration in future)
  ✓ USER_ID non-null (who created note)
  ✓ NOTE text 1-2000 characters (if present)
  ✓ DISPLAY_* flags are 'Y' or NULL (valid values)
  ✓ ID_PATIENT references valid PATIENT record
  ✓ CREATED_STORE_NHINID references valid STORE (if populated)

[COMPLIANCE_CONSIDERATIONS]
  HIPAA Clinical Documentation:
    - All notes are PHI (Protected Health Information)
    - Changes tracked in audit table (who, what, when)
    - Soft-delete only (no permanent deletion of clinical records)
    - 5+ year retention for all notes (statute of limitations)
    - Privileged communication (pharmacist-patient confidentiality)
  
  Pharmacy Board Regulations:
    - All patient interactions documented
    - Questions and answers recorded
    - Medication therapy changes noted
    - Adverse events reported

[EXPIRATION_MANAGEMENT]
  [EXPIRATION_DATE]: When note should be archived/deleted:
    - Older medications (note no longer relevant after 3-5 years)
    - Patient deceased (notes archived, not deleted)
    - Regulatory retention satisfied (archive to cold storage)
  
  Compliance workflow:
    SELECT [ID_PATIENT], [NOTE], [EXPIRATION_DATE]
    FROM [EPS].[PATIENT_NOTES_AUDIT]
    WHERE [EXPIRATION_DATE] < GETDATE()
    AND [DELETED] IS NULL;
    
    Output used for: Archival job, compliance report

[PRINT_RESTRICTION_LOGIC]
  Patient Web Portal displayed notes (DISPLAY_WC='Y'):
    Only show notes if [ELIGIBLE_TO_PRINT] = 'Y'
    Rationale: Some clinical discussions inappropriate for patient viewing
    (e.g., "Patient's insurance denied, exploring alternative medications")

[MULTI-MODULE_NOTE_VISIBILITY]
  Pharmacy system modules see different notes:
  - Pharmacy Technician (filling): DISPLAY_FILL='Y' notes only
  - Pharmacist (counseling): All notes accessible
  - Prescriber (order entry): DISPLAY_OE='Y' notes only
  - Patient (web portal): DISPLAY_WC='Y' notes only
  - QA Auditor: All notes for compliance review
  
  Business rule: DISPLAY_* flags control role-based access
  Recommendation: Validate DISPLAY_* configuration in UAT

[POST_MIGRATION_CONSIDERATIONS]
  GUID validation: Ensure all notes have valid GUID
  DISPLAY flags: Audit sample of notes to confirm visibility rules are correct
  Expiration dates: Verify compliance with retention regulations
  User IDs: Validate all USER_ID entries reference valid employees
*/
