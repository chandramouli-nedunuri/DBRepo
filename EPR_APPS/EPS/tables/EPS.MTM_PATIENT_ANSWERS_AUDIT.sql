-- ============================================================
-- Azure SQL Schema Conversion for EPS.MTM_PATIENT_ANSWERS_AUDIT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-25
-- ============================================================

-- TABLE: EPS.MTM_PATIENT_ANSWERS_AUDIT
-- Type: Composite Partitioned Audit Table (Medication Therapy Management)
-- Oracle Partitions: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
-- Purpose: Audit trail for MTM patient questionnaire responses

CREATE TABLE [EPS].[MTM_PATIENT_ANSWERS_AUDIT] (
    [CHAIN_ID] [int] NOT NULL,
    [ID] [int] NOT NULL,
    [ANSWER_SEQUENCE] [numeric](3, 0) NULL,
    [QUESTION_VERSION] [numeric](10, 0) NULL,
    [RX_COM_QUESTION_NUMBER] [numeric](10, 0) NULL,
    [ID_MTM_PATIENT_SESSION] [int] NOT NULL,
    [ID_AAL] [int] NOT NULL,
    [LAST_UPDATED] [datetime] NULL,
    [ID_AUDIT] [int] NOT NULL,
    [AUDIT_TIMESTAMP] [datetime2](6) NOT NULL
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Audit Timestamp Range Query
CREATE NONCLUSTERED INDEX [IX_MTM_ANSWERS_AUDIT_TIMESTAMP] 
ON [EPS].[MTM_PATIENT_ANSWERS_AUDIT] ([AUDIT_TIMESTAMP], [CHAIN_ID])
INCLUDE ([ID], [ID_MTM_PATIENT_SESSION], [ID_AUDIT])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Session Reference (connect to MTM_PATIENT_SESSION)
CREATE NONCLUSTERED INDEX [IX_MTM_ANSWERS_AUDIT_SESSION] 
ON [EPS].[MTM_PATIENT_ANSWERS_AUDIT] ([ID_MTM_PATIENT_SESSION], [CHAIN_ID], [AUDIT_TIMESTAMP])
INCLUDE ([ID], [ANSWER_SEQUENCE], [QUESTION_VERSION])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Chain-based Filtering
CREATE NONCLUSTERED INDEX [IX_MTM_ANSWERS_AUDIT_CHAIN] 
ON [EPS].[MTM_PATIENT_ANSWERS_AUDIT] ([CHAIN_ID], [AUDIT_TIMESTAMP])
INCLUDE ([ID], [ID_MTM_PATIENT_SESSION])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- PAGE compression for audit table (high repetition)
ALTER TABLE [EPS].[MTM_PATIENT_ANSWERS_AUDIT] 
SET (COMPRESSION = PAGE);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[COMPOSITE_PARTITIONING] Oracle structure: LIST by CHAIN_ID (13 chains) + RANGE by AUDIT_TIMESTAMP (3-month rolling)
  
  RECOMMENDATION: Implement 24-month rolling monthly RANGE partitioning post-migration:
  
  CREATE PARTITION FUNCTION [PF_MTM_ANSWERS_AUDIT_MONTHLY](datetime2)
  AS RANGE RIGHT FOR VALUES (
      '2024-07-01', '2024-08-01', ... '2026-09-01'
  );
  
  This supports efficient quarterly MTM audit reviews and compliance reporting

[SESSION_RELATIONSHIP] Foreign key relationship to EPS.MTM_PATIENT_SESSION
  Audit records tied to MTM_PATIENT_SESSION parent by ID_MTM_PATIENT_SESSION
  
  VALIDATION: Ensure all audit records have matching SESSION record
  SELECT COUNT(DISTINCT A.ID_MTM_PATIENT_SESSION) as [AuditSessions],
         COUNT(DISTINCT S.ID) as [CurrentSessions]
  FROM [EPS].[MTM_PATIENT_ANSWERS_AUDIT] A
  LEFT JOIN [EPS].[MTM_PATIENT_SESSION] S 
    ON A.CHAIN_ID = S.CHAIN_ID AND A.ID_MTM_PATIENT_SESSION = S.ID;

[QUESTION_VERSIONING] Columns [QUESTION_VERSION], [RX_COM_QUESTION_NUMBER] track:
  - MTM questionnaire evolution (version control)
  - RX_Com external system mapping
  
  No constraints enforced - consider adding check constraint if valid versions known:
  ALTER TABLE [EPS].[MTM_PATIENT_ANSWERS_AUDIT]
  ADD CONSTRAINT [CK_QUESTION_VERSION] CHECK ([QUESTION_VERSION] > 0);

[SIZE_ESTIMATE] ~300-500 MB (MTM-participating locations × 3 months rolling)

[AUDIT_RETENTION] Determine retention policy for MTM audit data:
  - 3 years minimum (typical pharmacy compliance)
  - Consider archiving to cold storage after 24 months
  - Use sliding window partitioning to automate cleanup

[SEQUENCE_GAPS] Validate ANSWER_SEQUENCE values:
  SELECT [ANSWER_SEQUENCE], COUNT(*) FROM [EPS].[MTM_PATIENT_ANSWERS_AUDIT]
  GROUP BY [ANSWER_SEQUENCE] ORDER BY [ANSWER_SEQUENCE];
  
  Expect sequential 1-N per session
*/
