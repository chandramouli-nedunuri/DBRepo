-- ============================================================================
-- Azure SQL Conversion: EPS.PATIENT_SIGNATURES_AUDIT
-- Audit Table with LOB Storage (Patient Signatures)
-- Source: Oracle (EPS database)
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-29
-- LOB Strategy: Inline storage (VARBINARY(MAX))
-- ============================================================================

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID (~25 extended chains)
--       All partitions removed for Azure SQL (non-partitioned implementation)
--       Composite partitioning strategy removed

-- LOB CONVERSION NOTES:
-- =====================
-- Oracle: BLOB columns for binary signature storage
-- Azure Implementation: VARBINARY(MAX) for inline storage
-- Strategy: First pass uses inline storage (VARBINARY(MAX))
-- Rationale: Supports up to 2 GB per value; easier for initial migration
-- Alternative: Azure Blob Storage with reference URLs (can be implemented post-migration)
-- Post-Migration Option: Move large signature BLOBs to Azure Blob Storage if table grows >500 GB

CREATE TABLE [EPS].[PATIENT_SIGNATURES_AUDIT]
(
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [SIGNATURE_DATA] VARBINARY(MAX) NULL,  -- NOTE: Converted from Oracle BLOB to VARBINARY(MAX)
    [SIGNATURE_TYPE] VARCHAR(50) NULL,
    [SIGNATURE_FORMAT] VARCHAR(20) NULL,
    [SIGNATURE_DATE] DATETIME2(6) NULL,
    [LAST_UPDATED] DATETIME2(6) NOT NULL,
    [ID_AAL] BIGINT NULL,
    [ID_CREATOR] BIGINT NULL,
    [ID_MODIFIER] BIGINT NULL,
    [DATE_CREATED] DATETIME2(6) NULL,
    [DATE_MODIFIED] DATETIME2(6) NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    
    CONSTRAINT [PATIENT_SIGNATURES_AUDIT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]) WITH (FILLFACTOR = 90),
    CONSTRAINT [PATIENT_SIGNATURES_AUDIT_FK1] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT]) 
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID])
)
-- NOTE: Oracle storage and tuning parameters removed
-- NOTE: All Oracle partitioning removed (original: LIST by CHAIN_ID with ~25 extended chains)
-- NOTE: SUPPLEMENTAL LOG DATA clause removed
-- LOB STRATEGY: Inline storage using VARBINARY(MAX)
--   Size consideration: Monitor table growth; move to Azure Blob if exceeds 500 GB
--   Access: Retrieve directly from database; post-migration migration to Blob Storage optional
-- Audit Table: Standard audit trail with LOB (signature binary data)
