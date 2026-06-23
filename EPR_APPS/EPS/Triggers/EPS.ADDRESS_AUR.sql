IF OBJECT_ID('EPS.ADDRESS_AUR', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[ADDRESS_AUR];
GO

CREATE TRIGGER [EPS].[ADDRESS_AUR]
ON [EPS].[ADDRESS]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [EPS].[ADDRESS_AUDIT] (
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [ADDED],
        [UPDATED],
        [NHIN_ID],
        [ADDRESS_KEY],
        [ADDRESS_LINE1],
        [ADDRESS_LINE2],
        [ADDRESS_TYPE],
        [CITY],
        [CLEAN],
        [COUNTRY],
        [DEACTIVATION_DATE],
        [ENDING_DATE],
        [VALID],
        [NOTE1A],
        [NOTE1B],
        [PO_BOX],
        [POSTAL_CODE],
        [STARTING_DATE],
        [STATE],
        [WORK_AREA_CODE],
        [WORK_PHONE],
        [HOME_AREA_CODE],
        [HOME_PHONE],
        [ID_PATIENT],
        [ID_AAL],
        [CARE_OF],
        [COUNTY],
        [MAIL_STOP],
        [SHIPPING_ADDRESS],
        [ADDRESS_IDENTIFIER],
        [DEFAULT_DELIVERY_SITE],
        [DEFAULT_ADDRESS],
        [WORK_PHONE_UPDATED_DATE],
        [HOME_PHONE_UPDATED_DATE],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        d.[CHAIN_ID],
        d.[ID],
        d.[DELETED],
        d.[LAST_UPDATED],
        d.[ADDED],
        d.[UPDATED],
        d.[NHIN_ID],
        d.[ADDRESS_KEY],
        d.[ADDRESS_LINE1],
        d.[ADDRESS_LINE2],
        d.[ADDRESS_TYPE],
        d.[CITY],
        d.[CLEAN],
        d.[COUNTRY],
        d.[DEACTIVATION_DATE],
        d.[ENDING_DATE],
        d.[VALID],
        d.[NOTE1A],
        d.[NOTE1B],
        d.[PO_BOX],
        d.[POSTAL_CODE],
        d.[STARTING_DATE],
        d.[STATE],
        d.[WORK_AREA_CODE],
        d.[WORK_PHONE],
        d.[HOME_AREA_CODE],
        d.[HOME_PHONE],
        d.[ID_PATIENT],
        d.[ID_AAL],
        d.[CARE_OF],
        d.[COUNTY],
        d.[MAIL_STOP],
        d.[SHIPPING_ADDRESS],
        d.[ADDRESS_IDENTIFIER],
        d.[DEFAULT_DELIVERY_SITE],
        d.[DEFAULT_ADDRESS],
        d.[WORK_PHONE_UPDATED_DATE],
        d.[HOME_PHONE_UPDATED_DATE],
        NEXT VALUE FOR [EPS].[AUDIT_SEQ],
        SYSDATETIME()
    FROM deleted d;
END;
GO