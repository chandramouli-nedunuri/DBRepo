# Comprehensive Partition Strategy by Table
## EPS Schema Migration: Oracle to Azure SQL

**Analysis Date:** June 26, 2026  
**Total Tables Analyzed:** 128 tables  
**- Partition-only tables:** 73  
**- Composite subpartition tables:** 55  

---

## STRATEGIC GROUPING & RECOMMENDATIONS

### EXECUTIVE SUMMARY

The 128 EPS tables fall into **3 clear categories** with distinct conversion strategies:

| Category | # Tables | Partitioning Type | Strategy | Rationale |
|----------|----------|-------------------|----------|-----------|
| **A** | 73 | Master/Transaction (LIST on CHAIN_ID) | **PARTITION BY CHAIN_ID** | Business entity partitioning; direct Oracle conversion |
| **B** | 50 | Audit (LIST×RANGE composite) | **PARTITION BY AUDIT_TIMESTAMP** | Time-series retention; archive/purge critical |
| **C** | 5 | Special Audit (Small/Low-Volume) | **PARTITION BY AUDIT_TIMESTAMP** or **INDEX-ONLY** | Low volume; simpler retention; optional partitioning |

---

## CATEGORY A: PARTITION BY CHAIN_ID
### Master & Transactional Data (73 tables)

**Strategy:** PARTITION BY CHAIN_ID (6 value ranges)  
**Rationale:** 
- Master data naturally organized by business entity (pharmacy chain)
- Direct Oracle LIST conversion
- Supports per-chain queries (most common)
- Per-chain maintenance windows feasible

**Partition Boundaries:**
```
P1: CHAIN_ID ≤ 1,000
P2: 1,000 < CHAIN_ID ≤ 5,000
P3: 5,000 < CHAIN_ID ≤ 50,000
P4: 50,000 < CHAIN_ID ≤ 100,000
P5: 100,000 < CHAIN_ID ≤ 130,000
P6: CHAIN_ID > 130,000
```

### Category A Tables (73 total)

#### A1: HIGH-PRIORITY (Large, Critical Tables)
These tables should be partitioned first; highest query volume expected:

| Table Name | Partition Count | Purpose | Priority | Index Strategy |
|-----------|-----------------|---------|----------|-----------------|
| **PATIENT** | 163 | Core patient master | ⭐⭐⭐ | Index on (CHAIN_ID, PATIENT_ID, DOB) |
| **RX_TX** | 163 | Rx transaction master | ⭐⭐⭐ | Index on (CHAIN_ID, RX_DATE, STATUS) |
| **PRESCRIBER** | 163 | Prescriber master | ⭐⭐⭐ | Index on (CHAIN_ID, PRESCRIBER_ID, DEA) |
| **ADDRESS** | 163 | Patient/Prescriber addresses | ⭐⭐⭐ | Index on (CHAIN_ID, ADDRESS_TYPE) |
| **MRN** | 163 | Medical record numbers | ⭐⭐⭐ | Index on (CHAIN_ID, MRN, PATIENT_ID) |
| **CARD** | 163 | Insurance cards | ⭐⭐ | Index on (CHAIN_ID, CARD_ID) |
| **PAYMENT** | 163 | Payment transactions | ⭐⭐ | Index on (CHAIN_ID, PAYMENT_DATE) |
| **LINE_ITEM** | 163 | Rx line items | ⭐⭐ | Index on (CHAIN_ID, RX_ID) |
| **ALLERGY** | 163 | Patient allergies | ⭐⭐ | Index on (CHAIN_ID, PATIENT_ID) |
| **DISEASE** | 163 | Patient medical conditions | ⭐⭐ | Index on (CHAIN_ID, PATIENT_ID) |

**Implementation Priority:** PHASE 1 (Week 1-2 of implementation)

