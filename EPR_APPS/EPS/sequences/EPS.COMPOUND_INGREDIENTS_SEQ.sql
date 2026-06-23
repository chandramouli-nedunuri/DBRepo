-- Converted from Oracle to Azure SQL
-- Original Oracle Sequence Definition converted to Azure SQL T-SQL
-- Oracle-specific parameters (CACHE, NOORDER, NOCYCLE, NOKEEP, NOSCALE, GLOBAL) removed as they are not supported in Azure SQL

CREATE SEQUENCE EPS.COMPOUND_INGREDIENTS_SEQ
    AS BIGINT
    START WITH 252
    INCREMENT BY 1
    MINVALUE 1
    NO MAXVALUE
    CACHE 50
    NO CYCLE;
GO
