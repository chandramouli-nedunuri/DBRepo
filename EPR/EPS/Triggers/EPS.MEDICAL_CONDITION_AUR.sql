-- TRIGGER: [EPS].[MEDICAL_CONDITION_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[MEDICAL_CONDITION_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[MEDICAL_CONDITION_AUR];
GO

CREATE TRIGGER [EPS].[MEDICAL_CONDITION_AUR]
ON [EPS].[MEDICAL_CONDITION]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[MEDICAL_CONDITION_AUDIT] (
        [CHAIN_ID],
        [ID],
        [ID_PATIENT],
        [NHIN_ID],
        [LAST_UPDATED],
        [MEDICAL_CONDITION_CODE],
        [ICD10],
        [LAST],
        [STOP],
        [DELETED],
        [ID_AAL],
        [DURATION],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [ID_PATIENT],
        [NHIN_ID],
        [LAST_UPDATED],
        [MEDICAL_CONDITION_CODE],
        [ICD10],
        [LAST],
        [STOP],
        [DELETED],
        [ID_AAL],
        [DURATION],
        NEXT VALUE FOR [EPS].[AUDIT_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
