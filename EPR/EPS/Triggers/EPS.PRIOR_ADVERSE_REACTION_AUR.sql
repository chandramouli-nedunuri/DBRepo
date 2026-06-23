-- TRIGGER: [EPS].[PRIOR_ADVERSE_REACTION_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[PRIOR_ADVERSE_REACTION_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[PRIOR_ADVERSE_REACTION_AUR];
GO

CREATE TRIGGER [EPS].[PRIOR_ADVERSE_REACTION_AUR]
ON [EPS].[PRIOR_ADVERSE_REACTION]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[PRIOR_ADVERSE_REACTION_AUDIT] (
        [CHAIN_ID],
        [ID],
        [ID_PATIENT],
        [NHIN_ID],
        [LAST_UPDATED],
        [CLASS_NUMBER],
        [KDC5],
        [RASH],
        [SHOCK],
        [BREATH],
        [GI_TRACT],
        [BLOOD],
        [UNSPEC],
        [START_DATE],
        [ADDED],
        [REPORT_BY],
        [DELETED],
        [ID_AAL],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [ID_PATIENT],
        [NHIN_ID],
        [LAST_UPDATED],
        [CLASS_NUMBER],
        [KDC5],
        [RASH],
        [SHOCK],
        [BREATH],
        [GI_TRACT],
        [BLOOD],
        [UNSPEC],
        [START_DATE],
        [ADDED],
        [REPORT_BY],
        [DELETED],
        [ID_AAL],
        NEXT VALUE FOR [EPS].[AUDIT_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
