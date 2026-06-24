-- TRIGGER: [EPS].[FOLLOW_UP_PRESCRIBER_TRIG_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[FOLLOW_UP_PRESCRIBER_TRIG_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[FOLLOW_UP_PRESCRIBER_TRIG_AUR];
GO

CREATE TRIGGER [EPS].[FOLLOW_UP_PRESCRIBER_TRIG_AUR]
ON [EPS].[FOLLOW_UP_PRESCRIBER]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[FOLLOW_UP_PRESCRIBER_AUDIT] (
        [CHAIN_ID],
        [ID],
        [ADDRESS],
        [ADDRESS1],
        [CPM_IDENTIFIER],
        [DEA],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [NAME],
        [PHONE],
        [PHONE1],
        [STATE],
        [ZIP],
        [CITY],
        [ID_AAL],
        [LICENSE_NUM],
        [DEA_SCHEDULE_II_RESTRICTIONS],
        [DEA_SCHEDULE_III_RESTRICTIONS],
        [DEA_SCHEDULE_IV_RESTRICTIONS],
        [LAST_NTP_LOGIN_DATE],
        [ID_PATIENT],
        [ISOSTATE],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [ADDRESS],
        [ADDRESS1],
        [CPM_IDENTIFIER],
        [DEA],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [NAME],
        [PHONE],
        [PHONE1],
        [STATE],
        [ZIP],
        [CITY],
        [ID_AAL],
        [LICENSE_NUM],
        [DEA_SCHEDULE_II_RESTRICTIONS],
        [DEA_SCHEDULE_III_RESTRICTIONS],
        [DEA_SCHEDULE_IV_RESTRICTIONS],
        [LAST_NTP_LOGIN_DATE],
        [ID_PATIENT],
        [ISOSTATE],
        NEXT VALUE FOR [EPS].[FOLLOW_UP_PRESCRIBER_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
