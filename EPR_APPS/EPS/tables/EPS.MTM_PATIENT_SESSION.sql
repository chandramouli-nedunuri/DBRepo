-- ============================================================
-- Azure SQL Schema Conversion for EPS.MTM_PATIENT_SESSION
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-25
-- ============================================================

-- TABLE: EPS.MTM_PATIENT_SESSION
-- Type: Master Transaction Table with DEFERRABLE Foreign Keys
-- Oracle Partitions: LIST by CHAIN_ID (13 partitions)
-- Purpose: Current MTM patient consultation sessions

CREATE TABLE [EPS].[MTM_PATIENT_SESSION] (
    [CHAIN_ID] [int] NOT NULL,
    [ID] [int] NOT NULL,
    [RUN_DATE] [datetime] NULL,
    [SCORE] [numeric](13, 4) NULL,
    [SCORE_TEXT] [varchar](2000) NULL,
    [STATUS] [numeric](1, 0) NULL,
    [ID_SIGNATURE] [int] NOT NULL,
    [ID_AAL] [int] NOT NULL,
    [LAST_UPDATED] [datetime] NULL,
    
    -- FOREIGN KEY CONSTRAINTS
    -- ⚠️ [DEFERRABLE_FK] Both constraints were DEFERRABLE INITIALLY DEFERRED in Oracle
    CONSTRAINT [MTM_PATIENT_SESSION_FK_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [MTM_PATIENT_SESSION_FK_SIGN] FOREIGN KEY ([CHAIN_ID], [ID_SIGNATURE])
        REFERENCES [EPS].[SIGNATURE] ([CHAIN_ID], [ID])
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Signature (Pharmacist) Reference
CREATE NONCLUSTERED INDEX [IX_MTM_SESSION_SIGNATURE] 
ON [EPS].[MTM_PATIENT_SESSION] ([CHAIN_ID], [ID_SIGNATURE])
INCLUDE ([ID], [SCORE], [STATUS], [RUN_DATE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Status-based Filtering (for pending/incomplete sessions)
CREATE NONCLUSTERED INDEX [IX_MTM_SESSION_STATUS] 
ON [EPS].[MTM_PATIENT_SESSION] ([CHAIN_ID], [STATUS])
INCLUDE ([ID], [SCORE], [RUN_DATE], [ID_SIGNATURE])
WHERE [STATUS] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Date-based Reporting
CREATE NONCLUSTERED INDEX [IX_MTM_SESSION_RUNDATE] 
ON [EPS].[MTM_PATIENT_SESSION] ([RUN_DATE], [CHAIN_ID])
INCLUDE ([ID], [SCORE], [STATUS])
WHERE [RUN_DATE] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- ROW compression for transactional table
ALTER TABLE [EPS].[MTM_PATIENT_SESSION] 
SET (COMPRESSION = ROW);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[DEFERRABLE_FK_WARNING] This table contains 2 DEFERRABLE INITIALLY DEFERRED foreign keys:
  
  1. MTM_PATIENT_SESSION_FK_ESCHAIN → SEC_ADMIN.EPS_SEC_CHAIN (CHAIN_NHIN_ID)
     Chain/customer reference
     
  2. MTM_PATIENT_SESSION_FK_SIGN → EPS.SIGNATURE (CHAIN_ID, ID)
     Composite FK: Pharmacist who conducted session (must be within same chain)
  
  Azure SQL behavior: Constraints are IMMEDIATE (not deferrable)
  
  IMPACT: Application code creating MTM sessions must ensure:
    BEGIN TRANSACTION;
    -- 1. Verify SIGNATURE exists first
    SELECT 1 FROM [EPS].[SIGNATURE] WHERE [CHAIN_ID] = @chainId AND [ID] = @signatureId;
    -- 2. Then create MTM_PATIENT_SESSION
    INSERT INTO [EPS].[MTM_PATIENT_SESSION] (...) VALUES (...);
    COMMIT;
  
  RISK: Out-of-order operations will fail with FK violation
  ACTION REQUIRED: Code audit for deferred constraint dependencies
  
  See CRITICAL_FIX_SCRIPTS.sql for validation and remediation

[SIGNATURE_INTEGRITY] Composite FK on (CHAIN_ID, ID_SIGNATURE):
  Ensures pharmacist belongs to same chain as session
  Prevents cross-chain MTM consultations (organizational policy enforcement)
  
  VALIDATION: All signatures referenced must exist:
  SELECT COUNT(*) as [OrphanSignatures]
  FROM [EPS].[MTM_PATIENT_SESSION] S
  LEFT JOIN [EPS].[SIGNATURE] SG 
    ON S.[CHAIN_ID] = SG.[CHAIN_ID] AND S.[ID_SIGNATURE] = SG.[ID]
  WHERE SG.[ID] IS NULL;  -- Should return 0

[PARENT_TABLE] MTM_PATIENT_SESSION is parent to MTM_PATIENT_ANSWERS
  - One session can have multiple answer records (1:N relationship)
  - Each answer references back to session
  - Ensure referential integrity during data load:
    Multiple answers per session = normal
    Answers without session = data quality issue

[PARTITIONING_REMOVED] Oracle LIST partitioning by CHAIN_ID removed
  (13 partitions: GEAGLE, ECOM, HANNAF, MEIJER, RXCOM, SHOPKO, STLUKE, FREDS, GUNDER, WEBSCR, DUMMY, MEDSHP, ACMEHQ)
  
  Replaced with composite nonclustered index on CHAIN_ID, ID_SIGNATURE

[STATUS_WORKFLOW] Single-digit status field likely represents:
  0 = Draft/Initiated
  1 = In Progress
  2 = Completed/Submitted
  3 = Reviewed/Approved
  
  Query all distinct statuses to understand workflow states:
  SELECT DISTINCT [STATUS], COUNT(*) as [Count]
  FROM [EPS].[MTM_PATIENT_SESSION]
  GROUP BY [STATUS];
  
  Consider adding check constraint if valid values known:
  ALTER TABLE [EPS].[MTM_PATIENT_SESSION]
  ADD CONSTRAINT [CK_STATUS] CHECK ([STATUS] IN (0, 1, 2, 3));

[SCORE_INTERPRETATION] Numeric(13,4) score field:
  Large precision (13 digits before decimal) supports wide value range
  4 decimal places allow scoring precision (e.g., 7.5000)
  
  Likely values:
  - 0-10: Low/high risk scale
  - 0-100: Percentage scale
  - Risk score from pharmacotherapy assessment tool
  
  Validate score distribution and outliers:
  SELECT 
    MIN([SCORE]), MAX([SCORE]), AVG([SCORE]),
    STDEV([SCORE]) as [StdDeviation]
  FROM [EPS].[MTM_PATIENT_SESSION];
  
  Investigate if outliers are data quality issues or legitimate

[RUN_DATE_HANDLING] Date session was actually conducted
  May differ from LAST_UPDATED (when record was last modified)
  and AUDIT_TIMESTAMP (when modification logged)
  
  Typical flow:
  - RUN_DATE: Pharmacist completes consultation (past or present)
  - LAST_UPDATED: Record last changed in system
  - AUDIT_TIMESTAMP: Change logged to audit table
  
  Validate consistency:
  SELECT COUNT(*) as [BadDates]
  FROM [EPS].[MTM_PATIENT_SESSION]
  WHERE [RUN_DATE] > [LAST_UPDATED];  -- Should be 0

[SIZE_ESTIMATE] ~100-200 MB (MTM-participating patients, much smaller than audit table)

[EXPECTED_QUERIES]
  1. Pending/incomplete sessions (STATUS != 2):
     SELECT [CHAIN_ID], COUNT(*) as [PendingSessions]
     FROM [EPS].[MTM_PATIENT_SESSION]
     WHERE [STATUS] < 2
     GROUP BY [CHAIN_ID];
  
  2. Pharmacist workload:
     SELECT [ID_SIGNATURE], COUNT(*) as [SessionsCompleted]
     FROM [EPS].[MTM_PATIENT_SESSION]
     WHERE [RUN_DATE] >= DATEADD(MONTH, -1, GETDATE())
     GROUP BY [ID_SIGNATURE]
     ORDER BY [SessionsCompleted] DESC;
  
  3. Risk stratification:
     SELECT 
       CASE WHEN CAST([SCORE] AS FLOAT) < 5 THEN 'Low'
            WHEN CAST([SCORE] AS FLOAT) < 7 THEN 'Medium'
            ELSE 'High' END as [RiskLevel],
       COUNT(*) as [PatientCount]
     FROM [EPS].[MTM_PATIENT_SESSION]
     WHERE [SCORE] IS NOT NULL
     GROUP BY CASE WHEN ... END;
*/
