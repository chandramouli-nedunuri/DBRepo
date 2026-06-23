-- TRIGGER: [EPS].[MATCH_KEY_TRIG_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[MATCH_KEY_TRIG_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[MATCH_KEY_TRIG_AUR];
GO

CREATE TRIGGER [EPS].[MATCH_KEY_TRIG_AUR]
ON [EPS].[MATCH_KEY]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[MATCH_KEY_AUDIT] (
        [CHAIN_ID],
        [ID],
        [MATCH_TYPE],
        [MATCH_VALUE],
        [ID_PATIENT],
        [ID_AAL],
        [LAST_UPDATED],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [MATCH_TYPE],
        [MATCH_VALUE],
        [ID_PATIENT],
        [ID_AAL],
        [LAST_UPDATED],
        NEXT VALUE FOR [EPS].[MATCH_KEY_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