```sql
-- Template for all Category A High-Priority tables
CREATE PARTITION FUNCTION pf_ADDRESS_ChainID (INT)
AS RANGE LEFT FOR VALUES (1000, 5000, 50000, 100000, 130000);

CREATE PARTITION SCHEME ps_ADDRESS_ChainID
AS PARTITION pf_ADDRESS_ChainID ALL TO ([PRIMARY]);

CREATE CLUSTERED INDEX CIX_ADDRESS_CHAINID
ON EPS.ADDRESS (CHAIN_ID, ADDRESS_ID)
ON ps_ADDRESS_ChainID(CHAIN_ID);

CREATE NONCLUSTERED INDEX NIX_ADDRESS_TYPE
ON EPS.ADDRESS (ADDRESS_TYPE, CHAIN_ID)
ON ps_ADDRESS_ChainID(CHAIN_ID);
```

---

#### A2: MEDIUM-PRIORITY (Moderate-Size Tables)
Standard operational tables; moderate query volume:

| Table Name | Partition Count | Purpose | Index Strategy |
|-----------|-----------------|---------|-----------------|
| PATIENT_CARE_PROVIDER | 164 | Care provider associations | Index on (CHAIN_ID, PROVIDER_ID) |
| TELEPHONE | 163 | Phone numbers | Index on (CHAIN_ID, PATIENT_ID) |
| EMAIL | 163 | Email addresses | Index on (CHAIN_ID, PATIENT_ID) |
| PRESCRIBER | 163 | Prescriber data | Index on (CHAIN_ID, DEA_NUMBER) |
| MEDICAL_CONDITION | 163 | Medical conditions | Index on (CHAIN_ID, CONDITION_CODE) |
| FREE_FORM_ALLERGY | 163 | Allergy text | Index on (CHAIN_ID, PATIENT_ID) |
| FDB_PATIENT_ALLERGY | 163 | FDB allergy data | Index on (CHAIN_ID, PATIENT_ID) |
| COMPOUND_INGREDIENTS | 163 | Rx ingredients | Index on (CHAIN_ID, RX_ID) |
| PACKAGE_INFO | 163 | Package information | Index on (CHAIN_ID, PACKAGE_ID) |
| SIGNATURE | 163 | Patient signatures | Index on (CHAIN_ID, PATIENT_ID) |
| PATIENT_EMERGENCY_CONTACT | 163 | Emergency contacts | Index on (CHAIN_ID, PATIENT_ID) |
| PATIENT_CREDIT_CARD | 163 | Credit cards | Index on (CHAIN_ID, PATIENT_ID) |
| PATIENT_DOCUMENT | 163 | Documents | Index on (CHAIN_ID, PATIENT_ID) |
| PATIENT_PROGRAM | 163 | Patient programs | Index on (CHAIN_ID, PATIENT_ID) |
| PATIENT_PROGRAM_CONTACT | 163 | Program contacts | Index on (CHAIN_ID, PROGRAM_ID) |
| PRIOR_ADVERSE_REACTION | 163 | Adverse reactions | Index on (CHAIN_ID, PATIENT_ID) |
| ALT_PRESCRIBER | 163 | Alternative prescribers | Index on (CHAIN_ID, PRESCRIBER_ID) |
| FOLLOW_UP_PRESCRIBER | 163 | Follow-up prescribers | Index on (CHAIN_ID, PRESCRIBER_ID) |
| COUNSELING_NOTES | 163 | Counseling notes | Index on (CHAIN_ID, PATIENT_ID) |
| PATIENT_NOTES | 163 | Patient notes | Index on (CHAIN_ID, PATIENT_ID) |
| VIAL_INFO | 163 | Vial information | Index on (CHAIN_ID, VIAL_ID) |
| TX_LOT | 163 | Transaction lots | Index on (CHAIN_ID, LOT_NUMBER) |
| KP_RXNUM_REF | 163 | Rx number references | Index on (CHAIN_ID, RX_NUMBER) |
| TP_LINK | 163 | Third-party links | Index on (CHAIN_ID, TP_ID) |
| INTAKE_SOURCES | 163 | Intake sources | Index on (CHAIN_ID, SOURCE_ID) |
| MATCH_KEY | 163 | Matching keys | Index on (CHAIN_ID, MATCH_KEY) |
| IDGEN | 163 | ID generation | Index on (CHAIN_ID, ID_TYPE) |
| RENAL_MEASUREMENT | 163 | Renal measurements | Index on (CHAIN_ID, PATIENT_ID) |

