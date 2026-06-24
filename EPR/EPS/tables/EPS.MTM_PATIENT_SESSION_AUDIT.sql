-- ============================================================
-- Azure SQL Schema Conversion for EPS.MTM_PATIENT_SESSION_AUDIT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-25
-- ============================================================

-- TABLE: EPS.MTM_PATIENT_SESSION_AUDIT
-- Type: Composite Partitioned Audit Table (MTM Sessions)
-- Oracle Partitions: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
-- Purpose: Audit trail for MTM consultation sessions

CREATE TABLE [EPS].[MTM_PATIENT_SESSION_AUDIT] (
    [CHAIN_ID] [int] NOT NULL,
    [ID] [int] NOT NULL,
    [RUN_DATE] [datetime] NULL,
    [SCORE] [numeric](13, 4) NULL,
    [SCORE_TEXT] [varchar](2000) NULL,
    [STATUS] [numeric](1, 0) NULL,
    [ID_SIGNATURE] [int] NOT NULL,
    [ID_AAL] [int] NOT NULL,
    [LAST_UPDATED] [datetime] NULL,
    [ID_AUDIT] [int] NOT NULL,
    [AUDIT_TIMESTAMP] [datetime2](6) NOT NULL
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Audit Timestamp Range (monthly window queries)
CREATE NONCLUSTERED INDEX [IX_MTM_SESSION_AUDIT_TIMESTAMP] 
ON [EPS].[MTM_PATIENT_SESSION_AUDIT] ([AUDIT_TIMESTAMP], [CHAIN_ID])
INCLUDE ([ID], [ID_SIGNATURE], [ID_AUDIT], [SCORE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Signature Reference (pharmacist/clinician accountability)
CREATE NONCLUSTERED INDEX [IX_MTM_SESSION_AUDIT_SIGNATURE] 
ON [EPS].[MTM_PATIENT_SESSION_AUDIT] ([ID_SIGNATURE], [CHAIN_ID], [AUDIT_TIMESTAMP])
INCLUDE ([ID], [SCORE], [STATUS], [RUN_DATE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Chain-Date-Score Range (rolling performance analysis)
CREATE NONCLUSTERED INDEX [IX_MTM_SESSION_AUDIT_CHAIN_SCORE] 
ON [EPS].[MTM_PATIENT_SESSION_AUDIT] ([CHAIN_ID], [AUDIT_TIMESTAMP])
INCLUDE ([ID], [SCORE], [STATUS], [ID_SIGNATURE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- PAGE compression for audit table
ALTER TABLE [EPS].[MTM_PATIENT_SESSION_AUDIT] 
SET (COMPRESSION = PAGE);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[COMPOSITE_PARTITIONING] Oracle: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
  
  RECOMMENDATION: Implement 24-month rolling monthly RANGE partitioning:
  
  CREATE PARTITION FUNCTION [PF_MTM_SESSION_AUDIT_MONTHLY](datetime2)
  AS RANGE RIGHT FOR VALUES ('2024-07-01', '2024-08-01', ... '2026-09-01');
  
  Enables: Fast quarterly/annual MTM performance reports, sliding window archive

[SCORE_INTERPRETATION] Numeric field [SCORE] (precision 13, scale 4):
  Range: 0.0000 to 9999999999.9999
  
  Clinical interpretation (hypothesis):
  - MTM assessment score (medication-related concerns identified)
  - Value range likely 0-10 or 0-100 (normalize for UI display)
  - NULL indicates session initiated but not completed
  
  Validate distribution:
  SELECT 
    MIN([SCORE]), MAX([SCORE]), AVG([SCORE]), 
    SUM(CASE WHEN [SCORE] IS NULL THEN 1 ELSE 0 END) as [NullCount]
  FROM [EPS].[MTM_PATIENT_SESSION_AUDIT];

[SCORE_TEXT] Text representation of SCORE (free-form commentary/classification)
  May contain:
  - Textual score labels ('Low Risk', 'Medium Risk', 'High Risk')
  - Clinical interpretation ('No concerns', '3 concerns identified', etc.)
  - Pharmacist notes (up to 2000 characters)
  
  Check for sensitive data (duplicate from SCORE field or supplementary detail):
  SELECT DISTINCT [SCORE_TEXT] FROM [EPS].[MTM_PATIENT_SESSION_AUDIT]
  WHERE [SCORE_TEXT] IS NOT NULL
  ORDER BY [SCORE_TEXT];

[STATUS_FLAG] Numeric(1,0) - single-digit status code:
  Expected values: 0, 1 (possibly 2-9 if multi-state workflow)
  
  Likely states:
  - 0 = Draft/Incomplete
  - 1 = Complete/Submitted
  - 2 = Reviewed/Approved
  
  Validate valid values:
  SELECT [STATUS], COUNT(*) FROM [EPS].[MTM_PATIENT_SESSION_AUDIT]
  GROUP BY [STATUS] ORDER BY [STATUS];

[ID_SIGNATURE] References clinician/pharmacist who conducted consultation
  RELATIONSHIP: Links to EPS.SIGNATURE table (pharmacist registry)
  
  REFERENTIAL INTEGRITY: Composite FK in MTM_PATIENT_SESSION parent table
  
  VALIDATION: Check no orphaned signatures:
  SELECT COUNT(DISTINCT A.[ID_SIGNATURE]) as [AuditSignatures],
         COUNT(DISTINCT S.ID) as [ValidSignatures]
  FROM [EPS].[MTM_PATIENT_SESSION_AUDIT] A
  LEFT JOIN [EPS].[SIGNATURE] S ON A.[ID_SIGNATURE] = S.[ID];

[RUN_DATE_SEMANTICS] [RUN_DATE] (nullable datetime):
  Likely interpretations:
  - Date session was executed/conducted
  - Date report was generated
  - Scheduled date for follow-up
  
  NULL values may indicate:
  - Draft sessions (not yet run)
  - Cancelled sessions
  - Pending scheduling
  
  Analyze usage pattern:
  SELECT 
    SUM(CASE WHEN [RUN_DATE] IS NULL THEN 1 ELSE 0 END) as [NullRunDates],
    MAX([RUN_DATE]) as [LatestRun],
    MIN([RUN_DATE]) as [EarliestRun]
  FROM [EPS].[MTM_PATIENT_SESSION_AUDIT];

[SIZE_ESTIMATE] ~500-700 MB (13 chains × 3 months rolling, multiple sessions per patient)

[COMPLIANCE_REPORTING] MTM audit critical for:
  - URAC accreditation (MTM program reporting requirements)
  - Pharmacy compliance documentation
  - Medication therapy interventions tracking
  
  Ensure retention 5+ years for compliance audits

[QUERY PATTERNS FOR BUSINESS INTELLIGENCE]
  1. Pharmacist MTM case load:
     SELECT [ID_SIGNATURE], COUNT(*) as [SessionsPerPharmacist]
     FROM [EPS].[MTM_PATIENT_SESSION_AUDIT]
     WHERE [AUDIT_TIMESTAMP] >= DATEADD(MONTH, -3, GETDATE())
     GROUP BY [ID_SIGNATURE];
  
  2. MTM risk distribution by chain:
     SELECT [CHAIN_ID], 
            AVG(CAST([SCORE] AS FLOAT)) as [AvgScore],
            SUM(CASE WHEN CAST([SCORE] AS FLOAT) > 5 THEN 1 ELSE 0 END) as [HighRisk]
     FROM [EPS].[MTM_PATIENT_SESSION_AUDIT]
     GROUP BY [CHAIN_ID];
*/
