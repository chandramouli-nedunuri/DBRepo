-- ============================================================
-- Azure SQL Schema Conversion for EPS.MTM_PATIENT_ANSWERS
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-25
-- ============================================================

-- TABLE: EPS.MTM_PATIENT_ANSWERS
-- Type: Master Transaction Table with DEFERRABLE Foreign Keys
-- Oracle Partitions: LIST by CHAIN_ID (13 partitions)
-- Purpose: Current MTM patient questionnaire answers (Medication Therapy Management)

CREATE TABLE [EPS].[MTM_PATIENT_ANSWERS] (
    [CHAIN_ID] [int] NOT NULL,
    [ID] [int] NOT NULL,
    [ANSWER_SEQUENCE] [numeric](3, 0) NULL,
    [QUESTION_VERSION] [numeric](10, 0) NULL,
    [RX_COM_QUESTION_NUMBER] [numeric](10, 0) NULL,
    [ID_MTM_PATIENT_SESSION] [int] NOT NULL,
    [ID_AAL] [int] NOT NULL,
    [LAST_UPDATED] [datetime] NULL,
    
    -- FOREIGN KEY CONSTRAINTS
    -- ⚠️ [DEFERRABLE_FK] Both constraints were DEFERRABLE INITIALLY DEFERRED in Oracle
    CONSTRAINT [MTM_PATIENT_ANSWERS_FK_SESS] FOREIGN KEY ([CHAIN_ID], [ID_MTM_PATIENT_SESSION])
        REFERENCES [EPS].[MTM_PATIENT_SESSION] ([CHAIN_ID], [ID]),
    CONSTRAINT [MTM_PATIENT_ANSWERS_FK_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Session Lookup (primary relationship)
CREATE NONCLUSTERED INDEX [IX_MTM_ANSWERS_SESSION] 
ON [EPS].[MTM_PATIENT_ANSWERS] ([CHAIN_ID], [ID_MTM_PATIENT_SESSION])
INCLUDE ([ID], [ANSWER_SEQUENCE], [QUESTION_VERSION], [ID_AAL])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- RX_COM Question Reference
CREATE NONCLUSTERED INDEX [IX_MTM_ANSWERS_RXCOM] 
ON [EPS].[MTM_PATIENT_ANSWERS] ([RX_COM_QUESTION_NUMBER])
INCLUDE ([CHAIN_ID], [ID], [ANSWER_SEQUENCE], [QUESTION_VERSION])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- AAL Audit Trail
CREATE NONCLUSTERED INDEX [IX_MTM_ANSWERS_AAL] 
ON [EPS].[MTM_PATIENT_ANSWERS] ([ID_AAL])
INCLUDE ([CHAIN_ID], [ID], [ID_MTM_PATIENT_SESSION])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- ROW compression for transactional table
ALTER TABLE [EPS].[MTM_PATIENT_ANSWERS] 
SET (COMPRESSION = ROW);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[DEFERRABLE_FK_WARNING] This table contains 2 DEFERRABLE INITIALLY DEFERRED foreign keys:
  
  1. MTM_PATIENT_ANSWERS_FK_SESS → EPS.MTM_PATIENT_SESSION (CHAIN_ID, ID)
     Master-detail relationship: Session is parent, Answers are children
     
  2. MTM_PATIENT_ANSWERS_FK_ESCHAIN → SEC_ADMIN.EPS_SEC_CHAIN (CHAIN_NHIN_ID)
     Referential integrity to chain master
  
  Azure SQL behavior: Constraints are IMMEDIATE (not deferrable)
  
  IMPACT: Application code inserting MTM answers must:
    BEGIN TRANSACTION;
    -- 1. Ensure MTM_PATIENT_SESSION exists
    INSERT INTO EPS.MTM_PATIENT_SESSION (...) VALUES (...);
    -- 2. Then insert MTM_PATIENT_ANSWERS
    INSERT INTO EPS.MTM_PATIENT_ANSWERS (...) VALUES (...);
    COMMIT;
  
  RISK: Any out-of-order inserts will fail with FK violation
  ACTION REQUIRED: Code audit - search for deferred constraint usage
  
  See CRITICAL_FIX_SCRIPTS.sql for validation and remediation

[SESSION_INTEGRITY] Composite FK constraint across (CHAIN_ID, ID):
  Must match exact MTM_PATIENT_SESSION parent
  
  VALIDATION QUERY:
  SELECT COUNT(*) as [OrphanAnswers]
  FROM [EPS].[MTM_PATIENT_ANSWERS] A
  LEFT JOIN [EPS].[MTM_PATIENT_SESSION] S 
    ON A.CHAIN_ID = S.CHAIN_ID AND A.ID_MTM_PATIENT_SESSION = S.ID
  WHERE S.ID IS NULL;  -- Should return 0

[PARTITIONING_REMOVED] Oracle LIST partitioning by CHAIN_ID removed
  (13 partitions: GEAGLE, ECOM, HANNAF, MEIJER, RXCOM, SHOPKO, STLUKE, FREDS, GUNDER, WEBSCR, DUMMY, MEDSHP, ACMEHQ)
  
  Replaced with nonclustered index on CHAIN_ID, ID_MTM_PATIENT_SESSION

[MTM_WORKFLOW] Typical flow:
  1. MTM patient invited, MTM_PATIENT_SESSION record created
  2. Patient completes questionnaire → MTM_PATIENT_ANSWERS records inserted (1+ per session)
  3. MTM consultants review answers → updates to QUESTION_VERSION, ANSWER_SEQUENCE
  4. Audit trail maintained in MTM_PATIENT_ANSWERS_AUDIT
  
  Ensure referential integrity throughout workflow

[SIZE_ESTIMATE] ~150-250 MB (MTM program participants × question count)

[NULLABLE_COLUMNS] Note: ANSWER_SEQUENCE, QUESTION_VERSION nullable
  Implies optional questionnaire fields or incomplete sessions
  Investigate NULL distribution:
  SELECT 
    SUM(CASE WHEN [ANSWER_SEQUENCE] IS NULL THEN 1 ELSE 0 END) as [NullSequence],
    SUM(CASE WHEN [QUESTION_VERSION] IS NULL THEN 1 ELSE 0 END) as [NullVersion]
  FROM [EPS].[MTM_PATIENT_ANSWERS];
*/
