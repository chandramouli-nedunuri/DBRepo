-- Converted from Oracle to Azure SQL
-- Source: EPR_Oracle/Synonym/EPS.KAFKA_MESSAGE_QUEUE-Synonym.sql
-- Conversion Date: 2026-05-25

-- Oracle SYNONYM converted to Azure SQL T-SQL SYNONYM
-- Removed: EDITIONABLE keyword (Oracle-only feature)
-- Changed: Double quotes to square brackets for identifier escaping
-- Preserved: FOR clause for base object reference

CREATE SYNONYM [EPS].[KAFKA_MESSAGE_QUEUE] FOR [KMS].[KAFKA_MESSAGE_QUEUE];