**Implementation Priority:** PHASE 2 (Week 3-4)

**All use same partition scheme:** `ps_ChainID` (shared across all CATEGORY A tables)

---

#### A3: LOWER-PRIORITY (Specialized/Lookup Tables)
Smaller operational tables; can use shared partition scheme:

| Table Name | Partition Count | Purpose |
|-----------|-----------------|---------|
| MOD_PCM | 163 | Medication modification |
| MTM_PATIENT_ANSWERS | 163 | MTM questionnaire answers |
| MTM_PATIENT_SESSION | 163 | MTM session data |
| PATIENT_MO_CONSENT | 162 | Mobile opt-in consent |
| PATIENT_NOTIFY_SCHEDULE | 162 | Notification schedules |
| PATIENT_AR_ACCOUNT | 162 | A/R accounts |
| RX_TX_DIAGNOSIS_CODES | 163 | Diagnosis code mappings |
| RX_TX_DUR_LIST | 163 | DUR interaction lists |
| RX_TX_PAYMENT | 163 | Rx payment details |
| RX_TX_SIG_STRUCTURED_PART | 163 | Structured signature parts |
| FDB_PAT_ALLERGY_REACTION | 163 | FDB reaction details |
| PATIENT_SIGNATURES | 163 | Digital signatures |
| PA_NUM | 163 | Prior authorization numbers |
| QUEUECOMMAND | 163 | Queue commands |
| PATIENT_UNMERGE_LOCK | 163 | Patient merge locks |
| PATIENT_MO_CONSENT_AUDIT | 54 | Audit trail for consent |
| VISUALLY_IMPAIRED_DETAIL | 163 | Accessibility features |
| WORKMANS_COMP | 163 | Workers comp data |
| COMPOUND_INGREDIENT_LOT | 158 | Compound ingredient lots |
| TX_CRED | 163 | Transaction credits |
| TX_TP | 163 | Third-party transactions |
| VERSION | 163 | Version tracking |

**Implementation Priority:** PHASE 3 (Week 5+)

**Note:** These can share partition scheme with Category A1 tables for consistency

---

### CATEGORY A: Implementation Template

```sql
-- STEP 1: Create single shared partition function (ONE TIME)
CREATE PARTITION FUNCTION pf_ChainID_EPS (INT)
AS RANGE LEFT FOR VALUES (1000, 5000, 50000, 100000, 130000);

-- STEP 2: Create single shared partition scheme (ONE TIME)
CREATE PARTITION SCHEME ps_ChainID_EPS
AS PARTITION pf_ChainID_EPS ALL TO ([PRIMARY]);

-- STEP 3: Apply to each table (REPEAT for all 73 tables)
-- Example: PATIENT table
ALTER TABLE EPS.PATIENT
DROP CONSTRAINT PK_PATIENT; -- Drop existing PK

ALTER TABLE EPS.PATIENT
ADD CONSTRAINT PK_PATIENT 
PRIMARY KEY (PATIENT_ID, CHAIN_ID)
ON ps_ChainID_EPS(CHAIN_ID);

CREATE CLUSTERED INDEX CIX_PATIENT_CHAINID
ON EPS.PATIENT (CHAIN_ID, PATIENT_ID)
ON ps_ChainID_EPS(CHAIN_ID);

-- Add supporting indexes
CREATE NONCLUSTERED INDEX NIX_PATIENT_DOB
ON EPS.PATIENT (DOB, CHAIN_ID)
ON ps_ChainID_EPS(CHAIN_ID);
```

---

## CATEGORY B: PARTITION BY AUDIT_TIMESTAMP
### Composite Audit Tables (50 tables)

