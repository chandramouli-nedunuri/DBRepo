# ADDRESS TABLE - SOURCE DB QUERIES TO CONFIRM PK STRUCTURE

## Run These Queries Against Your SOURCE DATABASE (Oracle) to Determine Original PK

---

## **Query 1: Find Original PRIMARY KEY in Oracle**

```sql
SELECT 
    constraint_name,
    constraint_type,
    column_name,
    position
FROM user_cons_columns
WHERE table_name = 'ADDRESS'
  AND constraint_type = 'P'
ORDER BY position;
```

**What it shows:**
- The constraint name (e.g., PK_ADDRESS, ADDRESS_PK, etc.)
- All columns that make up the primary key
- Their ordinal position (1st, 2nd, 3rd, etc.)

**Expected Results:**
- If only CHAIN_ID: `(CHAIN_ID)` ← Single column PK
- If CHAIN_ID + ID: `(CHAIN_ID, ID)` ← Composite PK
- If only ID: `(ID)` ← Just ID column

---

## **Query 2: Check All Constraints on ADDRESS Table**

```sql
SELECT 
    constraint_name,
    constraint_type,
    status
FROM user_constraints
WHERE table_name = 'ADDRESS'
ORDER BY constraint_type;
```

**What it shows:**
- All constraints (Primary, Unique, Foreign, Check, etc.)
- Their status (ENABLED, DISABLED)

**Look for:** 
- `P` = Primary Key (this is what we need)
- `U` = Unique constraint (might be important too)

---

## **Query 3: Detailed PK Column Information**

```sql
SELECT 
    constraint_name,
    table_name,
    column_name,
    position
FROM user_cons_columns c
WHERE table_name = 'ADDRESS'
  AND EXISTS (
      SELECT 1 FROM user_constraints
      WHERE table_name = 'ADDRESS'
        AND constraint_type = 'P'
        AND constraint_name = c.constraint_name
  )
ORDER BY position;
```

**What it shows:**
- Exact PK structure with column names in order

---

## **Query 4: Check CHAIN_ID Uniqueness (within chains)**

```sql
SELECT 
    CHAIN_ID,
    COUNT(DISTINCT ID) as Unique_IDs,
    COUNT(*) as Total_Rows
FROM ADDRESS
GROUP BY CHAIN_ID
ORDER BY Total_Rows DESC;
```

**What it shows:**
- For each CHAIN_ID: how many unique IDs exist
- If CHAIN_ID is alone PK: each CHAIN_ID should have exactly 1 row
- If (CHAIN_ID, ID) is composite PK: each CHAIN_ID can have multiple IDs

**Decision Help:**
- If each CHAIN_ID has exactly 1 row → PK might be just (CHAIN_ID)
- If each CHAIN_ID has multiple rows → PK is definitely (CHAIN_ID, ID)

---

## **Query 5: Check for Duplicate CHAIN_IDs (Most Important)**

```sql
SELECT 
    CHAIN_ID,
    COUNT(*) as Row_Count
FROM ADDRESS
GROUP BY CHAIN_ID
HAVING COUNT(*) > 1
ORDER BY Row_Count DESC;
```

**What it shows:**
- Which CHAIN_IDs have more than 1 row
- If result is EMPTY → Each CHAIN_ID is unique (PK = CHAIN_ID)
- If result has rows → Multiple rows per CHAIN_ID (PK = CHAIN_ID + ID)

**Decision Help:**
- **Empty result** → `NEW PK = (CHAIN_ID)` only
- **Has results** → `NEW PK = (CHAIN_ID, ID)`

---

## **Query 6: Check ID Uniqueness**

```sql
SELECT 
    ID,
    COUNT(*) as Row_Count,
    COUNT(DISTINCT CHAIN_ID) as Unique_Chains
FROM ADDRESS
GROUP BY ID
HAVING COUNT(*) > 1
ORDER BY Row_Count DESC;
```

**What it shows:**
- If any ID appears in multiple chains
- If ID alone is unique across all chains

---

## **Query 7: Sample Data - See Structure**

```sql
SELECT TOP 100 
    CHAIN_ID, 
    ID, 
    ADDRESS_KEY,
    ADDRESS_LINE1,
    CITY,
    STATE
FROM ADDRESS
ORDER BY CHAIN_ID, ID;
```

**What it shows:**
- First 100 rows so you can see the data pattern
- How CHAIN_ID and ID relate to each other

---

## **QUICK DECISION MATRIX**

