-- TRIGGER: [EPS].[PATIENT_EMERGENCY_CONT_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[PATIENT_EMERGENCY_CONT_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[PATIENT_EMERGENCY_CONT_AUR];
GO

CREATE TRIGGER [EPS].[PATIENT_EMERGENCY_CONT_AUR]
ON [EPS].[PATIENT_EMERGENCY_CONTACT]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[PATIENT_EMERGENCY_CONT_AUDIT] (
        [CHAIN_ID],
        [ID],
        [ID_PATIENT],
        [PHONE_TYPE],
        [PHONE_NUMBER],
        [FIRST_NAME],
        [LAST_NAME],
        [RELATION],
        [CONTACT_ORDER],
        [ID_AAL],
        [LAST_UPDATED],
        [DELETED],
        [CONTACT_LAST_UPDATED],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [ID_PATIENT],
        [PHONE_TYPE],
        [PHONE_NUMBER],
        [FIRST_NAME],
        [LAST_NAME],
        [RELATION],
        [CONTACT_ORDER],
        [ID_AAL],
        [LAST_UPDATED],
        [DELETED],
        [CONTACT_LAST_UPDATED],
        NEXT VALUE FOR [EPS].[AUDIT_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