**Strategy:** PARTITION BY AUDIT_TIMESTAMP (6-8 weekly ranges)  
**Rationale:**
- Audit tables are time-series data
- Retention is date-driven ("Keep last 90 days")
- Partition switching enables fast archive/purge
- Typical queries: "Show audits from last 7 days"
- All have 163 primary partitions × 489+ subpartitions in Oracle

**Partition Boundaries (Weekly):**
```
P1: AUDIT_TIMESTAMP < 2026-06-15
P2: AUDIT_TIMESTAMP < 2026-06-22
P3: AUDIT_TIMESTAMP < 2026-06-29
P4: AUDIT_TIMESTAMP < 2026-07-06
P5: AUDIT_TIMESTAMP < 2026-07-13
P6: AUDIT_TIMESTAMP < 2026-07-20
P7: AUDIT_TIMESTAMP < 2026-07-27
P8: AUDIT_TIMESTAMP >= 2026-07-27
```

### Category B Tables (50 total)

#### B1: HIGH-VOLUME AUDIT (Critical retention requirement)
Large audit tables with 6,031 subpartitions (38-day data):

| Table Name | Partitions | Subpartitions | Purpose | Daily Volume |
|-----------|-----------|---|---------|---------------|
| **AUDIT_ACCESS_LOG** | 163 | 6,031 | System access audit trail | ⭐⭐⭐ Very High |
| **AUDIT_MESSAGE_CONTENT** | 163 | 6,031 | Message content audit | ⭐⭐⭐ Very High |

**Implementation Priority:** PHASE 1 (These are critical!)

```sql
-- STEP 1: Create partition function for high-volume audit
CREATE PARTITION FUNCTION pf_AUDIT_TS_WEEKLY (DATETIME2)
AS RANGE RIGHT FOR VALUES (
    '2026-06-15', '2026-06-22', '2026-06-29', 
    '2026-07-06', '2026-07-13', '2026-07-20', '2026-07-27'
);

-- STEP 2: Create partition scheme
CREATE PARTITION SCHEME ps_AUDIT_TS_WEEKLY
AS PARTITION pf_AUDIT_TS_WEEKLY ALL TO ([PRIMARY]);

-- STEP 3: Apply to AUDIT_ACCESS_LOG (highest priority)
CREATE CLUSTERED INDEX CIX_AUDIT_ACCESS_LOG_TS
ON EPS.AUDIT_ACCESS_LOG (AUDIT_TIMESTAMP, CHAIN_ID)
ON ps_AUDIT_TS_WEEKLY(AUDIT_TIMESTAMP);

-- STEP 4: Create supporting index for chain queries
CREATE NONCLUSTERED INDEX NIX_AUDIT_ACCESS_LOG_CHAIN
ON EPS.AUDIT_ACCESS_LOG (CHAIN_ID, AUDIT_TIMESTAMP)
INCLUDE (ACTION, USER_ID);

-- STEP 5: Archive strategy - switch old partition weekly
ALTER TABLE EPS.AUDIT_ACCESS_LOG
SWITCH PARTITION 1 TO EPS.AUDIT_ACCESS_LOG_ARCHIVE;
```

**Archive & Retention Procedure:**
```sql
-- Every Sunday: Archive last week's data
ALTER TABLE EPS.AUDIT_ACCESS_LOG
SWITCH PARTITION 1 TO EPS.AUDIT_ACCESS_LOG_WEEKLY_ARCHIVE_062626;

-- Purge data older than 90 days (automated job)
DROP TABLE EPS.AUDIT_ACCESS_LOG_ARCHIVE 
WHERE ArchiveDate < DATEADD(DAY, -90, GETDATE());
```

---

#### B2: STANDARD AUDIT (Moderate volume, 489 subpartitions)
Medium-volume audit tables covering major entities:

