-- TRIGGER: [EPS].[RENAL_MEASUREMENT_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[RENAL_MEASUREMENT_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[RENAL_MEASUREMENT_AUR];
GO

CREATE TRIGGER [EPS].[RENAL_MEASUREMENT_AUR]
ON [EPS].[RENAL_MEASUREMENT]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[RENAL_MEASUREMENT_AUDIT] (
        [CHAIN_ID],
        [ID],
        [MEASUREMENT_LAST_UPDATED_DATE],
        [LAST_UPDATED],
        [ID_PATIENT],
        [ID_AAL],
        [TYPE],
        [UNIT],
        [VALUE],
        [VALID_TILL_DAYS],
        [DELETED],
        [OBSERVATION_DATE],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [MEASUREMENT_LAST_UPDATED_DATE],
        [LAST_UPDATED],
        [ID_PATIENT],
        [ID_AAL],
        [TYPE],
        [UNIT],
        [VALUE],
        [VALID_TILL_DAYS],
        [DELETED],
        [OBSERVATION_DATE],
        NEXT VALUE FOR [EPS].[AUDIT_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
