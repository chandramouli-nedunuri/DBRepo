-- ============================================================
-- Azure SQL Schema Conversion for EPS.MOD_PCM_AUDIT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-25
-- ============================================================

-- TABLE: EPS.MOD_PCM_AUDIT
-- Type: Composite Partitioned Audit Table (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP)
-- Oracle Partitions: 13 chains × 3 monthly subpartitions = ~39 partitions
-- Azure Strategy: Remove LIST+RANGE partitioning, create nonclustered indexes

CREATE TABLE [EPS].[MOD_PCM_AUDIT] (
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
    [ID_AUDIT] [int] NULL,
    [ARCHIVE_DATE] [datetime] NULL,
    [AUDIT_TIMESTAMP] [datetime2](6) NOT NULL
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Purpose: Replace Oracle composite LIST+RANGE partitioning with directed indexes

-- Audit Timestamp Range Index (for time-based queries, formerly subpartition key)
CREATE NONCLUSTERED INDEX [IX_MOD_PCM_AUDIT_TIMESTAMP] 
ON [EPS].[MOD_PCM_AUDIT] ([AUDIT_TIMESTAMP], [CHAIN_ID])
INCLUDE ([ID], [ID_AUDIT])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Chain-based Access Pattern
CREATE NONCLUSTERED INDEX [IX_MOD_PCM_AUDIT_CHAIN] 
ON [EPS].[MOD_PCM_AUDIT] ([CHAIN_ID], [AUDIT_TIMESTAMP])
INCLUDE ([ID], [ID_AUDIT])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- Audit tables benefit from PAGE compression due to high repetition of CHAIN_ID, AUDIT_TIMESTAMP

ALTER TABLE [EPS].[MOD_PCM_AUDIT] 
SET (COMPRESSION = PAGE);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[COMPOSITE_PARTITIONING] This table was partitioned in Oracle with:
  - Primary: LIST partition by CHAIN_ID (13 chains)
  - Secondary: RANGE subpartition by AUDIT_TIMESTAMP (3-month rolling monthly boundaries)
  
  RECOMMENDATION: Post-migration, implement monthly RANGE partitioning on [AUDIT_TIMESTAMP]
  with 27-month rolling window (24 months + 3 month sliding buffer):
  
  ALTER TABLE [EPS].[MOD_PCM_AUDIT]
  ADD PARTITION FUNCTION [PF_MOD_PCM_AUDIT_MONTHLY](datetime2) 
      AS RANGE RIGHT FOR VALUES (
          '2024-07-01', '2024-08-01', '2024-09-01', '2024-10-01', 
          '2024-11-01', '2024-12-01', '2025-01-01', '2025-02-01', 
          '2025-03-01', '2025-04-01', '2025-05-01', '2025-06-01',
          '2025-07-01', '2025-08-01', '2025-09-01', '2025-10-01',
          '2025-11-01', '2025-12-01', '2026-01-01', '2026-02-01',
          '2026-03-01', '2026-04-01', '2026-05-01', '2026-06-01',
          '2026-07-01', '2026-08-01', '2026-09-01'
      );
  
  Expected benefit: Faster time-based queries (3-month maintenance window queries)
  Risk: Initial 2-3 hour implementation window required

[STATISTICS] Disable auto-create and auto-update statistics during bulk load:
  ALTER DATABASE [YourDB] SET AUTO_CREATE_STATISTICS OFF;
  ALTER DATABASE [YourDB] SET AUTO_UPDATE_STATISTICS OFF;
  -- Re-enable post-load and manually update

[AUDIT_COLUMN_USAGE] Verify column [DELETED] usage - may indicate logical vs. physical deletes
  Confirm if soft-delete pattern requires indexed filtered view or physical archive table

[SIZE_ESTIMATE] ~600-800 MB (26 columns × 13 chains × 3 months rolling data)
*/
