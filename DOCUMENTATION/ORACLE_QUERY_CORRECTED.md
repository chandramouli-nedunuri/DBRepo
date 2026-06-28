# CORRECTED QUERY 1 FOR ORACLE - ADDRESS PRIMARY KEY

## **Use This Query Instead** (Corrected Syntax)

```sql
SELECT 
    c.constraint_name,
    c.constraint_type,
    cc.column_name,
    cc.position
FROM user_constraints c
JOIN user_cons_columns cc ON c.constraint_name = cc.constraint_name
WHERE c.table_name = 'ADDRESS'
  AND c.constraint_type = 'P'
ORDER BY cc.position;
```

**Explanation of Fix:**
- ❌ **Wrong:** `user_cons_columns` doesn't have `CONSTRAINT_TYPE` column directly
- ✅ **Fixed:** JOIN `user_constraints` (has constraint_type) with `user_cons_columns` (has column_name)

---

## **If That Fails, Use This Alternative:**

```sql
SELECT 
    constraint_name,
    column_name,
    position
FROM user_cons_columns
WHERE constraint_name IN (
    SELECT constraint_name 
    FROM user_constraints 
    WHERE table_name = 'ADDRESS' 
      AND constraint_type = 'P'
)
ORDER BY position;
```

---

## **Or Run This Super Simple Query:**

```sql
SELECT constraint_name, column_name, position
FROM user_cons_columns
WHERE table_name = 'ADDRESS'
  AND position IS NOT NULL
ORDER BY position;
```

Then manually check which one is the PRIMARY KEY in Oracle SQL Developer.

---

## **Then Run Query 2 - Check CHAIN_ID Uniqueness:**

```sql
SELECT CHAIN_ID, COUNT(*) as Row_Count
FROM ADDRESS
GROUP BY CHAIN_ID
HAVING COUNT(*) > 1
ORDER BY Row_Count DESC;
```

**Result interpretation:**
- **Empty result:** Each CHAIN_ID is unique → PK = (CHAIN_ID)
- **Has rows:** Some CHAIN_IDs appear multiple times → PK = (CHAIN_ID, ID)

---

## **Or Just Answer This:**

**In your ADDRESS table in Oracle, are there:**
1. Multiple rows with the same CHAIN_ID? (YES/NO)
2. Or is each CHAIN_ID unique in the table? (YES/NO)

That tells us everything we need!
