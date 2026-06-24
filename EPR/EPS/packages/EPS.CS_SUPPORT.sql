-- ============================================================================
-- Converted: Oracle Package EPS.CS_SUPPORT -> Azure SQL Stored Procedures
-- Conversion Date: 2026-05-25
-- Exception Mapping: Oracle RAISE_APPLICATION_ERROR codes preserved as
--   Oracle -2xxxx  --> SQL Server THROW 5xxxx  (e.g. -20500 -> 50500)
-- ============================================================================
-- Exception Code Reference:
--   50500 = excp_deleted_invalid / excp_no_chainid (dbu_address*)
--   50501 = excp_no_id             (dbu_address_full/dbu_address)
--   50503 = excp_rowcount_null     (dbu_address_full)
--   50504 = excp_rowcount_neg      (dbu_address_full)
--   50505 = excp_row_mismatch      (dbu_address_full/dbu_address)
--   50506 = OTHERS                 (dbu_address_full/dbu_address)
--   50507 = excp_no_chainid        (dbu_allergy/credit_card/disease/medical_condition/patient_emergency_contact/prior_adverse_reaction)
--   50508 = excp_no_id             (same group)
--   50509 = excp_rowcount_neg      (same group)
--   50510 = excp_rowcount_null     (same group)
--   50511 = excp_row_mismatch      (same group)
--   50512 = OTHERS / excp_no_chainid (dbu_patient_dls)
--   50513 = excp_no_chainid (dbu_patient) / excp_no_id (dbu_patient_dls)
--   50514 = excp_no_rxcomid        (dbu_patient/dbu_patient_dls)
--   50515 = excp_rowcount_neg (dbu_patient) / excp_inv_state_length (dbu_patient_dls)
--   50516 = excp_rowcount_null (dbu_patient) / excp_row_mismatch (dbu_patient_dls)
--   50517 = excp_row_mismatch (dbu_patient) / OTHERS (dbu_patient_dls)
--   50518 = OTHERS                 (dbu_patient)
--   50510 = excp_no_chainid        (dbu_patient_no_cf)
--   50511 = excp_bad_chainid       (dbu_patient_no_cf)
--   50512 = excp_no_nhinid         (dbu_patient_no_cf)
--   50513 = excp_bad_nhinid        (dbu_patient_no_cf)
--   50514 = excp_bad_no_cf_flag    (dbu_patient_no_cf)
--   50515 = excp_rowcount_null     (dbu_patient_no_cf)
--   50516 = excp_rowcount_neg      (dbu_patient_no_cf)
--   50517 = excp_row_mismatch      (dbu_patient_no_cf)
--   50518 = OTHERS                 (dbu_patient_no_cf)
--   50519 = excp_no_chainid        (dbu_rxtx/dbu_tplink_levelof)
--   50520 = excp_no_nhinid/excp_no_tplinkid/excp_no_levelof
--   50521 = excp_patient_tx        (dbu_rxtx)
--   50522 = excp_rowcount_neg      (dbu_rxtx)
--   50523 = excp_rowcount_null     (dbu_rxtx)
--   50524 = excp_row_mismatch      (dbu_rxtx)
--   50525 = OTHERS                 (dbu_rxtx/dbu_tplink_levelof)
-- ============================================================================

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_log_audit_dbu]
    @p_dbu_table VARCHAR(128),
    @p_dbu_parms VARCHAR(MAX),
    @p_dbu_rows  NUMERIC(18, 0),
    @p_sql_text  VARCHAR(MAX),
    @o_id        NUMERIC(18, 0) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @o_id = NEXT VALUE FOR [audit_dbu_log_seq];
    -- Insert and immediately commit independently so audit row persists even if caller rolls back
    BEGIN TRANSACTION;
    INSERT INTO [audit_dbu_log] ([id],[exec_time_stamp],[user_id],[dbu_table],[dbu_parms],[dbu_rows],[sql_text])
    VALUES (@o_id, SYSDATETIME(), SUSER_SNAME(), UPPER(@p_dbu_table), @p_dbu_parms, @p_dbu_rows, @p_sql_text);
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_log_error]
    @p_id    NUMERIC(18, 0),
    @p_error VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [audit_dbu_log] SET [error_text] = @p_error WHERE [id] = @p_id;
END;
GO

