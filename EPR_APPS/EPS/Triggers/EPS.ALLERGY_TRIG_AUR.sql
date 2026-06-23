IF OBJECT_ID('EPS.ALLERGY_TRIG_AUR', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[ALLERGY_TRIG_AUR];
GO

CREATE TRIGGER [EPS].[ALLERGY_TRIG_AUR]
ON [EPS].[ALLERGY]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [EPS].[ALLERGY_AUDIT] (
        [CHAIN_ID],
        [ID],
        [ADDED],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [BLOOD],
        [BREATH],
        [GI_TRACT],
        [RASH],
        [REPORT_BY],
        [SHOCK],
        [START_DATE],
        [UNSPEC],
        [AC_CODE],
        [ID_PATIENT],
        [ID_AAL],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        d.[CHAIN_ID],
        d.[ID],
        d.[ADDED],
        d.[DELETED],
        d.[LAST_UPDATED],
        d.[NHIN_ID],
        d.[BLOOD],
        d.[BREATH],
        d.[GI_TRACT],
        d.[RASH],
        d.[REPORT_BY],
        d.[SHOCK],
        d.[START_DATE],
        d.[UNSPEC],
        d.[AC_CODE],
        d.[ID_PATIENT],
        d.[ID_AAL],
        NEXT VALUE FOR [EPS].[ALLERGY_SEQ],
        SYSDATETIME()
    FROM deleted d;
END;
GO