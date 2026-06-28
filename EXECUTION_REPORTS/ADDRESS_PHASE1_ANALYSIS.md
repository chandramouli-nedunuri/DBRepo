# ADDRESS TABLE - PHASE 1 PRE-EXECUTION ANALYSIS
**Date:** June 26, 2026  
**Table:** EPS.ADDRESS  
**Category:** A1 (High Priority - CHAIN_ID Partitioning)  
**Status:** ✅ READY FOR PARTITIONING  

---

## 📊 PHASE 1 ANALYSIS RESULTS

### **Step 1.1: TABLE EXISTENCE CHECK** ✅
```
Status: ADDRESS table exists in EPS schema
Found: 1 record
Ready: YES
```

### **Step 1.2: CHAIN_ID COLUMN VERIFICATION** ✅
```
Column Name: CHAIN_ID
Data Type: bigint (PERFECT for partitioning)
Nullable: NO (Required - cannot partition on nullable column)
Status: ✅ READY
```

### **Step 1.3: PRIMARY KEY IDENTIFICATION** ✅
```
Current PK Name: ADDRESS_PK
Status: Exists and ready to be modified
```

### **Step 1.4: ORIGINAL PRIMARY KEY STRUCTURE** ⚠️
```
Current PK Columns:
  Ordinal 1: CHAIN_ID

Finding: ⚠️ ADDRESS_PK currently ONLY has CHAIN_ID!
  └─ This is UNUSUAL - typically PK has 2+ columns
  └─ Original oracle PK was likely (ID) - need to verify with SOURCE

Note: ID column exists (numeric, NOT NULL) - this should be part of PK
```

### **Step 1.5: FOREIGN KEY INVENTORY** ✅
```
Total FKs for ADDRESS:
  - FKs going OUT (to other tables): 3
  - FKs coming IN (from child tables): 0

FKs to Drop/Recreate (Phase 2):
  1. ADDRESS_FK_ESCHAIN → EPS_SEC_CHAIN
  2. ADDRESS_FK_ESSTORE → EPS_SEC_STORE
  3. ADDRESS_FK_PATIENT → PATIENT_OLD

Complexity: LOW (only 3 FKs, no child table FKs)
```

### **Step 1.6: PARTITION INFRASTRUCTURE VERIFICATION** ✅
```
Partition Function: pf_ChainID_EPS
  Status: ✅ EXISTS and READY
  Type: RANGE LEFT
  Boundaries: 1000, 5000, 50000, 100000, 130000
  Partitions: 6

Partition Scheme: ps_ChainID_EPS
  Status: ✅ EXISTS and READY
  Mapped To: PRIMARY filegroup
  Can Reuse: YES
```

---

## 🎯 TABLE STRUCTURE SUMMARY

| Property | Value | Status |
|----------|-------|--------|
| **Schema** | EPS | ✅ |
| **Table Name** | ADDRESS | ✅ |
| **Row Count** | [To be determined] | ✅ |
| **CHAIN_ID Column** | bigint, NOT NULL | ✅ |
| **Current PK** | ADDRESS_PK (CHAIN_ID only) | ⚠️ Investigate |
| **ID Column** | numeric, NOT NULL | ✅ |
| **Outbound FKs** | 3 | ✅ |
| **Inbound FKs** | 0 | ✅ |
| **Total Columns** | 38 | ✅ |

---

## ⚠️ CRITICAL DECISION POINT

**Issue Found:** ADDRESS_PK currently only contains CHAIN_ID, but ADDRESS table also has an ID column (numeric, NOT NULL).

**Question:** What should be the new PRIMARY KEY?

### **Option A: (CHAIN_ID, ID)** [RECOMMENDED]
```sql
NEW PK: (CHAIN_ID, ID)
Rationale: 
  - Matches PATIENT model (CHAIN_ID, ID)
  - ID is NOT NULL - perfect for composite key
  - ID is likely the original oracle PK
  - Ensures uniqueness: (CHAIN_ID, ID) combinations are unique
  - Enables partition elimination: queries can filter by CHAIN_ID
```

### **Option B: Keep (CHAIN_ID) only**
```sql
NEW PK: (CHAIN_ID)
Rationale:
  - Already configured this way
  - Simpler PK
  - But: Does not guarantee uniqueness within chain?
  - Risk: Multiple rows with same (CHAIN_ID) allowed?
```

---

## 🚀 READY FOR PHASE 2 (When Confirmed)

**Before proceeding, CONFIRM:**
1. What should be the new PRIMARY KEY for ADDRESS? 
   - Option A: (CHAIN_ID, ID) → Matches PATIENT model
   - Option B: (CHAIN_ID) only → Keep current structure

Once confirmed, ready to execute:
- **Phase 2:** Drop 3 FKs (ADDRESS_FK_ESCHAIN, ADDRESS_FK_ESSTORE, ADDRESS_FK_PATIENT)
- **Phase 3:** Drop ADDRESS_PK, create new PK on ps_ChainID_EPS(CHAIN_ID)
- **Phase 4:** Recreate 3 FKs with CHAIN_ID component
- **Phase 5:** Run 6 verification queries

**Expected Duration:** 45-60 minutes total
**Risk Level:** LOW (simple FK structure, no child dependencies)

---

## 📋 DECISION REQUIRED

**Question:** For ADDRESS table, what should the new PK be?

```
Choose:
A) (CHAIN_ID, ID)        ← Recommended, matches PATIENT
B) (CHAIN_ID)            ← Keep current, simpler
C) Other - specify       ← Custom specification
```

**After confirmation, I will execute Phases 2-5 immediately.**