-- ============================================================================
-- dbu_address  (-20500 no_chainid/deleted_invalid, -20501 no_id,
--              -20503 rowcount_null, -20504 rowcount_neg,
--              -20505 row_mismatch, -20506 OTHERS)
-- ============================================================================
CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_address]
    @p_chainid NUMERIC(18, 0) = NULL,
    @p_id      NUMERIC(18, 0) = NULL,
    @p_numrows NUMERIC(18, 0) = NULL,
    @p_deleted VARCHAR(2)     = 'N'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_rowsproc INT;
    DECLARE @v_sql      NVARCHAR(2000);
    DECLARE @l_id       NUMERIC(18, 0);

    IF @p_chainid IS NULL THROW 50500, 'DBU [ADDRESS] must contain a CHAIN_ID', 1;
    IF @p_id      IS NULL THROW 50501, 'DBU [ADDRESS] must contain an ID', 1;
    IF @p_numrows IS NULL THROW 50503, 'DBU [ADDRESS] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0     THROW 50504, 'DBU [ADDRESS] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN ('Y','N')
        THROW 50500, 'DBU [ADDRESS] deleted flag is invalid', 1;

    SET @v_sql = N'UPDATE [address] SET [deleted]=''' + UPPER(@p_deleted)
               + N''' WHERE [chain_id]=@chain_id AND [id]=@id';

    EXEC [EPS].[CS_SUPPORT_log_audit_dbu]
        @p_dbu_table='ADDRESS',
        @p_dbu_parms='chain_id='+CONVERT(VARCHAR(50),@p_chainid)+', id='+CONVERT(VARCHAR(50),@p_id),
        @p_dbu_rows=@p_numrows,
        @p_sql_text=@v_sql+CHAR(10)+'Using: '+CONVERT(VARCHAR(50),@p_chainid)+', '+CONVERT(VARCHAR(50),@p_id),
        @o_id=@l_id OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sp_executesql @v_sql, N'@chain_id NUMERIC(18,0),@id NUMERIC(18,0)', @chain_id=@p_chainid, @id=@p_id;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc
        BEGIN
            ROLLBACK TRANSACTION;
            EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
                @p_error='DBU [ADDRESS] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows but was expecting '+CONVERT(VARCHAR(50),@p_numrows)+' rows';
            THROW 50505, 'DBU [ADDRESS] row count mismatch', 1;
        END
        COMMIT TRANSACTION;
        PRINT 'DBU [ADDRESS] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows out of '+CONVERT(VARCHAR(50),@p_numrows)+' rows expected.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
            @p_error='DBU [ADDRESS] unhandled exception encountered: '+ERROR_MESSAGE();
        THROW; -- -20506
    END CATCH
END;
GO

-- ============================================================================
-- dbu_address_full  (-20500 no_chainid/deleted_invalid, -20501 no_id,
--                   -20503 rowcount_null, -20504 rowcount_neg,
--                   -20505 row_mismatch, -20506 OTHERS)
-- ============================================================================
CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_address_full]
    @p_chainid        NUMERIC(18, 0) = NULL,
    @p_id             NUMERIC(18, 0) = NULL,
    @p_numrows        NUMERIC(18, 0) = NULL,
    @p_address_line1  VARCHAR(255)   = NULL,
    @p_city           VARCHAR(255)   = NULL,
    @p_state          VARCHAR(10)    = NULL,
    @p_zip            VARCHAR(20)    = NULL,
    @p_home_area_code VARCHAR(10)    = NULL,
    @p_phone          NUMERIC(18, 0) = NULL,
    @p_deleted        VARCHAR(2)     = 'N'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_rowsproc INT;
    DECLARE @v_sql      NVARCHAR(4000);
    DECLARE @l_id       NUMERIC(18, 0);

    IF @p_chainid IS NULL THROW 50500, 'DBU [Full ADDRESS] must contain a CHAIN_ID', 1;
    IF @p_id      IS NULL THROW 50501, 'DBU [Full ADDRESS] must contain an ID', 1;
    IF @p_numrows IS NULL THROW 50503, 'DBU [Full ADDRESS] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0     THROW 50504, 'DBU [Full ADDRESS] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN ('Y','N')
        THROW 50500, 'DBU [Full ADDRESS] deleted flag is invalid', 1;

    SET @v_sql = N'UPDATE [address] SET ';
    IF @p_deleted        IS NOT NULL SET @v_sql += N' [deleted]='''          + UPPER(@p_deleted)                         + N''',';
    IF @p_address_line1  IS NOT NULL SET @v_sql += N' [address_line1]='''    + REPLACE(@p_address_line1,'''','''''')      + N''',';
    IF @p_state          IS NOT NULL SET @v_sql += N' [state]='''            + REPLACE(@p_state,'''','''''')              + N''',';
    IF @p_city           IS NOT NULL SET @v_sql += N' [city]='''             + REPLACE(@p_city,'''','''''')               + N''',';
    IF @p_zip            IS NOT NULL SET @v_sql += N' [postal_code]='''      + REPLACE(@p_zip,'''','''''')                + N''',';
    IF @p_home_area_code IS NOT NULL SET @v_sql += N' [home_area_code]='''   + REPLACE(@p_home_area_code,'''','''''')     + N''',';
    IF @p_phone          IS NOT NULL SET @v_sql += N' [home_phone]='''       + CONVERT(VARCHAR(50),@p_phone)              + N''',';
    IF RIGHT(@v_sql,1)=',' SET @v_sql = LEFT(@v_sql,LEN(@v_sql)-1);
    SET @v_sql += N' WHERE [chain_id]=@chain_id AND [id]=@id';

    EXEC [EPS].[CS_SUPPORT_log_audit_dbu]
        @p_dbu_table='ADDRESS',
        @p_dbu_parms='chain_id='+CONVERT(VARCHAR(50),@p_chainid)+', id='+CONVERT(VARCHAR(50),@p_id)
            +', flag='+COALESCE(CONVERT(VARCHAR(50),@p_deleted),'<NULL>')
            +', address_line1='+COALESCE(@p_address_line1,'<NULL>')
            +', state='+COALESCE(@p_state,'<NULL>')
            +', home_area_code='+COALESCE(@p_home_area_code,'<NULL>')
            +', phone='+COALESCE(CONVERT(VARCHAR(50),@p_phone),'<NULL>'),
        @p_dbu_rows=@p_numrows,
        @p_sql_text=@v_sql+CHAR(10)+'Using: '+CONVERT(VARCHAR(50),@p_chainid)+', '+CONVERT(VARCHAR(50),@p_id),
        @o_id=@l_id OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sp_executesql @v_sql, N'@chain_id NUMERIC(18,0),@id NUMERIC(18,0)', @chain_id=@p_chainid, @id=@p_id;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc
        BEGIN
            ROLLBACK TRANSACTION;
            EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
                @p_error='DBU [Full ADDRESS] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows but was expecting '+CONVERT(VARCHAR(50),@p_numrows)+' rows';
            THROW 50505, 'DBU [Full ADDRESS] row count mismatch', 1;
        END
        COMMIT TRANSACTION;
        PRINT 'DBU [Full ADDRESS] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows out of '+CONVERT(VARCHAR(50),@p_numrows)+' rows expected.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
            @p_error='DBU [Full ADDRESS] unhandled exception encountered: '+ERROR_MESSAGE();
        THROW; -- -20506
    END CATCH
END;
GO

-- ============================================================================
-- dbu_allergy  (-20500 deleted_invalid, -20507 no_chainid, -20508 no_id,
--              -20509 rowcount_neg, -20510 rowcount_null,
--              -20511 row_mismatch, -20512 OTHERS)
-- ============================================================================
CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_allergy]
    @p_chainid NUMERIC(18, 0) = NULL,
    @p_id      NUMERIC(18, 0) = NULL,
    @p_numrows NUMERIC(18, 0) = NULL,
    @p_deleted VARCHAR(2)     = 'N'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_rowsproc INT;
    DECLARE @v_sql      NVARCHAR(2000);
    DECLARE @l_id       NUMERIC(18, 0);

    IF @p_chainid IS NULL THROW 50507, 'DBU [ALLERGY] must contain a CHAIN_ID', 1;
    IF @p_id      IS NULL THROW 50508, 'DBU [ALLERGY] must contain an ID', 1;
    IF @p_numrows IS NULL THROW 50510, 'DBU [ALLERGY] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0     THROW 50509, 'DBU [ALLERGY] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN ('Y','N')
        THROW 50500, 'DBU [ALLERGY] deleted flag is invalid', 1;

    SET @v_sql = N'UPDATE [allergy] SET [deleted]=''' + UPPER(@p_deleted)
               + N''' WHERE [chain_id]=@chain_id AND [id]=@id';

    EXEC [EPS].[CS_SUPPORT_log_audit_dbu]
        @p_dbu_table='ALLERGY',
        @p_dbu_parms='chain_id='+CONVERT(VARCHAR(50),@p_chainid)+', id='+CONVERT(VARCHAR(50),@p_id),
        @p_dbu_rows=@p_numrows,
        @p_sql_text=@v_sql+CHAR(10)+'Using: '+CONVERT(VARCHAR(50),@p_chainid)+', '+CONVERT(VARCHAR(50),@p_id),
        @o_id=@l_id OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sp_executesql @v_sql, N'@chain_id NUMERIC(18,0),@id NUMERIC(18,0)', @chain_id=@p_chainid, @id=@p_id;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc
        BEGIN
            ROLLBACK TRANSACTION;
            EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
                @p_error='DBU [ALLERGY] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows but was expecting '+CONVERT(VARCHAR(50),@p_numrows)+' rows';
            THROW 50511, 'DBU [ALLERGY] row count mismatch', 1;
        END
        COMMIT TRANSACTION;
        PRINT 'DBU [ALLERGY] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows out of '+CONVERT(VARCHAR(50),@p_numrows)+' rows expected.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
            @p_error='DBU [ALLERGY] unhandled exception encountered: '+ERROR_MESSAGE();
        THROW; -- -20512
    END CATCH
END;
GO

-- ============================================================================
-- dbu_credit_card  (-20500 no_token, -20507 no_chainid, -20508 no_id_patient,
--                  -20509 rowcount_neg, -20510 rowcount_null,
--                  -20511 row_mismatch, -20512 OTHERS)
-- ============================================================================
CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_credit_card]
    @p_chainid   NUMERIC(18, 0) = NULL,
    @p_patientid NUMERIC(18, 0) = NULL,
    @p_tokennbr  VARCHAR(255)   = NULL,
    @p_numrows   NUMERIC(18, 0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_rowsproc INT;
    DECLARE @v_sql      NVARCHAR(2000);
    DECLARE @l_id       NUMERIC(18, 0);

    IF @p_chainid   IS NULL THROW 50507, 'DBU [CREDIT_CARD] must contain a CHAIN_ID', 1;
    IF @p_patientid IS NULL THROW 50508, 'DBU [CREDIT_CARD] must contain an ID_PATIENT', 1;
    IF @p_tokennbr  IS NULL THROW 50500, 'DBU [CREDIT_CARD] must contain a TOKEN_NUMBER', 1;
    IF @p_numrows   IS NULL THROW 50510, 'DBU [CREDIT_CARD] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0       THROW 50509, 'DBU [CREDIT_CARD] must be given a rowcount which is > 0', 1;

    SET @v_sql = N'DELETE FROM [PATIENT_CREDIT_CARD] WHERE [chain_id]=@chain_id AND [id_patient]=@id_patient AND [token_number]=@token_number';

    EXEC [EPS].[CS_SUPPORT_log_audit_dbu]
        @p_dbu_table='CREDIT_CARD',
        @p_dbu_parms='chain_id='+CONVERT(VARCHAR(50),@p_chainid)+', id_patient='+CONVERT(VARCHAR(50),@p_patientid)+', token_number='+@p_tokennbr,
        @p_dbu_rows=@p_numrows,
        @p_sql_text=@v_sql+CHAR(10)+'Using: '+CONVERT(VARCHAR(50),@p_chainid)+', '+CONVERT(VARCHAR(50),@p_patientid)+', '+@p_tokennbr,
        @o_id=@l_id OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sp_executesql @v_sql,
            N'@chain_id NUMERIC(18,0),@id_patient NUMERIC(18,0),@token_number VARCHAR(255)',
            @chain_id=@p_chainid, @id_patient=@p_patientid, @token_number=@p_tokennbr;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc
        BEGIN
            ROLLBACK TRANSACTION;
            EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
                @p_error='DBU [CREDIT_CARD] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows but was expecting '+CONVERT(VARCHAR(50),@p_numrows)+' rows';
            THROW 50511, 'DBU [CREDIT_CARD] row count mismatch', 1;
        END
        COMMIT TRANSACTION;
        PRINT 'DBU [CREDIT_CARD] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows out of '+CONVERT(VARCHAR(50),@p_numrows)+' rows expected.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
            @p_error='DBU [CREDIT_CARD] unhandled exception encountered: '+ERROR_MESSAGE();
        THROW; -- -20512
    END CATCH
END;
GO

-- ============================================================================
-- dbu_disease  (same Oracle codes as dbu_allergy: -20507..-20512)
-- ============================================================================
CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_disease]
    @p_chainid NUMERIC(18, 0) = NULL,
    @p_id      NUMERIC(18, 0) = NULL,
    @p_numrows NUMERIC(18, 0) = NULL,
    @p_deleted VARCHAR(2)     = 'N'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_rowsproc INT;
    DECLARE @v_sql      NVARCHAR(2000);
    DECLARE @l_id       NUMERIC(18, 0);

    IF @p_chainid IS NULL THROW 50507, 'DBU [DISEASE] must contain a CHAIN_ID', 1;
    IF @p_id      IS NULL THROW 50508, 'DBU [DISEASE] must contain an ID', 1;
    IF @p_numrows IS NULL THROW 50510, 'DBU [DISEASE] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0     THROW 50509, 'DBU [DISEASE] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN ('Y','N')
        THROW 50500, 'DBU [DISEASE] deleted flag is invalid', 1;

    SET @v_sql = N'UPDATE [disease] SET [deleted]=''' + UPPER(@p_deleted)
               + N''' WHERE [chain_id]=@chain_id AND [id]=@id';

    EXEC [EPS].[CS_SUPPORT_log_audit_dbu]
        @p_dbu_table='DISEASE',
        @p_dbu_parms='chain_id='+CONVERT(VARCHAR(50),@p_chainid)+', id='+CONVERT(VARCHAR(50),@p_id),
        @p_dbu_rows=@p_numrows,
        @p_sql_text=@v_sql+CHAR(10)+'Using: '+CONVERT(VARCHAR(50),@p_chainid)+', '+CONVERT(VARCHAR(50),@p_id),
        @o_id=@l_id OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sp_executesql @v_sql, N'@chain_id NUMERIC(18,0),@id NUMERIC(18,0)', @chain_id=@p_chainid, @id=@p_id;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc
        BEGIN
            ROLLBACK TRANSACTION;
            EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
                @p_error='DBU [DISEASE] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows but was expecting '+CONVERT(VARCHAR(50),@p_numrows)+' rows';
            THROW 50511, 'DBU [DISEASE] row count mismatch', 1;
        END
        COMMIT TRANSACTION;
        PRINT 'DBU [DISEASE] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows out of '+CONVERT(VARCHAR(50),@p_numrows)+' rows expected.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
            @p_error='DBU [DISEASE] unhandled exception encountered: '+ERROR_MESSAGE();
        THROW; -- -20512
    END CATCH
END;
GO

-- ============================================================================
-- dbu_medical_condition  (same Oracle codes: -20507..-20512)
-- ============================================================================
CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_medical_condition]
    @p_chainid NUMERIC(18, 0) = NULL,
    @p_id      NUMERIC(18, 0) = NULL,
    @p_numrows NUMERIC(18, 0) = NULL,
    @p_deleted VARCHAR(2)     = 'N'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_rowsproc INT;
    DECLARE @v_sql      NVARCHAR(2000);
    DECLARE @l_id       NUMERIC(18, 0);

    IF @p_chainid IS NULL THROW 50507, 'DBU [MEDICAL_CONDITION] must contain a CHAIN_ID', 1;
    IF @p_id      IS NULL THROW 50508, 'DBU [MEDICAL_CONDITION] must contain an ID', 1;
    IF @p_numrows IS NULL THROW 50510, 'DBU [MEDICAL_CONDITION] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0     THROW 50509, 'DBU [MEDICAL_CONDITION] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN ('Y','N')
        THROW 50500, 'DBU [MEDICAL_CONDITION] deleted flag is invalid', 1;

    SET @v_sql = N'UPDATE [medical_condition] SET [deleted]=''' + UPPER(@p_deleted)
               + N''' WHERE [chain_id]=@chain_id AND [id]=@id';

    EXEC [EPS].[CS_SUPPORT_log_audit_dbu]
        @p_dbu_table='MEDICAL_CONDITION',
        @p_dbu_parms='chain_id='+CONVERT(VARCHAR(50),@p_chainid)+', id='+CONVERT(VARCHAR(50),@p_id),
        @p_dbu_rows=@p_numrows,
        @p_sql_text=@v_sql+CHAR(10)+'Using: '+CONVERT(VARCHAR(50),@p_chainid)+', '+CONVERT(VARCHAR(50),@p_id),
        @o_id=@l_id OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sp_executesql @v_sql, N'@chain_id NUMERIC(18,0),@id NUMERIC(18,0)', @chain_id=@p_chainid, @id=@p_id;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc
        BEGIN
            ROLLBACK TRANSACTION;
            EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
                @p_error='DBU [MEDICAL_CONDITION] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows but was expecting '+CONVERT(VARCHAR(50),@p_numrows)+' rows';
            THROW 50511, 'DBU [MEDICAL_CONDITION] row count mismatch', 1;
        END
        COMMIT TRANSACTION;
        PRINT 'DBU [MEDICAL_CONDITION] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows out of '+CONVERT(VARCHAR(50),@p_numrows)+' rows expected.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
            @p_error='DBU [MEDICAL_CONDITION] unhandled exception encountered: '+ERROR_MESSAGE();
        THROW; -- -20512
    END CATCH
END;
GO

-- ============================================================================
-- dbu_patient  (-20500 deleted_invalid, -20513 no_chainid, -20514 no_rxcomid,
--              -20515 rowcount_neg, -20516 rowcount_null,
--              -20517 row_mismatch, -20518 OTHERS)
-- ============================================================================
CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_patient]
    @p_chainid NUMERIC(18, 0) = NULL,
    @p_rxcomid NUMERIC(18, 0) = NULL,
    @p_numrows NUMERIC(18, 0) = NULL,
    @p_deleted VARCHAR(2)     = 'N'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_rowsproc INT;
    DECLARE @v_sql      NVARCHAR(2000);
    DECLARE @l_id       NUMERIC(18, 0);

    IF @p_chainid IS NULL THROW 50513, 'DBU [PATIENT] must contain a CHAIN_ID', 1;
    IF @p_rxcomid IS NULL THROW 50514, 'DBU [PATIENT] must contain an RX_COM_ID', 1;
    IF @p_numrows IS NULL THROW 50516, 'DBU [PATIENT] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0     THROW 50515, 'DBU [PATIENT] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN ('Y','N')
        THROW 50500, 'DBU [PATIENT] deleted flag is invalid', 1;

    SET @v_sql = N'UPDATE [patient] SET [multibirth]=''' + UPPER(@p_deleted)
               + N''' WHERE [chain_id]=@chain_id AND [rx_com_id]=@rx_com_id';

    EXEC [EPS].[CS_SUPPORT_log_audit_dbu]
        @p_dbu_table='PATIENT',
        @p_dbu_parms='chain_id='+CONVERT(VARCHAR(50),@p_chainid)+', rx_com_id='+CONVERT(VARCHAR(50),@p_rxcomid),
        @p_dbu_rows=@p_numrows,
        @p_sql_text=@v_sql+CHAR(10)+'Using: '+CONVERT(VARCHAR(50),@p_chainid)+', '+CONVERT(VARCHAR(50),@p_rxcomid),
        @o_id=@l_id OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sp_executesql @v_sql, N'@chain_id NUMERIC(18,0),@rx_com_id NUMERIC(18,0)', @chain_id=@p_chainid, @rx_com_id=@p_rxcomid;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc
        BEGIN
            ROLLBACK TRANSACTION;
            EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
                @p_error='DBU [PATIENT] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows but was expecting '+CONVERT(VARCHAR(50),@p_numrows)+' rows';
            THROW 50517, 'DBU [PATIENT] row count mismatch', 1;
        END
        COMMIT TRANSACTION;
        PRINT 'DBU [PATIENT] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows out of '+CONVERT(VARCHAR(50),@p_numrows)+' rows expected.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
            @p_error='DBU [PATIENT] unhandled exception encountered: '+ERROR_MESSAGE();
        THROW; -- -20518
    END CATCH
END;
GO

-- ============================================================================
-- dbu_patient_dls  (-20512 no_chainid, -20513 no_id, -20514 no_rxcomid,
--                  -20515 inv_state_length, -20516 row_mismatch, -20517 OTHERS)
-- ============================================================================
CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_patient_dls]
    @p_chainid NUMERIC(18, 0) = NULL,
    @p_id      NUMERIC(18, 0) = NULL,
    @p_rxcomid NUMERIC(18, 0) = NULL,
    @p_state   VARCHAR(10)    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_rowsproc INT;
    DECLARE @v_sql      NVARCHAR(2000);
    DECLARE @v_numrows  INT            = 1;
    DECLARE @l_id       NUMERIC(18, 0);

    IF @p_chainid IS NULL THROW 50512, 'DBU [PATIENT_DLS] must contain a CHAIN_ID', 1;
    IF @p_id      IS NULL THROW 50513, 'DBU [PATIENT_DLS] must contain an ID', 1;
    IF @p_rxcomid IS NULL THROW 50514, 'DBU [PATIENT_DLS] must contain an RX_COM_ID', 1;
    IF @p_state IS NOT NULL AND LEN(@p_state) <> 2
        THROW 50515, 'DBU [PATIENT_DLS] must be given a two character state', 1;

    SET @v_sql = N'UPDATE [patient] SET [driver_license_state]='
               + CASE WHEN @p_state IS NULL THEN N'NULL' ELSE N''''+UPPER(@p_state)+N'''' END
               + N' WHERE [chain_id]=@chain_id AND [id]=@id AND [rx_com_id]=@rx_com_id';

    EXEC [EPS].[CS_SUPPORT_log_audit_dbu]
        @p_dbu_table='PATIENT',
        @p_dbu_parms='chain_id='+CONVERT(VARCHAR(50),@p_chainid)+', id='+CONVERT(VARCHAR(50),@p_id)+', rx_com_id='+CONVERT(VARCHAR(50),@p_rxcomid),
        @p_dbu_rows=1,
        @p_sql_text=@v_sql+CHAR(10)+'Using: '+CONVERT(VARCHAR(50),@p_chainid)+', '+CONVERT(VARCHAR(50),@p_id)+', '+CONVERT(VARCHAR(50),@p_rxcomid),
        @o_id=@l_id OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sp_executesql @v_sql,
            N'@chain_id NUMERIC(18,0),@id NUMERIC(18,0),@rx_com_id NUMERIC(18,0)',
            @chain_id=@p_chainid, @id=@p_id, @rx_com_id=@p_rxcomid;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @v_numrows <> @v_rowsproc
        BEGIN
            ROLLBACK TRANSACTION;
            EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
                @p_error='DBU [PATIENT_DLS] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows but was expecting '+CONVERT(VARCHAR(50),@v_numrows)+' rows';
            THROW 50516, 'DBU [PATIENT_DLS] row count mismatch', 1;
        END
        COMMIT TRANSACTION;
        PRINT 'DBU [PATIENT_DLS] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows out of '+CONVERT(VARCHAR(50),@v_numrows)+' rows expected.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
            @p_error='DBU [PATIENT_DLS] unhandled exception encountered: '+ERROR_MESSAGE();
        THROW; -- -20517
    END CATCH
END;
GO

-- ============================================================================
-- dbu_patient_emergency_contact  (-20500 no_phone, -20507 no_chainid,
--   -20508 no_id, -20509 rowcount_neg, -20510 rowcount_null,
--   -20511 row_mismatch, -20512 OTHERS)
-- ============================================================================
CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_patient_emergency_contact]
    @p_chainid NUMERIC(18, 0) = NULL,
    @p_id      NUMERIC(18, 0) = NULL,
    @p_numrows NUMERIC(18, 0) = NULL,
    @p_phone   VARCHAR(50)    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_rowsproc INT;
    DECLARE @v_sql      NVARCHAR(2000);
    DECLARE @l_id       NUMERIC(18, 0);

    IF @p_chainid IS NULL THROW 50507, 'DBU [PATIENT_EMERGENCY_CONTACT] must contain a CHAIN_ID', 1;
    IF @p_id      IS NULL THROW 50508, 'DBU [PATIENT_EMERGENCY_CONTACT] must contain an ID', 1;
    IF @p_numrows IS NULL THROW 50510, 'DBU [PATIENT_EMERGENCY_CONTACT] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0     THROW 50509, 'DBU [PATIENT_EMERGENCY_CONTACT] must be given a rowcount which is > 0', 1;
    IF @p_phone   IS NULL THROW 50500, 'DBU [PATIENT_EMERGENCY_CONTACT] must contain a PHONE_NUMBER', 1;

    SET @v_sql = N'UPDATE [patient_emergency_contact] SET [phone_number]='''+REPLACE(@p_phone,'''','''''')
               + N''' WHERE [chain_id]=@chain_id AND [id]=@id';

    EXEC [EPS].[CS_SUPPORT_log_audit_dbu]
        @p_dbu_table='PATIENT_EMERGENCY_CONTACT',
        @p_dbu_parms='chain_id='+CONVERT(VARCHAR(50),@p_chainid)+', id='+CONVERT(VARCHAR(50),@p_id),
        @p_dbu_rows=@p_numrows,
        @p_sql_text=@v_sql+CHAR(10)+'Using: '+CONVERT(VARCHAR(50),@p_chainid)+', '+CONVERT(VARCHAR(50),@p_id),
        @o_id=@l_id OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sp_executesql @v_sql, N'@chain_id NUMERIC(18,0),@id NUMERIC(18,0)', @chain_id=@p_chainid, @id=@p_id;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc
        BEGIN
            ROLLBACK TRANSACTION;
            EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
                @p_error='DBU [PATIENT_EMERGENCY_CONTACT] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows but was expecting '+CONVERT(VARCHAR(50),@p_numrows)+' rows';
            THROW 50511, 'DBU [PATIENT_EMERGENCY_CONTACT] row count mismatch', 1;
        END
        COMMIT TRANSACTION;
        PRINT 'DBU [PATIENT_EMERGENCY_CONTACT] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows out of '+CONVERT(VARCHAR(50),@p_numrows)+' rows expected.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
            @p_error='DBU [PATIENT_EMERGENCY_CONTACT] unhandled exception encountered: '+ERROR_MESSAGE();
        THROW; -- -20512
    END CATCH
END;
GO

-- ============================================================================
-- dbu_patient_no_cf  (-20510 no_chainid, -20511 bad_chainid,
--   -20512 no_nhinid, -20513 bad_nhinid, -20514 bad_no_cf_flag,
--   -20515 rowcount_null, -20516 rowcount_neg,
--   -20517 row_mismatch, -20518 OTHERS)
-- ============================================================================
CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_patient_no_cf]
    @p_chainid    NUMERIC(18, 0) = NULL,
    @p_nhinid     NUMERIC(18, 0) = NULL,
    @p_no_cf_flag CHAR(1)        = NULL,
    @p_numrows    NUMERIC(18, 0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @f_count    INT;
    DECLARE @v_rowsproc INT;
    DECLARE @v_sql      NVARCHAR(2000);
    DECLARE @l_id       NUMERIC(18, 0);

    IF @p_chainid IS NULL THROW 50510, 'DBU [PATIENT_NO_CF] must contain a CHAIN_ID', 1;

    SELECT @f_count = COUNT(*) FROM [eps_sec_chain] WHERE [chain_nhin_id] = @p_chainid;
    IF @f_count = 0 THROW 50511, 'DBU [PATIENT_NO_CF] must contain a valid CHAIN_ID', 1;

    IF @p_nhinid IS NULL THROW 50512, 'DBU [PATIENT_NO_CF] must contain an NHIN_ID', 1;

    SELECT @f_count = COUNT(*) FROM [eps_sec_store]
     WHERE [chain_nhin_id]=@p_chainid AND [store_nhin_id]=@p_nhinid;
    IF @f_count = 0 THROW 50513, 'DBU [PATIENT_NO_CF] must contain a valid CHAIN_ID and NHIN_ID combination', 1;

    IF @p_no_cf_flag IS NULL OR @p_no_cf_flag NOT IN ('Y','N')
        THROW 50514, 'DBU [PATIENT_NO_CF] must contain a NO_CF_FLAG of Y or N', 1;
    IF @p_numrows IS NULL THROW 50515, 'DBU [PATIENT_NO_CF] must contain an expected count of the rows in the affected dataset', 1;
    IF @p_numrows < 0     THROW 50516, 'DBU [PATIENT_NO_CF] must be given a rowcount which is > 0', 1;

    SET @v_sql = N'UPDATE [patient] SET [no_cf]=''' + @p_no_cf_flag
               + N''' WHERE [chain_id]=@chain_id AND [nhin_id]=@nhin_id ';
    IF @p_no_cf_flag='N' SET @v_sql += N'AND [no_cf]<>''N''';
    ELSE                  SET @v_sql += N'AND ([no_cf] IS NULL OR [no_cf]<>''Y'')';

    EXEC [EPS].[CS_SUPPORT_log_audit_dbu]
        @p_dbu_table='PATIENT',
        @p_dbu_parms='chain_id='+CONVERT(VARCHAR(50),@p_chainid)+', nhin_id='+CONVERT(VARCHAR(50),@p_nhinid)+', no_cf_flag='+@p_no_cf_flag,
        @p_dbu_rows=@p_numrows,
        @p_sql_text=@v_sql+CHAR(10)+'Using: '+CONVERT(VARCHAR(50),@p_chainid)+', '+CONVERT(VARCHAR(50),@p_nhinid),
        @o_id=@l_id OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sp_executesql @v_sql, N'@chain_id NUMERIC(18,0),@nhin_id NUMERIC(18,0)', @chain_id=@p_chainid, @nhin_id=@p_nhinid;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc
        BEGIN
            ROLLBACK TRANSACTION;
            EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
                @p_error='DBU [PATIENT_NO_CF] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows but was expecting '+CONVERT(VARCHAR(50),@p_numrows)+' rows';
            THROW 50517, 'DBU [PATIENT_NO_CF] row count mismatch', 1;
        END
        COMMIT TRANSACTION;
        PRINT 'DBU [PATIENT_NO_CF] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows out of '+CONVERT(VARCHAR(50),@p_numrows)+' rows expected.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
            @p_error='DBU [PATIENT_NO_CF] unhandled exception encountered: '+ERROR_MESSAGE();
        THROW; -- -20518
    END CATCH
END;
GO

-- ============================================================================
-- dbu_prior_adverse_reaction  (same Oracle codes as dbu_allergy: -20507..-20512)
-- ============================================================================
CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_prior_adverse_reaction]
    @p_chainid NUMERIC(18, 0) = NULL,
    @p_id      NUMERIC(18, 0) = NULL,
    @p_numrows NUMERIC(18, 0) = NULL,
    @p_deleted VARCHAR(2)     = 'N'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_rowsproc INT;
    DECLARE @v_sql      NVARCHAR(2000);
    DECLARE @l_id       NUMERIC(18, 0);

    IF @p_chainid IS NULL THROW 50507, 'DBU [PRIOR_ADVERSE_REACTION] must contain a CHAIN_ID', 1;
    IF @p_id      IS NULL THROW 50508, 'DBU [PRIOR_ADVERSE_REACTION] must contain an ID', 1;
    IF @p_numrows IS NULL THROW 50510, 'DBU [PRIOR_ADVERSE_REACTION] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0     THROW 50509, 'DBU [PRIOR_ADVERSE_REACTION] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN ('Y','N')
        THROW 50500, 'DBU [PRIOR_ADVERSE_REACTION] deleted flag is invalid', 1;

    SET @v_sql = N'UPDATE [prior_adverse_reaction] SET [deleted]=''' + UPPER(@p_deleted)
               + N''' WHERE [chain_id]=@chain_id AND [id]=@id';

    EXEC [EPS].[CS_SUPPORT_log_audit_dbu]
        @p_dbu_table='PRIOR_ADVERSE_REACTION',
        @p_dbu_parms='chain_id='+CONVERT(VARCHAR(50),@p_chainid)+', id='+CONVERT(VARCHAR(50),@p_id),
        @p_dbu_rows=@p_numrows,
        @p_sql_text=@v_sql+CHAR(10)+'Using: '+CONVERT(VARCHAR(50),@p_chainid)+', '+CONVERT(VARCHAR(50),@p_id),
        @o_id=@l_id OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sp_executesql @v_sql, N'@chain_id NUMERIC(18,0),@id NUMERIC(18,0)', @chain_id=@p_chainid, @id=@p_id;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc
        BEGIN
            ROLLBACK TRANSACTION;
            EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
                @p_error='DBU [PRIOR_ADVERSE_REACTION] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows but was expecting '+CONVERT(VARCHAR(50),@p_numrows)+' rows';
            THROW 50511, 'DBU [PRIOR_ADVERSE_REACTION] row count mismatch', 1;
        END
        COMMIT TRANSACTION;
        PRINT 'DBU [PRIOR_ADVERSE_REACTION] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows out of '+CONVERT(VARCHAR(50),@p_numrows)+' rows expected.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
            @p_error='DBU [PRIOR_ADVERSE_REACTION] unhandled exception encountered: '+ERROR_MESSAGE();
        THROW; -- -20512
    END CATCH
END;
GO

-- ============================================================================
-- dbu_rxtx  (-20500 deleted_invalid, -20519 no_chainid, -20520 no_nhinid,
--            -20521 patient_tx, -20522 rowcount_neg, -20523 rowcount_null,
--            -20524 row_mismatch, -20525 OTHERS)
-- ============================================================================
CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_rxtx]
    @p_chainid   NUMERIC(18, 0) = NULL,
    @p_nhinid    NUMERIC(18, 0) = NULL,
    @p_idpatient NUMERIC(18, 0) = NULL,
    @p_txnumber  NUMERIC(18, 0) = NULL,
    @p_numrows   NUMERIC(18, 0) = NULL,
    @p_deleted   VARCHAR(2)     = 'N'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_rowsproc INT;
    DECLARE @v_sql      NVARCHAR(2000);
    DECLARE @l_id       NUMERIC(18, 0);

    IF @p_chainid IS NULL THROW 50519, 'DBU [RX_TX] must contain a CHAIN_ID', 1;
    IF @p_nhinid  IS NULL THROW 50520, 'DBU [RX_TX] must contain an NHIN_ID', 1;
    IF @p_txnumber IS NOT NULL AND @p_idpatient IS NULL
        THROW 50521, 'DBU [RX_TX] must contain an ID_PATIENT if TX_NUMBER is specified', 1;
    IF @p_numrows IS NULL THROW 50523, 'DBU [RX_TX] must contain a count of the rows in the dataset', 1;
    IF @p_numrows < 0     THROW 50522, 'DBU [RX_TX] must be given a rowcount which is > 0', 1;
    IF @p_deleted IS NOT NULL AND UPPER(@p_deleted) NOT IN ('Y','N')
        THROW 50500, 'DBU [RX_TX] deleted flag is invalid', 1;

    SET @v_sql = N'UPDATE [rx_tx] SET [rx_deleted]='''+UPPER(@p_deleted)+N''', [tx_deleted]='''+UPPER(@p_deleted)
               + N''' WHERE [chain_id]=@chain_id AND [nhin_id]=@nhin_id';
    IF @p_idpatient IS NOT NULL SET @v_sql += N' AND [id_patient]=@id_patient';
    IF @p_txnumber  IS NOT NULL SET @v_sql += N' AND [tx_number]=@tx_number';

    EXEC [EPS].[CS_SUPPORT_log_audit_dbu]
        @p_dbu_table='RX_TX',
        @p_dbu_parms='chain_id='+CONVERT(VARCHAR(50),@p_chainid)+', nhin_id='+CONVERT(VARCHAR(50),@p_nhinid)
            +', id_patient='+COALESCE(CONVERT(VARCHAR(50),@p_idpatient),'<NULL>')
            +', tx_number='+COALESCE(CONVERT(VARCHAR(50),@p_txnumber),'<NULL>'),
        @p_dbu_rows=@p_numrows,
        @p_sql_text=@v_sql+CHAR(10)+'Using: '+CONVERT(VARCHAR(50),@p_chainid)+', '+CONVERT(VARCHAR(50),@p_nhinid)
            +CASE WHEN @p_idpatient IS NOT NULL THEN ', '+CONVERT(VARCHAR(50),@p_idpatient) ELSE '' END
            +CASE WHEN @p_txnumber  IS NOT NULL THEN ', '+CONVERT(VARCHAR(50),@p_txnumber)  ELSE '' END,
        @o_id=@l_id OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sp_executesql @v_sql,
            N'@chain_id NUMERIC(18,0),@nhin_id NUMERIC(18,0),@id_patient NUMERIC(18,0),@tx_number NUMERIC(18,0)',
            @chain_id=@p_chainid, @nhin_id=@p_nhinid, @id_patient=@p_idpatient, @tx_number=@p_txnumber;
        SET @v_rowsproc = @@ROWCOUNT;
        IF @p_numrows <> @v_rowsproc
        BEGIN
            ROLLBACK TRANSACTION;
            EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
                @p_error='DBU [RX_TX] processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows but was expecting '+CONVERT(VARCHAR(50),@p_numrows)+' rows';
            THROW 50524, 'DBU [RX_TX] row count mismatch', 1;
        END
        COMMIT TRANSACTION;
        PRINT '[RX_TX] DBU processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows out of '+CONVERT(VARCHAR(50),@p_numrows)+' rows expected.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC [EPS].[CS_SUPPORT_log_error] @p_id=@l_id,
            @p_error='DBU [RX_TX] unhandled exception encountered: '+ERROR_MESSAGE();
        THROW; -- -20525
    END CATCH
END;
GO

-- ============================================================================
-- dbu_tplink_levelof  (-20519 no_chainid, -20520 no_tplinkid/no_levelof,
--                      -20525 OTHERS)
-- ============================================================================
CREATE OR ALTER PROCEDURE [EPS].[CS_SUPPORT_dbu_tplink_levelof]
    @p_chainid  NUMERIC(18, 0) = NULL,
    @p_tplinkid NUMERIC(18, 0) = NULL,
    @p_levelof  VARCHAR(255)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_rowsproc INT;
    DECLARE @v_sql      NVARCHAR(2000);

    IF @p_chainid  IS NULL THROW 50519, 'DBU [TP_LINK] must contain a CHAIN_ID', 1;
    IF @p_tplinkid IS NULL THROW 50520, 'DBU [TP_LINK] must contain a TP_LINK_ID', 1;
    IF @p_levelof  IS NULL THROW 50520, 'DBU [TP_LINK] must contain a LEVEL_OF', 1;

    SET @v_sql = N'UPDATE [TP_LINK] SET [LEVEL_OF]=@levelof WHERE [CHAIN_ID]=@chain_id AND [ID]=@tplinkid';

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sp_executesql @v_sql,
            N'@levelof VARCHAR(255),@chain_id NUMERIC(18,0),@tplinkid NUMERIC(18,0)',
            @levelof=@p_levelof, @chain_id=@p_chainid, @tplinkid=@p_tplinkid;
        SET @v_rowsproc = @@ROWCOUNT;
        COMMIT TRANSACTION;
        PRINT '[TP_LINK] DBU processed '+CONVERT(VARCHAR(50),@v_rowsproc)+' rows.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW; -- -20525
    END CATCH
END;
GO
