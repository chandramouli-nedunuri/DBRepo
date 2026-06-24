-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_EMERGENCY_CONTACT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_EMERGENCY_CONTACT
-- Type: Master Transaction Table (Emergency Contacts)
-- Oracle Partitions: LIST by CHAIN_ID (~25 extended chains)
-- Purpose: Active emergency contact registry (crisis notification)

CREATE TABLE [EPS].[PATIENT_EMERGENCY_CONTACT] (
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
    [LAST_UPDATED] [datetime2](6) NULL,
    [DELETED] [varchar](1) NULL,
    [CONTACT_LAST_UPDATED] [datetime2](6) NULL,
    
    CONSTRAINT [PATIENT_EMERGENCY_CONTACT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Patient Emergency Contacts (primary lookup)
CREATE NONCLUSTERED INDEX [IX_PATIENT_EMERGENCY_CONTACT_PATIENT] 
ON [EPS].[PATIENT_EMERGENCY_CONTACT] ([ID_PATIENT], [CONTACT_ORDER], [CHAIN_ID])
INCLUDE ([ID], [FIRST_NAME], [LAST_NAME], [PHONE_NUMBER], [PHONE_TYPE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Contact Type (for crisis routing)
CREATE NONCLUSTERED INDEX [IX_PATIENT_EMERGENCY_CONTACT_TYPE] 
ON [EPS].[PATIENT_EMERGENCY_CONTACT] ([PHONE_TYPE], [RELATION], [CHAIN_ID])
INCLUDE ([ID_PATIENT], [FIRST_NAME], [LAST_NAME], [PHONE_NUMBER])
WHERE [DELETED] IS NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- ROW compression for emergency contact registry
ALTER TABLE [EPS].[PATIENT_EMERGENCY_CONTACT] 
SET (COMPRESSION = ROW);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[PRIMARY_KEY] Composite key: (CHAIN_ID, ID)
  Ensures unique emergency contact per chain

[EMERGENCY_RESPONSE_PROTOCOL]
  When patient is hospitalized, unconscious, or in medical crisis:
  1. System retrieves PATIENT_EMERGENCY_CONTACT records
  2. Contacts called in CONTACT_ORDER priority (1→2→3)
  3. Phone system uses [PHONE_TYPE] to determine availability:
     - Mobile: Call anytime (highest priority)
     - Work: Call during business hours only
     - Home: Call during evening/weekend
     - Other: Alternative contact method
  4. Pharmacy staff document contact result (dialed, reached, message left)
  5. Audit trail records crisis notification in PATIENT_EMERGENCY_CONT_AUDIT

[CONTACT_ORDER_VALIDATION]
  Critical business rule: No gaps in CONTACT_ORDER
  Valid: 1, 2, 3, 4, 5 (sequential)
  Invalid: 1, 3, 5 (missing 2, 4)
  
  Validation query:
  WITH ContactRanks AS (
    SELECT [ID_PATIENT], [CONTACT_ORDER], 
           ROW_NUMBER() OVER (PARTITION BY [ID_PATIENT] ORDER BY [CONTACT_ORDER]) as RowNum
    FROM [EPS].[PATIENT_EMERGENCY_CONTACT]
    WHERE [DELETED] IS NULL
  )
  SELECT [ID_PATIENT], [CONTACT_ORDER], RowNum
  FROM ContactRanks
  WHERE [CONTACT_ORDER] <> RowNum;  -- Identifies gaps

[PARTITIONING_REMOVED] Oracle LIST partitioning by CHAIN_ID (~25 chains) removed
  Extended partition set: Similar to PATIENT_CARE_PROVIDER, PATIENT_DOCUMENT
  Index strategy: Unified nonclustered (avoids partition explosion)

[SIZE_ESTIMATE] ~50-100 MB (master table, relatively small)

[VERIFICATION_WORKFLOW] Annual contact verification:
  SELECT [ID_PATIENT], MAX([CONTACT_LAST_UPDATED]) as [LastVerified],
         DATEDIFF(DAY, MAX([CONTACT_LAST_UPDATED]), GETDATE()) as [DaysSinceVerification]
  FROM [EPS].[PATIENT_EMERGENCY_CONTACT]
  WHERE [DELETED] IS NULL
  GROUP BY [ID_PATIENT]
  HAVING MAX([CONTACT_LAST_UPDATED]) < DATEADD(DAY, -365, GETDATE());
  
  Identifies patients requiring contact verification (> 1 year old)

[MULTIPLE_CONTACTS_PATTERN]
  Typical patient may have 2-3 emergency contacts:
  - Contact 1 (primary): Spouse, parent, or best friend
  - Contact 2 (secondary): Sibling or close relative
  - Contact 3 (tertiary): Employer or backup contact
  
  Business rule: Ensure at least 1 contact per patient (regulatory requirement)
  Validation: COUNT of contacts per patient >= 1

[SOFT_DELETE_FOR_REMOVED_CONTACTS]
  When patient changes emergency contacts:
  DELETED = 'Y' marks contact inactive (historical record in audit table)
  
  Example: Divorce scenario
  - Contact 1 (former spouse): DELETED='Y', CONTACT_LAST_UPDATED = divorce date
  - Contact 2 (new spouse): LAST_UPDATED = new registration date
  - Audit table: Both records preserved for legal/historical review

[INTERNATIONAL_PHONE_SUPPORT]
  Current format: VARCHAR(10) US phone (XXXXXXXXXX)
  
  For international expansion (if applicable):
  - Consider E.164 format: +[country code] [number]
    Example: +1-800-555-1234 (10 chars + 6 = 16 max)
  - Current VARCHAR(10) may be insufficient
  - Recommend: Change to VARCHAR(20) post-migration for flexibility

[PII_PROTECTION_CRITICAL]
  Emergency contacts contain HIPAA-protected PII:
  - Names: Personal identifying information
  - Phone numbers: Confidential contact information
  - Relationships: PHI (Protected Health Information)
  
  Access control:
  - Only pharmacy clinical staff (crisis situations)
  - Not accessible to patients online (privacy boundary)
  - Audit logging required (who accessed, when, why)

[EXTENDED_PARTITION_SET] ~25 chains:
  Observation: PATIENT_DOCUMENT, PATIENT_CARE_PROVIDER, PATIENT_EMERGENCY_CONTACT
              all use ~25 chain partitions (vs. standard 13)
  
  Pattern: PATIENT family tables have extended chain set
  Strategy: Unified indexes (no partition-specific indexes)
  Investigation: Batch 9+ should confirm if entire PATIENT suite extended

[DATA_QUALITY_VALIDATION]
  ✓ At least 1 contact per patient (business rule)
  ✓ CONTACT_ORDER sequential (1, 2, 3 without gaps)
  ✓ PHONE_NUMBER format valid (10 digits or E.164)
  ✓ FIRST_NAME + LAST_NAME: At least one non-null
  ✓ CONTACT_LAST_UPDATED <= TODAY() (not future)
  ✓ LAST_UPDATED <= CONTACT_LAST_UPDATED (verification > creation)
  ✓ RELATION in valid list (spouse, parent, child, sibling, friend, employer, other)

[CRISIS_NOTIFICATION_TESTING]
  Pre-production validation:
  1. Load sample patient with multiple emergency contacts
  2. Execute crisis notification workflow (simulate system call)
  3. Verify contacts called in correct CONTACT_ORDER
  4. Verify phone type handling (mobile priority, work hours check, etc.)
  5. Verify audit trail recorded in PATIENT_EMERGENCY_CONT_AUDIT
  6. Test rescheduling (if contact unreachable, move to next)

[ORPHANED_PATIENT_CHECK]
  SELECT COUNT(*)
  FROM [EPS].[PATIENT_EMERGENCY_CONTACT] E
  LEFT JOIN [EPS].[PATIENT] P ON E.[ID_PATIENT] = P.[ID]
  WHERE P.[ID] IS NULL AND E.[DELETED] IS NULL;  -- Should return 0
*/