| Table Name | Partitions | Subpartitions | Audit Purpose |
|-----------|-----------|---|---|
| ADDRESS_AUDIT | 163 | 489 | Track address changes |
| ALLERGY_AUDIT | 163 | 489 | Track allergy modifications |
| ALT_PRESCRIBER_AUDIT | 163 | 489 | Alternative prescriber changes |
| CARD_AUDIT | 163 | 489 | Insurance card changes |
| COMPOUND_INGREDIENTS_AUDIT | 163 | 489 | Compound ingredient modifications |
| COUNSELING_NOTES_AUDIT | 163 | 489 | Counseling note changes |
| DISEASE_AUDIT | 163 | 489 | Disease/condition changes |
| EMAIL_AUDIT | 163 | 489 | Email address changes |
| FDB_PATIENT_ALLERGY_AUDIT | 163 | 489 | FDB allergy tracking |
| FDB_PAT_ALLERGY_REACTION_AUDIT | 163 | 489 | FDB reaction tracking |
| FOLLOW_UP_PRESCRIBER_AUDIT | 163 | 489 | Follow-up prescriber changes |
| FREE_FORM_ALLERGY_AUDIT | 163 | 489 | Free-form allergy changes |
| KP_RXNUM_REF_AUDIT | 163 | 489 | Rx number reference tracking |
| MATCH_KEY_AUDIT | 163 | 489 | Matching key changes |
| MEDICAL_CONDITION_AUDIT | 163 | 489 | Medical condition tracking |
| MOD_PCM_AUDIT | 163 | 489 | Medication modification tracking |
| MRN_AUDIT | 163 | 489 | Medical record number changes |
| MTM_PATIENT_ANSWERS_AUDIT | 163 | 489 | MTM questionnaire tracking |
| MTM_PATIENT_SESSION_AUDIT | 163 | 489 | MTM session tracking |
| PACKAGE_INFO_AUDIT | 163 | 489 | Package information changes |
| PATIENT_AUDIT | 163 | 489 | Patient record changes |
| PATIENT_CARE_PROVIDER_AUDIT | 163 | 489 | Care provider changes |
| PATIENT_CREDIT_CARD_AUDIT | 163 | 489 | Credit card changes |
| PATIENT_EMERGENCY_CONT_AUDIT | 163 | 489 | Emergency contact changes |
| PATIENT_NOTES_AUDIT | 163 | 489 | Patient note changes |
| PATIENT_PROGRAM_AUDIT | 163 | 489 | Patient program changes |
| PATIENT_PROGRAM_CONTACT_AUDIT | 163 | 489 | Program contact changes |
| PATIENT_SIGNATURES_AUDIT | 163 | 489 | Signature changes |
| PAYMENT_AUDIT | 163 | 489 | Payment transaction audit |
| PA_NUM_AUDIT | 163 | 489 | Prior authorization tracking |
| PRESCRIBER_AUDIT | 163 | 489 | Prescriber changes |
| PRIOR_ADVERSE_REACTION_AUDIT | 163 | 489 | Adverse reaction tracking |
| RTSSP_AUDIT | 163 | 489 | RTSSP audit trail |
| RX_TX_AUDIT | 163 | 489 | Rx transaction changes |
| RX_TX_DIAGNOSIS_CODES_AUDIT | 163 | 489 | Diagnosis code tracking |
| RX_TX_DUR_LIST_AUDIT | 163 | 489 | DUR interaction tracking |
| RX_TX_PAYMENT_AUDIT | 163 | 489 | Rx payment audit |
| SIGNATURE_AUDIT | 163 | 489 | Signature audit trail |
| TELEPHONE_AUDIT | 163 | 489 | Phone number changes |
| TP_LINK_AUDIT | 163 | 489 | Third-party link tracking |
| TX_CRED_AUDIT | 163 | 489 | Transaction credit audit |
| TX_LOT_AUDIT | 163 | 489 | Transaction lot tracking |
| TX_TP_AUDIT | 163 | 489 | Third-party transaction audit |
| VIAL_INFO_AUDIT | 163 | 489 | Vial information audit |
| WORKMANS_COMP_AUDIT | 163 | 489 | Workers comp audit |

