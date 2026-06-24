-- TRIGGER: [EPS].[PATIENT_PROGRAM_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[PATIENT_PROGRAM_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[PATIENT_PROGRAM_AUR];
GO

CREATE TRIGGER [EPS].[PATIENT_PROGRAM_AUR]
ON [EPS].[PATIENT_PROGRAM]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[PATIENT_PROGRAM_AUDIT] (
        [CHAIN_ID],
        [ID],
        [ID_PATIENT],
        [NHIN_ID],
        [ECC_PROGRAM_IDENTIFIER],
        [PROGRAM_ADDED_DATE],
        [OPT_OUT],
        [DELETED],
        [DEACTIVATED_DATE],
        [LAST_UPDATED],
        [ID_AAL],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [ID_PATIENT],
        [NHIN_ID],
        [ECC_PROGRAM_IDENTIFIER],
        [PROGRAM_ADDED_DATE],
        [OPT_OUT],
        [DELETED],
        [DEACTIVATED_DATE],
        [LAST_UPDATED],
        [ID_AAL],
        NEXT VALUE FOR [EPS].[AUDIT_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
