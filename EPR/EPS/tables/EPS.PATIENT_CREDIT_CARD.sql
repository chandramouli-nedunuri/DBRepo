-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_CREDIT_CARD
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_CREDIT_CARD
-- Type: Master Transaction Table (Payment Cards) - SENSITIVE DATA
-- Oracle Partitions: LIST by CHAIN_ID (13 partitions)
-- Purpose: Active patient autopay credit card registrations
-- ⚠️ [PCI-DSS] Contains encrypted TOKEN_NUMBER and FIRST_SIX_DIGITS (payment card credentials)

CREATE TABLE [EPS].[PATIENT_CREDIT_CARD] (
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
    [PAYMENT_PROCESSOR_TYPE] [numeric](2, 0) NULL,
    [CARD_CITY] [varchar](35) NULL,
    [CARD_STATE] [varchar](2) NULL,
    [CARD_NICK_NAME] [varchar](50) NULL,
    [FIRST_SIX_DIGITS] [varchar](6) NULL,  -- ⚠️ ENCRYPTED FIELD (Always Encrypted)
    [CC_TOKEN_PROVIDER] [varchar](64) NULL,
    
    CONSTRAINT [PATIENT_CREDIT_CARD_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES (ENCRYPTION-AWARE)
-- ============================================================
-- Patient Credit Card Lookup (autopay records managed by patient)
-- NOTE: Indexes cannot include encrypted columns (TOKEN_NUMBER, FIRST_SIX_DIGITS)
CREATE NONCLUSTERED INDEX [IX_PATIENT_CREDIT_CARD_PATIENT] 
ON [EPS].[PATIENT_CREDIT_CARD] ([ID_PATIENT], [SEQUENCE], [CHAIN_ID])
INCLUDE ([ID], [LAST_FOUR_DIGITS], [CARD_TYPE], [DEACTIVATE_DATE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Last Four Digits (for customer verification - non-sensitive)
CREATE NONCLUSTERED INDEX [IX_PATIENT_CREDIT_CARD_LASTFOUR] 
ON [EPS].[PATIENT_CREDIT_CARD] ([LAST_FOUR_DIGITS], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [CARD_TYPE])
WHERE [LAST_FOUR_DIGITS] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- ROW compression for credit card table
ALTER TABLE [EPS].[PATIENT_CREDIT_CARD] 
SET (COMPRESSION = ROW);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[PRIMARY_KEY] Composite key: (CHAIN_ID, ID)
  Ensures one unique credit card record per chain per ID

[PCI-DSS_SENSITIVITY] This is the MOST SENSITIVE table in the schema:
  Payment card data = highest regulatory concern
  
  Compliance: Must implement BATCH6-SCRIPT 1 before production use
  
  Key requirements:
  ✓ TDE (Transparent Data Encryption) for entire database
  ✓ Always Encrypted for TOKEN_NUMBER and FIRST_SIX_DIGITS
  ✓ SQL Server Audit enabled for all access
  ✓ Row-Level Security (RLS) restricting to finance/admin roles
  ✓ Tokenization (no full card numbers stored, only tokens)

[AUTOPAY_FEATURES]
  1. Patient enrolls: Provides card details (name, address, expiration)
  2. Token generation: Full card number tokenized immediately
  3. Recurring charges: System uses TOKEN_NUMBER for autopay
  4. Limit enforcement: AUTOPAY_MONTHLY_DOLLAR_LIMIT caps charges
  5. Card management: Patient can change/disable/delete cards
  6. Audit trail: Every change logged in PATIENT_CREDIT_CARD_AUDIT

[ENCRYPTION_IMPLEMENTATION]
  TOKEN_NUMBER and FIRST_SIX_DIGITS must be encrypted using Always Encrypted:
  
  -- Create Column Master Key (one-time)
  CREATE COLUMN MASTER KEY cmk_eprdb
    WITH ( KEY_STORE_PROVIDER_NAME = 'MSSQL_CERTIFICATE_STORE', KEY_PATH = '...' );
  
  -- Create Column Encryption Key
  CREATE COLUMN ENCRYPTION KEY cek_payment
    WITH VALUES ( COLUMN_MASTER_KEY = cmk_eprdb, ALGORITHM = 'RSA_OAEP', ENCRYPTED_VALUE = ... );
  
  -- Alter column to encrypted
  ALTER TABLE [EPS].[PATIENT_CREDIT_CARD]
  ALTER COLUMN [TOKEN_NUMBER] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS ENCRYPTED WITH (...);
  
  Note: Encryption is complex; coordinate with security team and database admins

[PAYMENT_PROCESSOR_INTEGRATION]
  CC_TOKEN_PROVIDER: Payment processor identifier
  Example: 'STRIPE', 'SQUARE', 'AUTHORIZENET'
  
  Each processor has different:
  - Token format (varies in length/structure)
  - Validation rules
  - Authorization flows
  - Webhook/callback formats
  
  Application must route based on processor type

[CARD_EXPIRATION_HANDLING]
  [CARD_EXPIRE_DATE]: Stored as VARCHAR (not DATE) because format may vary
  Examples: 'MM/YYYY', 'MM/DD/YYYY', '2026-12-31'
  
  Parse application-side; don't rely on database parsing

[AUTOPAY_MONTHLY_LIMIT] Fraud protection mechanism:
  - Patient sets maximum (or system default $500, $1000, etc.)
  - System silently rejects charges exceeding limit
  - Over-limit charge triggers alert for customer service review
  
  Example usage:
  IF (charge_amount > [AUTOPAY_MONTHLY_DOLLAR_LIMIT])
    THEN REJECT_CHARGE and NOTIFY_PATIENT;

[CARD_DEACTIVATION] DEACTIVATE_DATE flags card unusable:
  Triggers:
  - Failed charge (insufficient funds, expired card)
  - Fraud detection (suspicious activity pattern)
  - Customer request (lost card)
  
  Soft-disable (not deleted) allows forensic investigation

[PARTITIONING_REMOVED] Oracle LIST partitioning by CHAIN_ID removed
  Replaced with clustered PK on (CHAIN_ID, ID)

[SIZE_ESTIMATE] ~50-100 MB (active credit cards, much smaller than audit table)
  Typically 30-50% of patient base enrolled in autopay

[SEQUENCE_FIELD]
  Stores patient's preferred card order:
  SEQUENCE = 1: Primary autopay card
  SEQUENCE = 2: Backup card (charged if primary fails)
  SEQUENCE = 3: Tertiary card
  
  Query active primary card:
  SELECT * FROM [EPS].[PATIENT_CREDIT_CARD]
  WHERE [ID_PATIENT] = @patientID AND [SEQUENCE] = 1 
    AND [DEACTIVATE_DATE] IS NULL AND [DISCONTINUE_DATE] IS NULL;

[ACCESS_CONTROL_EXAMPLE]
  CREATE ROLE finance_admin;
  CREATE ROLE patient_service;
  
  GRANT SELECT ON [EPS].[PATIENT_CREDIT_CARD] TO finance_admin;
  GRANT SELECT ([ID_PATIENT], [SEQUENCE], [LAST_FOUR_DIGITS], [CARD_TYPE]) 
    ON [EPS].[PATIENT_CREDIT_CARD] TO patient_service;  -- Limited columns
  
  Patient Service view only last-4 digits, not full tokens

[ORPHANED_RECORD_CHECK]
  SELECT COUNT(*) as [OrphanCards]
  FROM [EPS].[PATIENT_CREDIT_CARD] CC
  LEFT JOIN [EPS].[PATIENT] P ON CC.[ID_PATIENT] = P.[ID]
  WHERE P.[ID] IS NULL;  -- Should return 0

[PCI_COMPLIANCE_VALIDATION_SCRIPT]
  See BATCH6-SCRIPT 1 for:
  - TDE enablement verification
  - Always Encrypted column validation
  - SQL Server Audit configuration
  - RLS policy testing
  - Masked view creation (non-PCI access)
  - Post-deployment checklist (15-point validation)

[PRODUCTION_READINESS] CRITICAL GATES:
  □ Security team approval (TDE + Always Encrypted architecture)
  □ DBA sign-off (encryption key management, backup strategy)
  □ Compliance team approval (PCI-DSS attestation)
  □ Application testing with encrypted columns (connection strings updated)
  □ UAT with actual payment processor (tokenization validation)
  □ Network penetration testing (in-transit encryption TLS 1.2+)
  □ Backup/restore testing (encrypted database recovery)
  
  Estimated timeline: 2-4 weeks (with dedicated security team)

[ROLLBACK_PLAN] If encryption fails:
  1. Restore pre-encryption backup
  2. Disable Always Encrypted in application
  3. Restrict database access to minimal roles
  4. Escalate to security team for alternative architecture

[NEXT_STEPS]
  1. Execute BATCH6-SCRIPT 1 (PCI-DSS compliance setup)
  2. Application team: Update connection strings for Always Encrypted
  3. Testing: Load sample cards, verify encryption, test chargebacks
  4. Security review: Pen testing, compliance audit
  5. Production deployment: Staged rollout with rollback plan
*/
