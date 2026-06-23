-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_NOTES
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_NOTES
-- Type: Master Transaction Table (Clinical Notes)
-- Oracle Partitions: LIST by CHAIN_ID (13 standard chains)
-- Purpose: Active patient pharmacy clinical notes

CREATE TABLE [EPS].[PATIENT_NOTES] (
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
    [CREATE_DATE] [datetime2](6) NULL,
    [USER_ID] [varchar](255) NULL,
    [ELIGIBLE_TO_PRINT] [varchar](1) NULL,
    [EXPIRATION_DATE] [datetime2](6) NULL,
    [CREATED_STORE_NHINID] [numeric](22, 0) NULL,
    [DISPLAY_PAE] [varchar](1) NULL,
    [DISPLAY_RPH_PATIENT_NOTE_IN_DV] [varchar](1) NULL,
    
    CONSTRAINT [PATIENT_NOTES_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Patient Notes Lookup (clinical note retrieval)
CREATE NONCLUSTERED INDEX [IX_PATIENT_NOTES_PATIENT] 
ON [EPS].[PATIENT_NOTES] ([ID_PATIENT], [CHAIN_ID], [CREATE_DATE])
INCLUDE ([ID], [GUID], [NOTE], [USER_ID], [DISPLAY_FILL])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- GUID Unique Lookup (note deduplication)
CREATE NONCLUSTERED INDEX [IX_PATIENT_NOTES_GUID] 
ON [EPS].[PATIENT_NOTES] ([GUID], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [CREATE_DATE])
WHERE [GUID] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Expiration Tracking (retention compliance)
CREATE NONCLUSTERED INDEX [IX_PATIENT_NOTES_EXPIRATION] 
ON [EPS].[PATIENT_NOTES] ([EXPIRATION_DATE], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [NOTE])
WHERE [EXPIRATION_DATE] IS NOT NULL AND [DEACTIVATE_DATE] IS NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- ROW compression for notes table
ALTER TABLE [EPS].[PATIENT_NOTES] 
SET (COMPRESSION = ROW);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[PRIMARY_KEY] Composite key: (CHAIN_ID, ID)
  Ensures unique note per chain

[NOTE_LIFECYCLE]
  1. Pharmacist/technician creates note during patient interaction
  2. [CREATE_DATE] set to transaction time
  3. [USER_ID] captures employee who entered note
  4. [GUID] assigned (UUID for deduplication across systems)
  5. Note stored in [NOTE] field (1-2000 character text)
  6. DISPLAY_* flags set to control visibility per module
  7. [EXPIRATION_DATE] set based on retention policy
  8. [ELIGIBLE_TO_PRINT] flag determines patient portal visibility
  9. If note needs to be archived: [DEACTIVATE_DATE] set, [DEACTIVATE_USER] recorded
  10. Note preserved in audit table throughout lifecycle

[CLINICAL_DOCUMENTATION_EXAMPLES]
  "Patient called requesting fill on lisinopril, confirmed with prescriber"
  "Counseled patient on sulfur allergy interaction with sulfonamides"
  "Auto-refill cancelled per patient request due to medication change"
  "Patient reported sensitivity to metoprolol, recommended alternative to MD"
  "Vaccine records updated per patient immunization documentation"
  "DME order requested, confirmed insurance coverage with benefits call"
  "Patient education: Proper inhaler technique, provided demonstration"

[PARTITIONING_REMOVED] Oracle LIST partitioning by CHAIN_ID (13 standard chains)
  Note: Standard 13-chain set (GEAGLE, ECOM, HANNAF, MEIJER, RXCOM, SHOPKO, STLUKE, etc.)
  NOT the extended ~25-chain set of PATIENT_DOCUMENT and PATIENT_EMERGENCY_CONTACT
  
  Index strategy: Standard nonclustered (standard chain set)

[SIZE_ESTIMATE] ~300-600 MB (active notes, much smaller than audit table)

[MULTI_CHAIN_NOTE_QUERIES]
  Typical pharmacy operations:
  
  -- Recent notes for patient
  SELECT TOP 10 * FROM [EPS].[PATIENT_NOTES]
  WHERE [ID_PATIENT] = @patientID
  AND [CHAIN_ID] = @chainID
  AND [DEACTIVATE_DATE] IS NULL
  ORDER BY [CREATE_DATE] DESC;
  
  -- Notes visible in filling module
  SELECT * FROM [EPS].[PATIENT_NOTES]
  WHERE [ID_PATIENT] = @patientID
  AND [DISPLAY_FILL] = 'Y'
  AND [DEACTIVATE_DATE] IS NULL
  ORDER BY [CREATE_DATE] DESC;
  
  -- Notes from specific pharmacist
  SELECT * FROM [EPS].[PATIENT_NOTES]
  WHERE [USER_ID] = @pharmacistID
  AND [CREATE_DATE] >= DATEADD(DAY, -30, GETDATE())
  ORDER BY [CREATE_DATE] DESC;

[GUID_DEDUPLICATION] - Data Integration:
  If notes exported/reimported (data warehouse, external system):
  Duplicate detection using GUID:
  
  SELECT [GUID], COUNT(*) as [Duplicates]
  FROM [EPS].[PATIENT_NOTES]
  GROUP BY [GUID]
  HAVING COUNT(*) > 1;  -- Should return 0 (GUID is unique)
  
  GUID ensures: Even if note reimported, duplicate GUID identified and merged

[ROLE_BASED_NOTE_VISIBILITY]
  Business rule: Different users see different notes based on DISPLAY_* flags
  
  Pharmacy Technician:
    SELECT * FROM [EPS].[PATIENT_NOTES]
    WHERE [ID_PATIENT] = @patientID
    AND [DISPLAY_FILL] = 'Y'   -- Filling module visibility
    AND [DEACTIVATE_DATE] IS NULL;
  
  Pharmacist (full access):
    SELECT * FROM [EPS].[PATIENT_NOTES]
    WHERE [ID_PATIENT] = @patientID
    AND [DEACTIVATE_DATE] IS NULL;  -- All notes
  
  Patient web portal:
    SELECT * FROM [EPS].[PATIENT_NOTES]
    WHERE [ID_PATIENT] = @patientID
    AND [DISPLAY_WC] = 'Y'     -- Web portal visibility
    AND [ELIGIBLE_TO_PRINT] = 'Y'  -- Eligible for patient viewing
    AND [DEACTIVATE_DATE] IS NULL;
  
  Prescriber (order entry):
    SELECT * FROM [EPS].[PATIENT_NOTES]
    WHERE [ID_PATIENT] = @patientID
    AND [DISPLAY_OE] = 'Y'     -- Order entry visibility
    AND [DEACTIVATE_DATE] IS NULL;

[CREATED_STORE_NHINID] - Location Tracking:
  Which store location created the note:
  Example: Patient interaction at GEAGLE location → [CREATED_STORE_NHINID] = 102
  
  Enables: Location-specific note analysis, shift-specific notes, location accountability

[DEACTIVATION_SOFT_DELETE]
  Deactivated notes NOT deleted (preserved in audit):
  [DEACTIVATE_DATE] set when note archived/removed
  [DEACTIVATE_USER] logs who deactivated (accountability)
  
  Example: Duplicate note deactivation
    Original note: [ID] = 1001, [GUID] = 'ABC123', [CREATE_DATE] = 2026-01-15
    Duplicate note: [ID] = 1002, [GUID] = 'ABC123', [CREATE_DATE] = 2026-01-15
                    [DEACTIVATE_DATE] = 2026-01-20, [DEACTIVATE_USER] = 'JSMITH'
  
  Result: Original kept active, duplicate preserved but deactivated

[DATA_QUALITY_VALIDATION]
  ✓ GUID non-null, unique, RFC 4122 format
  ✓ [CREATE_DATE] <= [LAST_UPDATED] (creation before update)
  ✓ [DEACTIVATE_DATE] >= [CREATE_DATE] (if set)
  ✓ [EXPIRATION_DATE] > [CREATE_DATE] (future expiration)
  ✓ [NOTE] length 1-2000 characters (if present)
  ✓ [USER_ID] non-null (who created note)
  ✓ [DEACTIVATE_USER] non-null IFF [DEACTIVATE_DATE] IS NOT NULL
  ✓ [DISPLAY_*] flags are 'Y' or NULL (no invalid values)
  ✓ ID_PATIENT references valid PATIENT record
  ✓ CREATED_STORE_NHINID references valid STORE (if populated)

[SYNC_WITH_AUDIT]
  Master table [PATIENT_NOTES] contains active notes
  Audit table [PATIENT_NOTES_AUDIT] contains full history
  
  Validation: Count of notes in master should be << count in audit
  Expected ratio: Master ~30% of audit (due to accumulated historical changes)

[HIPAA_CLINICAL_DOCUMENTATION_PRESERVATION]
  All patient interactions documented and audited
  No manual deletion allowed (soft-delete only)
  Full change history retained indefinitely
  User identification captured (USER_ID = employee accountability)
  
  Purpose: Enable compliance reviews, dispute resolution, legal discovery
*/
