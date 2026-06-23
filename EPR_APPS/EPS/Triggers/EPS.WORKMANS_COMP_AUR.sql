-- TRIGGER: [EPS].[WORKMANS_COMP_AUR] - Oracle to Azure SQL conversion
-- Converted: AFTER UPDATE trigger with set-based INSERT...SELECT

IF OBJECT_ID('[EPS].[WORKMANS_COMP_AUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[WORKMANS_COMP_AUR];
GO

CREATE TRIGGER [EPS].[WORKMANS_COMP_AUR]
ON [EPS].[WORKMANS_COMP]
AFTER UPDATE
AS
BEGIN
    INSERT INTO [EPS].[WORKMANS_COMP_AUDIT] (
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [ACCIDENT_INDICATOR],
        [ACCIDENT_STATE],
        [CARD_NUMBER],
        [CARRIER_ADDRESS],
        [CARRIER_AREA_CODE],
        [CARRIER_CITY],
        [CARRIER_CODE],
        [CARRIER_COUNTRY],
        [CARRIER_ID],
        [CARRIER_NAME],
        [CARRIER_PHONE],
        [CARRIER_STATE],
        [CARRIER_ZIP_CODE],
        [EMPLOYER_ADDRESS],
        [EMPLOYER_AREA_CODE],
        [EMPLOYER_CITY],
        [EMPLOYER_COUNTRY],
        [EMPLOYER_ID],
        [EMPLOYER_NAME],
        [EMPLOYER_PHONE],
        [EMPLOYER_PRIMARY_CONTACT],
        [EMPLOYER_STATE],
        [EMPLOYER_ZIP_CODE],
        [END_HOSPITALIZATION],
        [END_UNABLE_TO_WORK],
        [GROUP_NUMBER],
        [INJURY],
        [LAST],
        [OTHER_INFO],
        [PLAN_NUMBER],
        [REF_ID],
        [SIMILAR],
        [START_HOSPITALIZATION],
        [START_UNABLE_TO_WORK],
        [ID_CARD],
        [ID_AAL],
        [ID_AUDIT],
        [AUDIT_TIMESTAMP]
    )
    SELECT
        [CHAIN_ID],
        [ID],
        [DELETED],
        [LAST_UPDATED],
        [NHIN_ID],
        [ACCIDENT_INDICATOR],
        [ACCIDENT_STATE],
        [CARD_NUMBER],
        [CARRIER_ADDRESS],
        [CARRIER_AREA_CODE],
        [CARRIER_CITY],
        [CARRIER_CODE],
        [CARRIER_COUNTRY],
        [CARRIER_ID],
        [CARRIER_NAME],
        [CARRIER_PHONE],
        [CARRIER_STATE],
        [CARRIER_ZIP_CODE],
        [EMPLOYER_ADDRESS],
        [EMPLOYER_AREA_CODE],
        [EMPLOYER_CITY],
        [EMPLOYER_COUNTRY],
        [EMPLOYER_ID],
        [EMPLOYER_NAME],
        [EMPLOYER_PHONE],
        [EMPLOYER_PRIMARY_CONTACT],
        [EMPLOYER_STATE],
        [EMPLOYER_ZIP_CODE],
        [END_HOSPITALIZATION],
        [END_UNABLE_TO_WORK],
        [GROUP_NUMBER],
        [INJURY],
        [LAST],
        [OTHER_INFO],
        [PLAN_NUMBER],
        [REF_ID],
        [SIMILAR],
        [START_HOSPITALIZATION],
        [START_UNABLE_TO_WORK],
        [ID_CARD],
        [ID_AAL],
        NEXT VALUE FOR [EPS].[AUDIT_SEQ],
        SYSDATETIME()
    FROM deleted;
END;
GO
