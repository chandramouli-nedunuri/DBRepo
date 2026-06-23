-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_EMERGENCY_CONT_AUDIT_CSD_23800
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_EMERGENCY_CONT_AUDIT_CSD_23800
-- Type: Composite Audit Table (CSD Variant #2 - Conflict-Sensitive Data)
-- Oracle Partitions: LIST by CHAIN_ID (~25 different chains + CSD segregation)
-- Purpose: Audit trail for emergency contact assignments (conflict-sensitive variant)

-- ⚠️ [CSD_VARIANT] This is the SECOND CSD variant detected (First: PATIENT_CARE_PROVIDER_AUDIT_CSD_23800)
-- Different chain set from standard audit table (CSD segregation for legal hold)
-- Nullable AUDIT_TIMESTAMP (differs from standard signature)

CREATE TABLE [EPS].[PATIENT_EMERGENCY_CONT_AUDIT_CSD_23800] (
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
    [AUDIT_TIMESTAMP] [datetime2](6) NULL,  -- ⚠️ Nullable (CSD variant signature)
    [LAST_UPDATED] [datetime2](6) NULL,
    [DELETED] [varchar](1) NULL,
    [CONTACT_LAST_UPDATED] [datetime2](6) NULL
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES (CSD VARIANT)
-- ============================================================
-- Patient Emergency Contacts (CSD variant)
CREATE NONCLUSTERED INDEX [IX_PATIENT_EMERGENCY_CONT_AUDIT_CSD_PATIENT] 
ON [EPS].[PATIENT_EMERGENCY_CONT_AUDIT_CSD_23800] ([ID_PATIENT], [CONTACT_ORDER], [CHAIN_ID])
INCLUDE ([ID], [FIRST_NAME], [LAST_NAME], [PHONE_NUMBER])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Contact Type Lookup (by relationship)
CREATE NONCLUSTERED INDEX [IX_PATIENT_EMERGENCY_CONT_AUDIT_CSD_RELATION] 
ON [EPS].[PATIENT_EMERGENCY_CONT_AUDIT_CSD_23800] ([RELATION], [CHAIN_ID])
INCLUDE ([ID_PATIENT], [FIRST_NAME], [LAST_NAME], [PHONE_NUMBER])
WHERE [RELATION] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- PAGE compression for CSD audit table
ALTER TABLE [EPS].[PATIENT_EMERGENCY_CONT_AUDIT_CSD_23800] 
SET (COMPRESSION = PAGE);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[CSD_VARIANT_ALERT] This is BATCH9-SCRIPT 1 subject (CSD consolidation strategy):
  
  ⚠️ SECOND CSD VARIANT detected across Batches 8-9
  Batch 8: PATIENT_CARE_PROVIDER_AUDIT_CSD_23800
  Batch 9: PATIENT_EMERGENCY_CONT_AUDIT_CSD_23800
  
  Pattern emerging: Multiple CSD variants in PATIENT family
  Decision framework from Batch 8 applies:
    Option A: Keep separate (maintain segregation, ~2x storage)
    Option B: Merge (consolidate, lose conflict isolation)
    Option C: Archive (cold storage, legal hold)
    Option D: Delete (if retention expired)

[EMERGENCY_CONTACT_DOMAIN]
  Patient emergency contacts (designated for crisis notification):
  - CONTACT_ORDER: Priority (1=primary, 2=secondary, 3=tertiary)
  - RELATION: Family relationship (spouse, parent, child, sibling, friend, etc.)
  - PHONE_TYPE: Category (0=home, 1=work, 2=mobile, 3=other)
  - PHONE_NUMBER: Contact phone
  - FIRST_NAME, LAST_NAME: Contact person identification
  
  Workflow:
  1. Patient registers emergency contacts
  2. Contacts stored with priority order (CONTACT_ORDER)
  3. During patient crisis: System calls in priority order
  4. CONTACT_LAST_UPDATED tracks when contacts verified (annual confirmation)
  5. Audit trail records all changes (emergency contact changes tracked for compliance)

[NULLABLE_AUDIT_TIMESTAMP] CSD variant signature:
  Standard audit tables: AUDIT_TIMESTAMP NOT NULL (mandatory)
  CSD variant: AUDIT_TIMESTAMP NULL (optional)
  
  Implication: CSD variant may have loader gaps or async replication lag
  Consider: Investigate data completeness for CSD tables pre-UAT

[CONTACT_ORDER_HIERARCHY]
  CONTACT_ORDER = 1: Primary (call first during emergency)
  CONTACT_ORDER = 2: Secondary (call if primary unreachable)
  CONTACT_ORDER = 3+: Tertiary and beyond
  
  Business logic: Phone system follows order, stops on successful contact
  Validation: Ensure unique CONTACT_ORDER per patient (no duplicates)

[PHONE_TYPE_CODES] (hypothesis):
  0 = Home phone (landline)
  1 = Work phone (employer contact)
  2 = Mobile phone (cell, immediate reach)
  3 = Other (pager, alternate, fax)
  
  Recommend: Validate codes against business rules

[SIZE_ESTIMATE] ~150-250 MB (CSD variant subset)

[COMPLIANCE_CONSIDERATIONS]
  - Emergency contacts HIPAA-sensitive (PII for family members)
  - Contact verification required annually (CONTACT_LAST_UPDATED tracking)
  - Retention: 5+ years (regulatory hold on contact history)
  - Privacy: Restrict access (only pharmacy staff for crisis, not customers)

[CSD_CONSOLIDATION_DECISION] (Required pre-production):
  Similar to Batch 8 PATIENT_CARE_PROVIDER_AUDIT_CSD_23800
  Decision deferred to Data Steward + Legal Team
  See BATCH8-SCRIPT 2 decision framework (applies to all CSD variants)
  
  Recommendation: Develop unified CSD consolidation strategy across Batches 9+
  (Rather than individual table decisions, enterprise-wide CSD policy)

[DATA_QUALITY_VALIDATION]
  ✓ FIRST_NAME + LAST_NAME non-null or identifiable
  ✓ PHONE_NUMBER valid 10-digit format (for US)
  ✓ CONTACT_ORDER unique per patient (no duplicate priorities)
  ✓ CONTACT_LAST_UPDATED <= TODAY() (not future dates)
  ✓ AUDIT_TIMESTAMP can be null (CSD variant pattern)
  ✓ ID_PATIENT references valid PATIENT record

[ORPHANED_CONTACT_VALIDATION]
  SELECT COUNT(*)
  FROM [EPS].[PATIENT_EMERGENCY_CONT_AUDIT_CSD_23800] E
  LEFT JOIN [EPS].[PATIENT] P ON E.[ID_PATIENT] = P.[ID]
  WHERE P.[ID] IS NULL;  -- Should return 0
  
[MIGRATION_RISK] CSD variant consolidation strategy:
  - If keeping separate: Ensure replication sync (standard + CSD variants)
  - If merging: Validate data completeness before merge (no loss)
  - If archiving: Compliance lock required before deletion

[NEXT_ACTION] Batch 9 introduces CSD variant #2
  - Pattern now confirmed (not isolated incident)
  - Recommend: Enterprise-wide CSD consolidation decision
  - Timeline: Defer consolidation until all CSD tables inventoried (Batches 9-15)
*/
