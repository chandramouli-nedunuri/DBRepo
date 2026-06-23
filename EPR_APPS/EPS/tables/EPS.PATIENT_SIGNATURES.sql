-- ============================================================================
-- Azure SQL Conversion: EPS.PATIENT_SIGNATURES
-- Master Table with LOB Storage (Patient Signatures Registry)
-- Source: Oracle (EPS database)
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-29
-- LOB Strategy: Inline storage (VARBINARY(MAX))
-- ============================================================================

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID (~25 extended chains)
--       All partitions removed for Azure SQL (non-partitioned implementation)
--       Partitioning strategy can be reapplied post-migration if needed

-- LOB CONVERSION NOTES:
-- =====================
-- Oracle: BLOB columns for binary signature storage
-- Azure Implementation: VARBINARY(MAX) for inline storage
-- Strategy: First pass uses inline storage (VARBINARY(MAX))
-- Rationale: Supports up to 2 GB per value; easier for initial migration
-- Alternative: Azure Blob Storage with reference URLs (can be implemented post-migration)
-- Post-Migration Option: Move large signature BLOBs to Azure Blob Storage if table grows >500 GB

-- EXTERNAL REFERENCE HANDSHAKE:
-- =============================
-- This table stores digital signatures with external repository references
-- Current Pattern: Optional reference columns to document/file external storage
-- Azure Migration: Consider Azure Blob Storage for signature files
-- Implementation: Add URL/reference column if using external storage post-migration

CREATE TABLE [EPS].[PATIENT_SIGNATURES]
(
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [SIGNATURE_DATA] VARBINARY(MAX) NULL,  -- NOTE: Converted from Oracle BLOB to VARBINARY(MAX)
    [SIGNATURE_TYPE] VARCHAR(50) NULL,
    [SIGNATURE_FORMAT] VARCHAR(20) NULL,
    [SIGNATURE_DATE] DATETIME2(6) NULL,
    [EXTERNAL_STORAGE_URL] VARCHAR(MAX) NULL,  -- Optional: URL to external signature storage
    [LAST_UPDATED] DATETIME2(6) NOT NULL,
    [ID_AAL] BIGINT NULL,
    
    CONSTRAINT [PATIENT_SIGNATURES_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]) WITH (FILLFACTOR = 90),
    CONSTRAINT [PATIENT_SIGNATURES_FK1] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT]) 
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID])
)
-- NOTE: Oracle storage and tuning parameters removed
-- NOTE: All Oracle partitioning removed (original: LIST by CHAIN_ID with ~25 extended chains)
-- LOB STRATEGY: Inline storage using VARBINARY(MAX)
--   Size consideration: Monitor table growth; move to Azure Blob if exceeds 500 GB
--   Access: Retrieve directly from database; post-migration migration to Blob Storage optional
-- EXTERNAL STORAGE: Optional [EXTERNAL_STORAGE_URL] column for Azure Blob Storage references
--   Implementation: Populate during migration if using hybrid inline + external patterns
--   Validation: Pre-cutover validation of all signature references recommended
-- NOTE: Foreign key deferrability not supported (Azure enforces immediately)