### Run all 7 queries, then:

| Query 1 Result | Query 5 Result | Decision |
|---|---|---|
| PK = (CHAIN_ID) | Empty (no duplicates) | ✅ Keep PK = (CHAIN_ID) |
| PK = (CHAIN_ID) | Has results (duplicates) | ❌ ERROR - mismatch! |
| PK = (CHAIN_ID, ID) | Empty | ⚠️ Redundant composite PK |
| PK = (CHAIN_ID, ID) | Has results | ✅ Keep PK = (CHAIN_ID, ID) |
| PK = (ID) only | Empty | ⚠️ Query Query 4 result |
| PK = (ID) only | Has results | ❌ ERROR - ID not unique |

---

## **FINAL DECISION LOGIC**

```
1. Run Query 1 → See original PK in Oracle
2. Run Query 5 → Check if CHAIN_ID is unique
   
   IF Query 5 returns EMPTY:
      → Each CHAIN_ID has exactly 1 row
      → NEW PK = (CHAIN_ID) ✅
      
   IF Query 5 returns ROWS:
      → Multiple rows per CHAIN_ID
      → NEW PK = (CHAIN_ID, ID) ✅
      
3. Run Query 6 → Verify ID uniqueness pattern
4. Run Query 7 → Manually inspect first 100 rows
```

---

## **EXPECTED OUTCOMES**

### **Scenario 1: PK = CHAIN_ID (Single Column)**
```
Query 1: CHAIN_ID
Query 5: Empty result (no CHAIN_ID appears twice)
Query 7: Each row has unique CHAIN_ID

→ Address table has 1:1 relationship with CHAIN_ID
→ NEW PK = (CHAIN_ID) ✅ confirmed
```

### **Scenario 2: PK = (CHAIN_ID, ID) (Composite)**
```
Query 1: CHAIN_ID, ID (in that order)
Query 5: Shows CHAINs with multiple rows
Query 7: Same CHAIN_ID appears with different IDs

→ Address table has many addresses per CHAIN
→ NEW PK = (CHAIN_ID, ID) ✅ confirmed
```

### **Scenario 3: PK = ID (Only ID)**
```
Query 1: ID (no CHAIN_ID in PK)
Query 5: Empty result
Query 6: Empty result

→ ID is globally unique identifier
→ NEW PK = (CHAIN_ID, ID) ✅ Still add CHAIN_ID (partition key)
→ Note: Azure PK must include partition key as first column
```

---

## **INSTRUCTIONS**

1. **Copy each query above** (Query 1-7)
2. **Run in Oracle SQL Developer** or your source database tool
3. **Share the results** with me
4. **I will tell you** whether to use `(CHAIN_ID)` or `(CHAIN_ID, ID)`
5. **Then execute** Phases 2-5 on Azure SQL

---

## **QUICK SHORTCUT - Run This Combined Query**

If you want all info in one go, run this on Oracle:

```sql
-- All-in-one diagnostic
SELECT '1_ORIGINAL_PK' as Check_Name FROM dual
UNION ALL
SELECT constraint_name FROM user_cons_columns WHERE table_name='ADDRESS' AND constraint_type='P'
UNION ALL
SELECT '2_CHAIN_UNIQUENESS' as Check_Name FROM dual
UNION ALL
SELECT TO_CHAR(COUNT(*)) || ' CHAINs with multiple rows' FROM (
    SELECT CHAIN_ID, COUNT(*) FROM ADDRESS GROUP BY CHAIN_ID HAVING COUNT(*) > 1
)
UNION ALL
SELECT '3_SAMPLE_DATA' as Check_Name FROM dual
UNION ALL
SELECT CHAIN_ID || ' - ' || ID || ' - ' || ADDRESS_KEY FROM (
    SELECT TOP 20 CHAIN_ID, ID, ADDRESS_KEY FROM ADDRESS ORDER BY CHAIN_ID, ID
)
;
```

---

## **STILL UNSURE? HERE'S THE SAFEST APPROACH**

If the data analysis is complex, just answer this:

**Q: In your source Oracle database, how many ADDRESS records exist PER CHAIN?**

- If "Usually 1 address per chain" → `(CHAIN_ID)` PK
- If "Multiple addresses per chain (home, work, billing, etc.)" → `(CHAIN_ID, ID)` PK
- If "Varies" → Run Query 5 to see distribution

That's it! Once you answer this, I can confirm the PK and execute Phases 2-5 immediately.
