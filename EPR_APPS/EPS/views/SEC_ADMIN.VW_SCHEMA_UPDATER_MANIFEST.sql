-- Converted from Oracle to Azure SQL
-- Source: EPR_Oracle/Views/SEC_ADMIN.VW_SCHEMA_UPDATER_MANIFEST.sql
-- Conversion Date: 2026-05-25

-- Oracle VIEW converted to Azure SQL T-SQL VIEW
-- Removed: FORCE EDITIONABLE keywords (Oracle-only features)
-- Changed: Double quotes to square brackets for identifier escaping
-- Changed: NVL() -> ISNULL()
-- Changed: to_number(NULL) -> CAST(NULL AS NUMERIC)
-- Changed: NULLS LAST -> ORDER BY ... handling via CASE statement

CREATE VIEW [SEC_ADMIN].[VW_SCHEMA_UPDATER_MANIFEST] ([VERSION], [FILE_NAME], [APPLY_ORDER]) AS 
SELECT 
    [version],
    [file_name],
    ROW_NUMBER() OVER (ORDER BY CASE WHEN [apply_order] IS NULL THEN 1 ELSE 0 END, ISNULL([apply_order], -999999), [build_order]) AS [apply_order]
FROM (
    SELECT 
        m.[version],
        m.[file_name],
        m.[apply_order] AS [apply_order],
        CAST(NULL AS NUMERIC) AS [build_order]
    FROM [pdx_schema_updater_manifest] AS m
    UNION
    SELECT 
        m.[version],
        m.[file_name],
        CAST(NULL AS NUMERIC) AS [apply_order],
        m.[apply_order] AS [build_order]
    FROM [schema_updater_manifest] AS m
    WHERE m.[apply_order] > (
        SELECT ISNULL(MAX(mi.[apply_order]), -1)
        FROM [schema_updater_manifest] AS mi
        JOIN [pdx_schema_updater_manifest] AS pmi ON mi.[file_name] = pmi.[file_name]
    )
) AS [subquery];
