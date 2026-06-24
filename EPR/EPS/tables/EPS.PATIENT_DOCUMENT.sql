-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_DOCUMENT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_DOCUMENT
-- Type: Master Transaction Table (Document Management)
-- Oracle Partitions: LIST by CHAIN_ID (~25 extended chains)
-- Purpose: Patient document registry (scanned records, forms, attachments)

CREATE TABLE [EPS].[PATIENT_DOCUMENT] (
    [CHAIN_ID] [int] NOT NULL,
    [ID] [int] NOT NULL,
    [ID_PATIENT] [int] NOT NULL,
    [EPS_DOCUMENT_ID] [numeric](38, 0) NOT NULL,
    [TITLE] [varchar](60) NOT NULL,
    [TYPE] [varchar](60) NOT NULL,
    [NHIN_ID] [int] NULL,
    [ID_AAL] [int] NULL,
    [LAST_UPDATED] [datetime2](6) NULL,
    [EXPIRE_DATE] [datetime2](6) NULL,
    [DEACTIVATE_DATE] [datetime2](6) NULL,
    [DELETED] [varchar](1) NULL,
    [SUB_TYPE] [varchar](60) NULL,
    
    CONSTRAINT [PATIENT_DOCUMENT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Patient Document Lookup (document retrieval)
CREATE NONCLUSTERED INDEX [IX_PATIENT_DOCUMENT_PATIENT] 
ON [EPS].[PATIENT_DOCUMENT] ([ID_PATIENT], [CHAIN_ID])
INCLUDE ([ID], [TITLE], [TYPE], [EXPIRE_DATE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Document Type Lookup (by classification)
CREATE NONCLUSTERED INDEX [IX_PATIENT_DOCUMENT_TYPE] 
ON [EPS].[PATIENT_DOCUMENT] ([TYPE], [SUB_TYPE], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [EXPIRE_DATE])
WHERE [DELETED] IS NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Document Expiration (retention/compliance)
CREATE NONCLUSTERED INDEX [IX_PATIENT_DOCUMENT_EXPIRE] 
ON [EPS].[PATIENT_DOCUMENT] ([EXPIRE_DATE], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [TITLE])
WHERE [EXPIRE_DATE] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- ROW compression for document registry
ALTER TABLE [EPS].[PATIENT_DOCUMENT] 
SET (COMPRESSION = ROW);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[PRIMARY_KEY] Composite key: (CHAIN_ID, ID)
  Ensures one unique document per chain

[PARTITIONING_REMOVED] Oracle LIST partitioning by CHAIN_ID (~25 chains) removed
  Note: Extended partition set (ACMEHQ, ALBERT, APOTHERCARY, AVELLA, BEST, BURKLOW, etc.)
  Replaced with nonclustered indexes on CHAIN_ID

[DOCUMENT_MANAGEMENT_DOMAIN]
  Patient document repository for regulatory/clinical records:
  - Prescription forms (hard copies)
  - Prior authorization letters
  - Insurance correspondence
  - Lab results (scanned)
  - Clinical notes (legacy paper)
  - Legal/compliance documents
  
  Workflow:
  1. Document received (physical or electronic)
  2. EPS_DOCUMENT_ID assigned (external document storage system)
  3. TITLE assigned (document name for lookup)
  4. TYPE classified (prescription, authorization, lab, legal, etc.)
  5. SUB_TYPE for further categorization (specific prescription type, lab test, etc.)
  6. EXPIRE_DATE set (retention requirement, compliance deletion trigger)
  7. Archived (DELETED flag when retention period expires)

[EPS_DOCUMENT_ID] Reference to external document management system:
  - May link to separate DMS (document management system)
  - Handles actual file storage (not in EPS database)
  - EPS table = metadata registry only (title, type, expiration)
  
  Consider: Link validation to DMS during migration (verify all documents exist)

[DOCUMENT_TYPE_HIERARCHY]
  TYPE: Top-level classification (prescription, authorization, clinical, legal, etc.)
  SUB_TYPE: Further categorization (morphine prescription, Medicare denial, lab test, etc.)
  
  Example:
  TYPE='PRESCRIPTION', SUB_TYPE='CONTROLLED_SUBSTANCE'
  TYPE='LAB_RESULT', SUB_TYPE='URINALYSIS'
  TYPE='INSURANCE_DOC', SUB_TYPE='DENIAL_LETTER'

[EXPIRATION_MANAGEMENT] HIPAA/state-regulated retention:
  - Federal minimum: 3 years (HIPAA)
  - State requirements: Vary by state (CA 7 years, TX 5 years)
  - Best practice: 7 years minimum
  - Drug-related: 10+ years for controlled substance records
  
  Post-migration workflow:
  - Periodic job to identify expired documents (EXPIRE_DATE < TODAY())
  - Batch archive/delete process (compliance-controlled)
  - Audit trail (DELETED flag + DEACTIVATE_DATE mark when removed)

[EXTENDED_PARTITION_SET] ~25 chains:
  Index strategy: Unified nonclustered indexes (handles all chains)
  Avoid partition proliferation (25 index key combinations = complexity)
  
  Recommendation: Use composite indexes (CHAIN_ID first, then business key)

[SIZE_ESTIMATE] ~100-300 MB (metadata only, actual files stored externally)

[DOCUMENT_DEACTIVATION] DEACTIVATE_DATE soft-delete flag:
  Indicates document no longer accessible:
  - Retention period expired (auto-archive)
  - Legal hold released
  - Duplicate document (marked inactive)
  
  Soft-delete preserves audit trail (can reactivate if needed)

[DATA_QUALITY_VALIDATION]
  ✓ EPS_DOCUMENT_ID exists and non-null
  ✓ TITLE and TYPE non-null (required fields)
  ✓ EXPIRE_DATE > LAST_UPDATED (future expiration, not past)
  ✓ DEACTIVATE_DATE >= LAST_UPDATED (if set)
  ✓ EPS_DOCUMENT_ID unique (no duplicate documents)
  ✓ ID_PATIENT references valid PATIENT record

[ORPHANED_DOCUMENT_VALIDATION]
  SELECT COUNT(DISTINCT [ID_PATIENT])
  FROM [EPS].[PATIENT_DOCUMENT] D
  LEFT JOIN [EPS].[PATIENT] P ON D.[ID_PATIENT] = P.[ID]
  WHERE P.[ID] IS NULL;  -- Should return 0

[POST-MIGRATION_STRATEGY]
  1. Link to external DMS: Validate all EPS_DOCUMENT_ID references
  2. Retention policy: Implement automatic expiration workflow
  3. Compliance reporting: Monthly report of documents nearing expiration
  4. Archive strategy: Move expired documents to cold storage (Blob/S3)
  5. Audit: Log all document access for HIPAA compliance
*/
