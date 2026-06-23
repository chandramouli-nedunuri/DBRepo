-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_EMERGENCY_CONT_AUDIT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_EMERGENCY_CONT_AUDIT
-- Type: Composite Partitioned Audit Table (Emergency Contacts)
-- Oracle Partitions: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
-- Purpose: Audit trail for emergency contact assignments

CREATE TABLE [EPS].[PATIENT_EMERGENCY_CONT_AUDIT] (
    [CHAIN_ID] [int] NOT NULL,
    [ID] [int] NOT NULL,
    [ID_PATIENT] [int] NOT NULL,
    [PHONE_TYPE] [numeric](3, 0) NULL,
    [PHONE_NUMBER] [varchar](10) NULL,
    [FIRST_NAME] [varchar](20) NULL,
    [LAST_NAME] [varchar](25) NULL,
    [RELATION] [varchar](20) NULL,
    [CONTACT_ORDER] [numeric](2, 0) NULL,
    [ID_AAL] [int] NULL,
    [ID_AUDIT] [int] NULL,
    [AUDIT_TIMESTAMP] [datetime2](6) NOT NULL,
    [LAST_UPDATED] [datetime2](6) NULL,
    [DELETED] [varchar](1) NULL,
    [CONTACT_LAST_UPDATED] [datetime2](6) NULL
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Audit Timestamp Range
CREATE NONCLUSTERED INDEX [IX_PATIENT_EMERGENCY_CONT_AUDIT_TIMESTAMP] 
ON [EPS].[PATIENT_EMERGENCY_CONT_AUDIT] ([AUDIT_TIMESTAMP], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [FIRST_NAME], [LAST_NAME])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Patient Emergency Contact History
CREATE NONCLUSTERED INDEX [IX_PATIENT_EMERGENCY_CONT_AUDIT_PATIENT] 
ON [EPS].[PATIENT_EMERGENCY_CONT_AUDIT] ([ID_PATIENT], [CONTACT_ORDER], [CHAIN_ID])
INCLUDE ([ID], [FIRST_NAME], [LAST_NAME], [PHONE_NUMBER], [AUDIT_TIMESTAMP])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- PAGE compression for audit table
ALTER TABLE [EPS].[PATIENT_EMERGENCY_CONT_AUDIT] 
SET (COMPRESSION = PAGE);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[COMPOSITE_PARTITIONING] Oracle: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
  Recommendation: Post-migration monthly RANGE partitioning:
  
  CREATE PARTITION FUNCTION [PF_PATIENT_EMERGENCY_CONT_AUDIT_MONTHLY](datetime2)
  AS RANGE RIGHT FOR VALUES ('2024-07-01', '2024-08-01', ... '2026-09-01');

[EMERGENCY_CONTACT_AUDIT_TRAIL]
  Tracks all changes to patient emergency contacts:
  - Initial contact registration
  - Priority changes (CONTACT_ORDER modifications)
  - Contact updates (phone number changes, relationship changes)
  - Contact deactivations (DELETED flag)
  - Contact verification (CONTACT_LAST_UPDATED annual confirmation)
  
  Critical for: Compliance audits, dispute resolution, emergency procedure reviews

[CONTACT_VERIFICATION_WORKFLOW]
  Annual verification requirement (HIPAA privacy rule):
  1. System identifies contacts > 12 months old (CONTACT_LAST_UPDATED < TODAY() - 365 days)
  2. Pharmacy staff contacts patient to verify emergency contacts
  3. CONTACT_LAST_UPDATED reset to TODAY()
  4. Changes recorded in audit table (AUDIT_TIMESTAMP updated)
  5. Patient summary report: Current verified contacts
  
  Audit query:
  SELECT [ID_PATIENT], [FIRST_NAME], [LAST_NAME], MAX([CONTACT_LAST_UPDATED]) as [LastVerified]
  FROM [EPS].[PATIENT_EMERGENCY_CONT_AUDIT]
  WHERE [DELETED] IS NULL
  GROUP BY [ID_PATIENT], [FIRST_NAME], [LAST_NAME]
  HAVING MAX([CONTACT_LAST_UPDATED]) < DATEADD(DAY, -365, GETDATE());

[SIZE_ESTIMATE] ~200-400 MB (audit volume, 3-month rolling)

[CONTACT_ORDERING_PRIORITY]
  Business logic for crisis notification:
  1. Call CONTACT_ORDER = 1 (primary)
  2. If no answer after 3 attempts, call CONTACT_ORDER = 2 (secondary)
  3. If no answer after 3 attempts, call CONTACT_ORDER = 3+ (tertiary)
  4. If all unreachable, escalate to pharmacy manager
  
  Validation: Ensure no gaps in CONTACT_ORDER (1, 2, 3 - not 1, 2, 4)

[PHONE_TYPE_DETERMINATION]
  System pre-populates or patient-selected:
  - Home phone: Landline (lower priority, maybe shared line)
  - Work phone: Business hours only (limited availability)
  - Mobile phone: Highest priority (immediate reach, 24/7)
  - Other: Alternative contact (pager, fax, third-party relay)
  
  Insight: Mobile phones should be primary (highest reachability)

[RELATIONSHIP_TYPES]
  RELATION field captures emergency contact relationship:
  - Spouse (HIPAA-disclosed, immediate access)
  - Parent (guardian, adult child context)
  - Child (significant relationship, adult patient)
  - Sibling (family support)
  - Friend (legally authorized contact)
  - Employer (business emergency)
  - Other (organization, emergency service)
  
  Validate: RELATION aligns with PII disclosure rules

[AUDIT_TRAIL_FORENSICS]
  Review audit history for specific patient:
  SELECT [AUDIT_TIMESTAMP], [CONTACT_ORDER], [FIRST_NAME], [LAST_NAME], [PHONE_NUMBER], 
         [RELATION], [DELETED]
  FROM [EPS].[PATIENT_EMERGENCY_CONT_AUDIT]
  WHERE [ID_PATIENT] = @patientID
  ORDER BY [AUDIT_TIMESTAMP] DESC;
  
  Identifies all changes, deletions, re-additions (pattern analysis for fraud/abuse)

[SOFT_DELETE_PRESERVATION]
  DELETED = 'Y' indicates removed contact, but preserved in audit:
  - Patient removed contact (divorce, estrangement)
  - Contact information no longer valid (deceased, unreachable)
  - Duplicate contact (consolidated to current entry)
  
  Audit preservation: Enables compliance review without data loss

[DATA_QUALITY_VALIDATION]
  ✓ FIRST_NAME + LAST_NAME: At least one non-null
  ✓ PHONE_NUMBER: Valid format (10 digits or E.164 international)
  ✓ CONTACT_ORDER: Sequence 1, 2, 3, ... (no gaps)
  ✓ AUDIT_TIMESTAMP: NOT NULL and chronological (each change > previous)
  ✓ CONTACT_LAST_UPDATED <= TODAY(): No future verification dates

[COMPLIANCE_REPORTING]
  HIPAA emergency plan audit:
  SELECT COUNT(DISTINCT [ID_PATIENT]) as [PatientsWithContacts],
         COUNT(DISTINCT [ID_PATIENT]) as [VerifiedPatients]
  FROM [EPS].[PATIENT_EMERGENCY_CONT_AUDIT]
  WHERE [CONTACT_LAST_UPDATED] >= DATEADD(DAY, -365, GETDATE())
  AND [DELETED] IS NULL;
  
  Target: 100% verified contacts (annual confirmation rate)
*/