**Implementation Priority:** PHASE 2 (Week 2-3)

**Note:** All share same partition scheme `ps_AUDIT_TS_WEEKLY`

```sql
-- All B2 tables use same partition function/scheme as B1
-- Only differs in index strategy specific to each table

-- Example: ADDRESS_AUDIT
CREATE CLUSTERED INDEX CIX_ADDRESS_AUDIT_TS
ON EPS.ADDRESS_AUDIT (AUDIT_TIMESTAMP, CHAIN_ID)
ON ps_AUDIT_TS_WEEKLY(AUDIT_TIMESTAMP);

CREATE NONCLUSTERED INDEX NIX_ADDRESS_AUDIT_CHAIN
ON EPS.ADDRESS_AUDIT (CHAIN_ID, AUDIT_TIMESTAMP)
INCLUDE (CHANGE_TYPE, OLD_VALUE, NEW_VALUE);
```

---

#### B3: SMALLER AUDIT (Low-volume, <489 subpartitions)
Specialized audit tables with smaller subpartition counts:

| Table Name | Partitions | Subpartitions | Purpose | Notes |
|-----------|-----------|---|---------|-------|
| PATIENT_AR_ACCOUNT_AUDIT | 162 | 486 | A/R account audit | ~97% of data vs standard |
| RENAL_MEASUREMENT_AUDIT | 52 | 156 | Renal measurement audit | Specialized table; only ~31% coverage |
| PATIENT_NOTIFY_SCHEDULE_AUDIT | 51 | 153 | Notification schedule audit | Specialized; only ~31% coverage |
| CHAIN_RX_TX_SHARING_LINK_AUDIT | 163 | 489 | Rx sharing audit | Standard volume |

**Implementation Priority:** PHASE 2 (with standard audits)

**Strategy:** All can use same `ps_AUDIT_TS_WEEKLY` partition scheme; smaller subpartition counts won't hurt

---

### CATEGORY B: Archive & Retention Strategy

**Weekly Archive Procedure:**
```sql
-- Every Sunday night (automated SQL Agent job)
DECLARE @ArchiveDate NVARCHAR(50) = FORMAT(DATEADD(DAY, -7, GETDATE()), 'yyyyMMdd');

-- Archive all B tables (50 tables)
ALTER TABLE EPS.AUDIT_ACCESS_LOG
SWITCH PARTITION 1 TO EPS.AUDIT_ACCESS_LOG_ARCHIVE_@ArchiveDate;

ALTER TABLE EPS.AUDIT_MESSAGE_CONTENT
SWITCH PARTITION 1 TO EPS.AUDIT_MESSAGE_CONTENT_ARCHIVE_@ArchiveDate;

-- ... repeat for all 50 B tables

-- After 90 days, drop archives
DROP TABLE EPS.AUDIT_ACCESS_LOG_ARCHIVE_[date] 
WHERE DATEDIFF(DAY, [date], GETDATE()) > 90;
```

**Expected Improvement:**
- ✅ Archive operation: **Seconds** (partition switch) vs hours (DELETE)
- ✅ Purge operation: **Seconds** (DROP TABLE) vs minutes (DELETE + SHRINK)
- ✅ Query performance: Partition elimination on time ranges
- ✅ Retention automation: Predictable weekly cycle

---

## CATEGORY C: OPTIONAL/FLEXIBLE PARTITIONING
### Small or Special-Purpose Audit Tables (5 tables)

These tables can either use partitioning (PARTITION BY AUDIT_TIMESTAMP) OR index-based approach.

**Tables:**
1. PATIENT_MO_CONSENT_AUDIT — 54 partitions, only audit table (separate from main PATIENT_MO_CONSENT)
2. VISUALLY_IMPAIRED_DETAIL_AUDIT — 54 partitions, accessibility features audit

**Decision Matrix for Category C:**

