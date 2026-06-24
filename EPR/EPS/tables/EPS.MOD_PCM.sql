-- ============================================================
-- Azure SQL Schema Conversion for EPS.MOD_PCM
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-25
-- ============================================================

-- TABLE: EPS.MOD_PCM
-- Type: Master Configuration Table with DEFERRABLE Foreign Keys
-- Oracle Partitions: LIST by CHAIN_ID (13 partitions)
-- Contains: 25 data columns + supplemental logging

CREATE TABLE [EPS].[MOD_PCM] (
    [CHAIN_ID] [int] NOT NULL,
    [ID] [int] NOT NULL,
    [DELETED] [char](1) NULL,
    [LAST_UPDATED] [datetime] NULL,
    [NHIN_ID] [int] NULL,
    [LABEL1A] [varchar](25) NULL,
    [LABEL2A] [varchar](25) NULL,
    [LABEL3A] [varchar](25) NULL,
    [LABEL4A] [varchar](25) NULL,
    [LABEL5A] [varchar](25) NULL,
    [LABEL6A] [varchar](25) NULL,
    [LABEL7A] [varchar](25) NULL,
    [LABEL8A] [varchar](25) NULL,
    [LABEL1B] [varchar](25) NULL,
    [LABEL2B] [varchar](25) NULL,
    [LABEL3B] [varchar](25) NULL,
    [LABEL4B] [varchar](25) NULL,
    [LABEL5B] [varchar](25) NULL,
    [LABEL6B] [varchar](25) NULL,
    [LABEL7B] [varchar](25) NULL,
    [LABEL8B] [varchar](25) NULL,
    [ID_AAL] [int] NULL,
    [ARCHIVE_DATE] [datetime] NULL,
    
    -- FOREIGN KEY CONSTRAINTS
    -- ⚠️ [DEFERRABLE_FK] These constraints are DEFERRABLE INITIALLY DEFERRED in Oracle
    -- Azure SQL doesn't support native DEFERRABLE - constraint checking at COMMIT time
    CONSTRAINT [MOD_PCM_FK_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [MOD_PCM_FK_ESSTORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID]),
    
    CONSTRAINT [PK_MOD_PCM] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Chain-Store Composite (replaces Oracle LIST partitioning)
CREATE NONCLUSTERED INDEX [IX_MOD_PCM_CHAIN_NHIN] 
ON [EPS].[MOD_PCM] ([CHAIN_ID], [NHIN_ID])
INCLUDE ([ID], [ID_AAL])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- AAL Reference Lookup
CREATE NONCLUSTERED INDEX [IX_MOD_PCM_AAL] 
ON [EPS].[MOD_PCM] ([ID_AAL])
INCLUDE ([CHAIN_ID], [ID])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- Transactional tables use ROW compression (CHAIN_ID repetition benefits)
ALTER TABLE [EPS].[MOD_PCM] 
SET (COMPRESSION = ROW);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[DEFERRABLE_FK_WARNING] This table contains 2 DEFERRABLE INITIALLY DEFERRED foreign keys:
  1. MOD_PCM_FK_ESCHAIN references SEC_ADMIN.EPS_SEC_CHAIN
  2. MOD_PCM_FK_ESSTORE references SEC_ADMIN.EPS_SEC_STORE
  
  Azure SQL Server does NOT support native DEFERRABLE constraint semantics. 
  These constraints behave as IMMEDIATE by default.
  
  IMPACT: Any application code relying on deferred constraint checking will fail.
  
  REMEDIATION STRATEGY:
  a) Modify application INSERT/UPDATE transactions to ensure referential integrity
     in transaction order (insert parent before child)
  b) Use explicit transaction handling:
     BEGIN TRANSACTION;
     -- Insert into referenced tables first
     -- Then insert into MOD_PCM
     COMMIT;
  
  ACTION REQUIRED: Application code audit for constraint deferral dependencies
  RISK LEVEL: [DEFERRABLE_FK] - Must be resolved before UAT
  
  SCRIPT: See CRITICAL_FIX_SCRIPTS.sql for validation and remediation guidance

[PARTITIONING_REMOVED] Oracle LIST partitioning by CHAIN_ID (13 partitions) removed:
  GEAGLE(102), ECOM(99), HANNAF(88), MEIJER(128), RXCOM(119080), SHOPKO(180),
  STLUKE(114147), FREDS(70), GUNDER(368), WEBSCR(98), DUMMY(?), MEDSHP(?), ACMEHQ(?)
  
  Nonclustered index on CHAIN_ID compensates for partition elimination filtering

[SIZE_ESTIMATE] ~50-80 MB (configuration reference table, relatively small)

[AUDIT_LOGGING] Ensure SQL Server Audit or Change Data Capture (CDC) enabled
  if original Oracle database had supplemental logging requirements
*/
