-- TRIGGER: [EPS].[PATIENT_TRIG_BIUR] - Oracle to Azure SQL conversion
-- Converted: BEFORE INSERT OR UPDATE trigger with conditional logic

IF OBJECT_ID('[EPS].[PATIENT_TRIG_BIUR]', 'TR') IS NOT NULL
    DROP TRIGGER [EPS].[PATIENT_TRIG_BIUR];
GO

CREATE TRIGGER [EPS].[PATIENT_TRIG_BIUR]
ON [EPS].[PATIENT]
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    DECLARE @GroupNumber NVARCHAR(MAX);
    DECLARE @BottleColor INT;

    SELECT 
        @GroupNumber = [GROUP_NUMBER],
        @BottleColor = [BOTTLE_COLOR]
    FROM inserted;

    IF @GroupNumber IS NOT NULL OR @BottleColor IS NOT NULL
    BEGIN
        IF @GroupNumber IS NOT NULL
        BEGIN
            SET @BottleColor = CASE UPPER(@GroupNumber)
                WHEN 'R' THEN 1
                WHEN 'O' THEN 2
                WHEN 'Y' THEN 3
                WHEN 'G' THEN 4
                WHEN 'B' THEN 5
                WHEN 'P' THEN 6
                WHEN 'K' THEN 7
                ELSE 0
            END;
        END
        ELSE IF @BottleColor IS NOT NULL
        BEGIN
            SET @GroupNumber = CASE @BottleColor
                WHEN 1 THEN 'R'
                WHEN 2 THEN 'O'
                WHEN 3 THEN 'Y'
                WHEN 4 THEN 'G'
                WHEN 5 THEN 'B'
                WHEN 6 THEN 'P'
                WHEN 7 THEN 'K'
                ELSE NULL
            END;
        END;

        INSERT INTO [EPS].[PATIENT]
        SELECT 
            [CHAIN_ID],
            [ID],
            [RX_COM_ID],
            [LAST_UPDATED],
            [NHIN_ID],
            [ADDED],
            [LAST],
            [BIRTH_DATE],
            [CATEGORY],
            [DAW],
            [DEACTIVATE_DATE],
            [DECEASED_DATE],
            [DISCOUNT],
            [DRIVER_LICENSE],
            [FIRST_NAME],
            @GroupNumber,
            [HEIGHT],
            [LABEL],
            [LAST_NAME],
            [MARITAL_STATUS],
            [MEDICAL_RECORD_NUMBER],
            [METRIC_WEIGHT],
            [MIDDLE_NAME],
            [NO_CF],
            [NO_COMPLIANCE],
            [NO_PREFILL],
            [NO_REF_PREF],
            [NO_TRANSFER],
            [NSC],
            [NUM_LABS],
            [OMIT_DUR],
            [PARTIAL_CII_FILL],
            [PO_BOX],
            [RACE],
            [SEX],
            [SSN],
            [SUB_GROUP],
            [WEIGHT],
            [FOR_DAT],
            [LANG],
            [MAIL_TYPE],
            [MAJORITY],
            [NO_PAYMENT_REQ],
            [OTC_PRICE_CODE],
            [PRICE_CODE],
            [SHIP_TYPE],
            [TAXABLE],
            [BIRTH_DATE_TEXT],
            [RECORDTYPE],
            [ANIMALTYPE],
            [MULTIBIRTH],
            [PROFESSION],
            [SUFFIX],
            [ID_AAL],
            [SURVIVOR_ID],
            [OLD_CONTRIB_ID],
            [NEW_CONTRIB_ID],
            [MERGED_DATE],
            [UNMERGED_DATE],
            [STORE_CREATED_AT],
            @BottleColor,
            [EHR_ID],
            [EHR_ENABLED],
            [IS_LINKED],
            [LINK_FLAGS],
            [LAST_SYNC_TIME],
            [DRIVER_LICENSE_STATE],
            [ALT_PATIENT_ID],
            [ALT_PATIENT_ID_STATE],
            [ALT_PATIENT_ID_TYPE],
            [PUELA],
            [DRIVER_LICENSE_ADDENDUM],
            [TP_HIERARCHY_CHANGE],
            [VISUALLY_IMPAIRED],
            [REQUIRE_DELIVERY_CONFIRMATION],
            [ACTIVE_MEMBER],
            [TALKING_VIAL],
            [LANGUAGE_WRITTEN],
            [INTERPRETER_REQUIRED],
            [MEDIGAP_IDENTIFIER],
            [MTM_OPT_OUT],
            [DISPLAY_BOARD],
            [CONTACT_SMS],
            [CONTACT_PHONE],
            [CONTACT_EMAIL],
            [ADMIT_STATUS],
            [ALLERGY_REVIEW_DATE],
            [ALLERGY_REVIEW_EMPLOYEE_NUM],
            [CLINICAL_TRACK_NAME],
            [PASSPORT_IDENTIFICATION],
            [PASSPORT_COUNTRY],
            [MILITARY_IDENTIFICATION]
        FROM inserted;
    END;
END;
GO