| Factor | PARTITION BY TIMESTAMP | INDEX-ONLY | Winner |
|--------|------------------------|------------|--------|
| Volume | Low (54 partitions) | Small tables | 🟰 Either |
| Query Pattern | Time-based (typical audit) | Mixed | ⭐ TIMESTAMP |
| Archive Need | Optional | Not possible | ⭐ TIMESTAMP |
| Management | Minimal overhead | Zero overhead | INDEX-ONLY |
| Performance | Good | Good | 🟰 Either |

**Recommendation:** **Use PARTITION BY AUDIT_TIMESTAMP** for consistency with other audits, even though volume is low.

**Alternative:** If your team prefers minimal partitioning, these 2 tables can use index-based approach:
```sql
-- Index-based approach for small audit tables
CREATE CLUSTERED INDEX CIX_PATIENT_MO_CONSENT_AUDIT_TS
ON EPS.PATIENT_MO_CONSENT_AUDIT (AUDIT_TIMESTAMP, CHAIN_ID);

CREATE NONCLUSTERED INDEX NIX_PATIENT_MO_CONSENT_AUDIT_CHAIN
ON EPS.PATIENT_MO_CONSENT_AUDIT (CHAIN_ID, AUDIT_TIMESTAMP);
```

---

## COMPREHENSIVE IMPLEMENTATION PLAN

### Phase 1: Foundation (Week 1)
**Create shared partition functions & schemes**

```sql
-- Partition function for all CATEGORY A tables (Master data)
CREATE PARTITION FUNCTION pf_ChainID_EPS (INT)
AS RANGE LEFT FOR VALUES (1000, 5000, 50000, 100000, 130000);

CREATE PARTITION SCHEME ps_ChainID_EPS
AS PARTITION pf_ChainID_EPS ALL TO ([PRIMARY]);

-- Partition function for all CATEGORY B tables (Audit data)
CREATE PARTITION FUNCTION pf_AUDIT_TS_WEEKLY (DATETIME2)
AS RANGE RIGHT FOR VALUES (
    '2026-06-15', '2026-06-22', '2026-06-29', 
    '2026-07-06', '2026-07-13', '2026-07-20', '2026-07-27'
);

CREATE PARTITION SCHEME ps_AUDIT_TS_WEEKLY
AS PARTITION pf_AUDIT_TS_WEEKLY ALL TO ([PRIMARY]);
```

**Priority Tables (Apply partitioning):**
- EPS.PATIENT
- EPS.RX_TX
- EPS.PRESCRIBER
- EPS.AUDIT_ACCESS_LOG
- EPS.AUDIT_MESSAGE_CONTENT

---

### Phase 2: High-Value Tables (Week 2-3)
**Apply to remaining A1 & B1, B2 tables**

**Category A1 tables (10 high-priority):**
- ADDRESS, MRN, CARD, PAYMENT, LINE_ITEM, ALLERGY, DISEASE, TELEPHONE, EMAIL, PRESCRIBER

**Category B1 tables (2 high-volume audits):**
- AUDIT_ACCESS_LOG, AUDIT_MESSAGE_CONTENT

**Category B2 tables (subset of 44 standard audits):**
- All major entity audits (ADDRESS_AUDIT, ALLERGY_AUDIT, etc.)

---

### Phase 3: Remaining Tables (Week 4-5)
**Apply to Category A2, A3, B3, C**

**Category A2 & A3 (60 operational tables):**
- All remaining master/transactional data

**Category B3 (3 small audits):**
- PATIENT_AR_ACCOUNT_AUDIT, RENAL_MEASUREMENT_AUDIT, PATIENT_NOTIFY_SCHEDULE_AUDIT

**Category C (2 optional):**
- PATIENT_MO_CONSENT_AUDIT, VISUALLY_IMPAIRED_DETAIL_AUDIT

---

### Phase 4: Validation & Optimization (Week 6)
**Performance testing, index tuning, archive procedure testing**

---

## SUMMARY TABLE: QUICK REFERENCE

### Strategy Assignments by Table Count

