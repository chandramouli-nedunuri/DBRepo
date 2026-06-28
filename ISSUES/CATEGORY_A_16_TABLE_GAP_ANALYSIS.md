# Category A: Missing Tables Analysis
**Date:** June 28, 2026

## COMPLETE CATEGORY A TABLE LISTING FROM PARTITION_STRATEGY_BY_TABLE.md

### **A1: HIGH-PRIORITY (10 tables)**
1. PATIENT ✅
2. RX_TX ✅
3. PRESCRIBER ✅
4. ADDRESS ✅
5. MRN ✅
6. CARD ✅
7. PAYMENT ✅
8. LINE_ITEM ✅
9. ALLERGY ✅
10. DISEASE ✅

**Status:** All 10 partitioned

---

### **A2: MEDIUM-PRIORITY (28 tables)**
1. PATIENT_CARE_PROVIDER ✅
2. TELEPHONE ✅
3. EMAIL ✅
4. PRESCRIBER (duplicate from A1?) ✅
5. MEDICAL_CONDITION ✅
6. FREE_FORM_ALLERGY ✅
7. FDB_PATIENT_ALLERGY ✅
8. COMPOUND_INGREDIENTS ✅
9. PACKAGE_INFO ✅
10. SIGNATURE ✅
11. PATIENT_EMERGENCY_CONTACT ✅
12. PATIENT_CREDIT_CARD ✅
13. PATIENT_DOCUMENT ✅
14. PATIENT_PROGRAM ✅
15. PATIENT_PROGRAM_CONTACT ✅
16. PRIOR_ADVERSE_REACTION ✅
17. ALT_PRESCRIBER ✅
18. FOLLOW_UP_PRESCRIBER ✅
19. COUNSELING_NOTES ✅
20. PATIENT_NOTES ✅
21. VIAL_INFO ✅
22. TX_LOT ✅
23. KP_RXNUM_REF ✅
24. TP_LINK ✅
25. INTAKE_SOURCES ✅
26. MATCH_KEY ✅
27. IDGEN ✅
28. RENAL_MEASUREMENT ✅

**Status:** All 28 partitioned

---

### **A3: LOWER-PRIORITY (22 tables listed)**
1. MOD_PCM ✅
2. MTM_PATIENT_ANSWERS ✅
3. MTM_PATIENT_SESSION ✅
4. PATIENT_MO_CONSENT ✅
5. PATIENT_NOTIFY_SCHEDULE ✅
6. PATIENT_AR_ACCOUNT ✅
7. RX_TX_DIAGNOSIS_CODES ✅
8. RX_TX_DUR_LIST ✅
9. RX_TX_PAYMENT ✅
10. RX_TX_SIG_STRUCTURED_PART ✅
11. FDB_PAT_ALLERGY_REACTION ❌ **NOT PARTITIONED**
12. PATIENT_SIGNATURES ✅
13. PA_NUM ✅
14. QUEUECOMMAND ✅
15. PATIENT_UNMERGE_LOCK ✅
16. PATIENT_MO_CONSENT_AUDIT ⚠️ **SSMA SCHEME**
17. VISUALLY_IMPAIRED_DETAIL ✅
18. WORKMANS_COMP ✅
19. COMPOUND_INGREDIENT_LOT ✅
20. TX_CRED ✅
21. TX_TP ✅
22. VERSION ✅

**Status:** 20 partitioned, 1 not partitioned, 1 on wrong scheme

---

## TALLY SUMMARY

| Category | Listed | Partitioned | Status |
|----------|--------|-------------|--------|
| A1 | 10 | 10 | ✅ 100% |
| A2 | 28 | 28 | ✅ 100% |
| A3 | 22 | 20 | ⚠️ 91% |
| **TOTAL** | **60** | **58** | **97%** |

---

## THE MYSTERIOUS 16-TABLE GAP EXPLAINED

**Strategy Claims:** 73 Category A tables  
**Strategy Lists:** Only 60 tables (10 A1 + 28 A2 + 22 A3)  
**Missing from List:** 13 tables (not listed in document sections)  
**Actually Partitioned:** 58 tables (57 on correct scheme + 0 on incorrect schemes)  
**Accounting Gap:** 73 - 58 = **15 missing** (close to reported 16)

---

## POSSIBLE EXPLANATIONS FOR THE 16-TABLE GAP

### **Hypothesis 1: Duplicate Counting**
- PRESCRIBER appears in both A1 (as #3) and A2 (as #4)
- Document may count it twice
- This would account for 1 of the 16

### **Hypothesis 2: Missing A3 Tables in Document**
- Strategy doc claims 73 total but only lists 60
- Missing 13 tables from A3 that should be listed
- These 13 may have been intentionally excluded or are Oracle-only
- Common candidates (not explicitly listed):
  - FDB_PATIENT_ALLERGY_REACTION (exists, not partitioned)
  - Potential SSMA-generated auxiliary tables
  - Possible overlap/archived variants

### **Hypothesis 3: Oracle-Only Tables**
- 16 tables exist in Oracle but were never migrated to Azure
- Examples:
  - Intermediate processing tables
  - Deprecated tables
  - System/audit tables that weren't part of SSMA migration
  - Tables with naming conflicts in Azure

### **Hypothesis 4: SSMA Limitations**
- SSMA couldn't migrate 13-16 tables due to:
  - Unsupported Oracle data types
  - Complex triggers/functions not supported
  - Large object types (CLOB, BLOB)
  - Custom data types

---

## CONFIRMED ISSUES IN A3

### **1. FDB_PATIENT_ALLERGY_REACTION** ❌
- Listed in strategy A3
- Exists in Azure database ✅
- **NOT PARTITIONED** ❌
- Has CHAIN_ID column
- Can be partitioned using standard pattern
- Action: Apply ps_ChainID_EPS partitioning

### **2. PATIENT_MO_CONSENT_AUDIT** ⚠️
- Listed in strategy A3
- Exists in Azure database ✅
- **On SSMA partition scheme** (not Azure ps_AUDIT_TIMESTAMP)
- Has 54 SSMA partitions
- Should have 8 Azure partitions
- Action: Migrate from SSMA scheme to ps_AUDIT_TIMESTAMP

---

## CONCLUSION

The **16-table gap** is likely composed of:

1. **13 tables not listed in strategy document** (missing from doc sections)
   - May be Oracle-only
   - May be intentionally excluded
   - May be in supplementary lists not captured

2. **1 duplicate** (PRESCRIBER counted in both A1 and A2)

3. **2 confirmed partitioning issues:**
   - FDB_PATIENT_ALLERGY_REACTION (not partitioned)
   - PATIENT_MO_CONSENT_AUDIT (wrong scheme)

**Recommendation:** Query Oracle source database to:
1. Identify all 73 Category A tables
2. Determine which weren't migrated to Azure
3. Document exclusion rationale
4. Update strategy with complete inventory

