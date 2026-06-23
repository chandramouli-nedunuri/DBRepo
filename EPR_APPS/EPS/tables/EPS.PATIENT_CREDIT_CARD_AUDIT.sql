-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_CREDIT_CARD_AUDIT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_CREDIT_CARD_AUDIT
-- Type: Composite Partitioned Audit Table (Payment Cards) - SENSITIVE DATA
-- Oracle Partitions: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
-- Purpose: Audit trail for patient payment card records
-- ⚠️ [PCI-DSS] Contains encrypted TOKEN_NUMBER and FIRST_SIX_DIGITS (payment card credentials)

CREATE TABLE [EPS].[PATIENT_CREDIT_CARD_AUDIT] (
    [CHAIN_ID] [int] NOT NULL,
    [ID] [int] NOT NULL,
    [ID_PATIENT] [int] NOT NULL,
    [SEQUENCE] [numeric](3, 0) NULL,
    [CARD_TYPE] [numeric](3, 0) NULL,
    [CARD_EXPIRE_DATE] [varchar](17) NULL,
    [CARD_NAME] [varchar](64) NULL,
    [CARD_ADDRESS] [varchar](64) NULL,
    [CARD_POSTAL_CODE] [varchar](24) NULL,
    [DISCONTINUE_DATE] [datetime] NULL,
    [DEACTIVATE_DATE] [datetime] NULL,
    [AUTOPAY_MONTHLY_DOLLAR_LIMIT] [numeric](13, 2) NULL,
    [LAST_FOUR_DIGITS] [varchar](4) NULL,
    [TOKEN_NUMBER] [varchar](100) NULL,  -- ⚠️ ENCRYPTED FIELD (Always Encrypted)
    [ID_AAL] [int] NULL,
    [LAST_UPDATED] [datetime] NULL,
    [ID_AUDIT] [int] NULL,
    [AUDIT_TIMESTAMP] [datetime2](6) NOT NULL,
    [PAYMENT_PROCESSOR_TYPE] [numeric](2, 0) NULL,
    [CARD_CITY] [varchar](35) NULL,
    [CARD_STATE] [varchar](2) NULL,
    [CARD_NICK_NAME] [varchar](50) NULL,
    [FIRST_SIX_DIGITS] [varchar](6) NULL,  -- ⚠️ ENCRYPTED FIELD (Always Encrypted)
    [CC_TOKEN_PROVIDER] [varchar](64) NULL
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES (ENCRYPTION-AWARE)
-- ============================================================
-- Audit Timestamp Range (NOTE: Encrypted columns cannot be used in index keys)
CREATE NONCLUSTERED INDEX [IX_PATIENT_CREDIT_CARD_AUDIT_TIMESTAMP] 
ON [EPS].[PATIENT_CREDIT_CARD_AUDIT] ([AUDIT_TIMESTAMP], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [CARD_TYPE], [ID_AUDIT])  -- Non-encrypted columns only
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Patient Credit Card History (audit trail, no encrypted columns)
CREATE NONCLUSTERED INDEX [IX_PATIENT_CREDIT_CARD_AUDIT_PATIENT] 
ON [EPS].[PATIENT_CREDIT_CARD_AUDIT] ([ID_PATIENT], [CHAIN_ID], [AUDIT_TIMESTAMP])
INCLUDE ([ID], [SEQUENCE], [CARD_TYPE], [LAST_FOUR_DIGITS])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- PAGE compression for audit table
ALTER TABLE [EPS].[PATIENT_CREDIT_CARD_AUDIT] 
SET (COMPRESSION = PAGE);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[COMPOSITE_PARTITIONING] Oracle: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
  
  RECOMMENDATION: Post-migration monthly RANGE partitioning:
  
  CREATE PARTITION FUNCTION [PF_PATIENT_CREDIT_CARD_AUDIT_MONTHLY](datetime2)
  AS RANGE RIGHT FOR VALUES ('2024-07-01', '2024-08-01', ... '2026-09-01');
  
  Enables: Fast quarterly payment audit, compliance reporting

[PCI-DSS_COMPLIANCE_CRITICAL]
  This table contains SENSITIVE payment card data:
  - TOKEN_NUMBER: Card token (encrypted representation of full card number)
  - FIRST_SIX_DIGITS: BIN (issuer identification) - encrypted in this implementation
  
  Compliance requirements:
  ✓ TDE: Database Transparent Data Encryption (AT REST)
  ✓ Always Encrypted: Field-level encryption for TOKEN_NUMBER, FIRST_SIX_DIGITS
  ✓ Auditing: SQL Server Audit captures all access to payment card columns
  ✓ RLS: Row-level security restricts access to finance/compliance roles only
  ✓ Network: TLS 1.2 minimum for data in transit
  
  See BATCH6-SCRIPT 1 (PATIENT_CREDIT_CARD PCI-DSS) for full implementation

[ENCRYPTED_FIELDS]
  TOKEN_NUMBER: Encrypted card token (not full card number, just token)
              - Reduces PCI scope (tokenization best practice)
              - Can be masked in PATIENT_CREDIT_CARD_VIEW for non-PCI access
  
  FIRST_SIX_DIGITS: BIN/issuer identification, encrypted for defense-in-depth
                   - VISA (4), Mastercard (5), AMEX (3), Discover (6)
                   - Required for transaction routing, encrypted for privacy

[PAYMENT_CARD_LIFECYCLE]
  1. Patient enrolls autopay (CC captured, tokenized)
  2. SEQUENCE field tracks multiple cards per patient (1st, 2nd backup)
  3. CARD_TYPE = Payment processor card type (0=cc, 1=debit, 2=ach, etc.)
  4. AUTOPAY_MONTHLY_DOLLAR_LIMIT: Max monthly charges (fraud protection)
  5. DISCONTINUE_DATE: Customer no longer uses (not deleted, archived)
  6. DEACTIVATE_DATE: Disabled due to failed charge/fraud (soft-disable)
  7. Audit trail tracks every change for compliance investigation

[LAST_FOUR_DIGITS_UTILITY]
  Used for:
  - Customer service (verify "Is this ending in 4242?" before processing)
  - Statement display (last 4 digits + CARD_TYPE tell customer which card charged)
  - Fraud detection (unexpected card-type change)
  
  Public information (not PCI-sensitive), can assist with customer verification

[PAYMENT_PROCESSOR_TYPE]
  Likely codes:
  0 = Internal EPS system
  1 = Stripe
  2 = Square
  3 = PayPal
  4 = Authorize.Net
  5 = Chase Payable
  
  Different processor = different tokenization scheme, validation rules

[CARD_ADDRESS_VALIDATION]
  [CARD_ADDRESS], [CARD_CITY], [CARD_STATE], [CARD_POSTAL_CODE]
  Address Verification Service (AVS) fields
  
  AVS validation during capture:
  - Matches against bank records for fraud detection
  - Failed AVS = potential fraud, requires investigation
  
  COMPLIANCE: Store AVS results for chargeback defense

[AUTOPAY_RISK_MANAGEMENT]
  AUTOPAY_MONTHLY_DOLLAR_LIMIT: Customer-set or system-generated cap
  Prevents: Runaway chargers from fraud/data breach
  
  Example: Patient sets $100 limit, system rejects charges > $100
  (Legitimate refills are typically under limit)

[ENCRYPTION_REQUIREMENTS_POST-MIGRATION]
  1. Create Asymmetric Key or Symmetric Key for Always Encrypted
  2. Create Encrypted Column Master Key (CMK) in Key Vault
  3. Configure Column Encryption Key (CEK) with CMK
  4. Re-encrypt TOKEN_NUMBER and FIRST_SIX_DIGITS columns
  5. Create encrypted column definitions in application connection strings
  
  Timeline: 2-4 hours encryption setup + testing

[SIZE_ESTIMATE] ~400-600 MB (payment card audit, 13 chains × 3 months rolling)

[DATA_RETENTION] Payment card data retention:
  Federal: 5-7 years (for chargeback defense, dispute resolution)
  Industry: PCI-DSS recommends 2 years minimum
  Best practice: 7 years (statute of limitations for financial disputes)
  
  Archive older than 5 years to separate encrypted storage

[MASKED_VIEW_CREATION] (Alternative to Always Encrypted)
  If Always Encrypted unavailable, create masked view:
  
  CREATE VIEW [EPS].[PATIENT_CREDIT_CARD_AUDIT_MASKED] AS
  SELECT 
    [ID], [ID_PATIENT], [SEQUENCE], [CARD_TYPE],
    CASE WHEN IS_MEMBER('finance_role') = 1 THEN [TOKEN_NUMBER] ELSE '***' END as [TOKEN_NUMBER],
    CASE WHEN IS_MEMBER('finance_role') = 1 THEN [FIRST_SIX_DIGITS] ELSE '***' END as [FIRST_SIX_DIGITS],
    [LAST_FOUR_DIGITS], [CARD_NAME], [AUTOPAY_MONTHLY_DOLLAR_LIMIT],
    [DEACTIVATE_DATE], [DISCONTINUE_DATE], [AUDIT_TIMESTAMP]
  FROM [EPS].[PATIENT_CREDIT_CARD_AUDIT];
  
  Restricts sensitive data to finance role, auditors see masked values

[COMPLIANCE_CHECKLIST]
  □ TDE enabled on database
  □ Always Encrypted configured for TOKEN_NUMBER, FIRST_SIX_DIGITS
  □ SQL Server Audit configured for PCI table access
  □ RLS policy restricts to finance/compliance users only
  □ Data retention policy set (5-7 years minimum)
  □ Encryption key backups in secure location
  □ Application tested with encrypted columns
  □ UAT testing for TPP (Third-Party Processor) data flow
  □ Security team sign-off pre-production
  
  See BATCH6-SCRIPT 1 for complete implementation details

[PCI_SCOPE_REDUCTION] Tokenization strategy:
  ✓ Full card number NEVER stored (tokenization immediately)
  ✓ Only token stored (reduces PCI scope significantly)
  ✓ Token encrypted (defense-in-depth)
  ✓ View masked for non-finance users (application security)
  
  Estimated PCI effort reduction: 60-70% scope reduction vs. full card storage
*/