| Strategy | # Tables | Partition Column | Partition Scheme | Archive | Priority |
|----------|----------|------------------|-----------------|---------|----------|
| **Category A: CHAIN_ID** | 73 | CHAIN_ID (6 ranges) | ps_ChainID_EPS | Not needed | PHASE 1-3 |
| **Category B1: AUDIT_TS (High-Vol)** | 2 | AUDIT_TIMESTAMP (8 weekly) | ps_AUDIT_TS_WEEKLY | Weekly | PHASE 1 |
| **Category B2: AUDIT_TS (Std-Vol)** | 44 | AUDIT_TIMESTAMP (8 weekly) | ps_AUDIT_TS_WEEKLY | Weekly | PHASE 2-3 |
| **Category B3: AUDIT_TS (Low-Vol)** | 4 | AUDIT_TIMESTAMP (8 weekly) | ps_AUDIT_TS_WEEKLY | Weekly | PHASE 3 |
| **Category C: Optional** | 5 | AUDIT_TIMESTAMP (8 weekly) or Index | ps_AUDIT_TS_WEEKLY or None | Optional | PHASE 3 |

---

## KEY METRICS & EXPECTATIONS

### Before Partitioning (Oracle)
- **CATEGORY A (73 tables):** 163 LIST partitions each → Complex, non-optimal for Azure
- **CATEGORY B (50 tables):** 163×489 to 163×6031 composite → Oracle-specific, not replicable
- **Total Physical Partitions in Oracle:** 73×163 + 50×163 = 20K+ partitions (unwieldy)

### After Partitioning (Azure SQL)
- **CATEGORY A (73 tables):** 6 shared RANGE partitions each → Simple, shared scheme
- **CATEGORY B (50 tables):** 8 shared RANGE partitions each → Time-series optimized
- **Total Physical Partitions in Azure:** 73×6 + 50×8 = **438 + 400 = 838 partitions** (manageable!)

### Expected Performance Improvements

| Metric | Before | After | Improvement |
|--------|--------|-------|------------|
| Archive old audit data | DELETE: 30 mins | PARTITION SWITCH: 5 secs | **360x faster** |
| Date-range audit queries | Index scan | Partition elimination | **50-70% faster** |
| Chain-specific queries | Partition elimination | Partition elimination | **Same speed** |
| Archive purge after 90 days | Manual DELETE | Automated DROP TABLE | **Manual → Auto** |
| Management complexity | 20K+ partitions | 838 partitions | **96% simpler** |

---

## RISK MITIGATION

### Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Shared partition scheme failures | All 73 tables fail | Test ps_ChainID_EPS thoroughly before rollout |
| Archive job failures for 50 audits | Data accumulates, disk fills | Automate with error alerts; test weekly |
| Application code expects specific partition counts | Queries fail | Update app queries to avoid hardcoded partition numbers |
| Mixed partitioning strategies cause confusion | Deployment errors | Clear documentation; CATEGORY labels; phased approach |
| Date boundaries mismatch for AUDIT_TIMESTAMP | Data in wrong partition | Standardize AUDIT_TIMESTAMP format; test boundary values |

---

## RECOMMENDATIONS FOR CLIENT APPROVAL

✅ **Approve CATEGORY A partitioning:** PARTITION BY CHAIN_ID
- Direct Oracle conversion
- Supports business entity isolation
- Proven Azure best practice

✅ **Approve CATEGORY B partitioning:** PARTITION BY AUDIT_TIMESTAMP
- Time-series optimization for audits
- Enables weekly retention/archive cycle
- 360x faster purge operations

✅ **Decide on CATEGORY C:** 
- Recommend using same AUDIT_TIMESTAMP strategy for consistency
- Alternative: Use index-based approach for minimal overhead

✅ **Implement phased approach:**
- PHASE 1: Foundation + 10 priority tables
- PHASE 2-3: Remaining 115+ tables
- PHASE 4: Validation & optimization

---

**Next Step:** Schedule implementation kickoff meeting with technical team.

