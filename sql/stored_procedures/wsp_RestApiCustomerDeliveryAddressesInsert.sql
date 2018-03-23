SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 10 January 2018
-- Description:	Stored procedure for INSERTing new customer delivery addresses into WinMan for the WinMan REST API.
-- =============================================

IF NOT EXISTS
(
    SELECT 
		p.[name] 
	FROM 
		sys.procedures p
		INNER JOIN sys.schemas s ON p.[schema_id] = s.[schema_id]
    WHERE
        p.[type] = 'P'
		AND p.[name] = 'wsp_RestApiCustomerDeliveryAddressesInsert'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiCustomerDeliveryAddressesInsert AS PRINT ''dbo.wsp_RestApiCustomerDeliveryAddressesInsert''');
	END;
GO

-- 23Mar18 LAE Remove the check against CRM Company Name #0000140113

ALTER PROCEDURE [dbo].[wsp_RestApiCustomerDeliveryAddressesInsert]
	@eCommerceWebsiteId nvarchar(100) = null,
    @customerGuid nvarchar(36) = null,
	@title nvarchar(5) = null,
	@firstName nvarchar(25) = null,
	@lastName nvarchar(25) = null,
	@deliveryName nvarchar(50) = null,
	-- 23Mar18 LAE
    --@companyName nvarchar(50) = null,
	@address nvarchar(200) = null,
	@city nvarchar(50) = null,
	@region nvarchar(50) = null,
	@postalCode nvarchar(20) = null,
	@countryCode nvarchar(3) = null,
    @phoneNumber nvarchar(30) = null,
	@emailAddress nvarchar(50) = null,
    @isDefault bit = 0,  
	@scope nvarchar(50),
	@error nvarchar(1000) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCustomerDeliveryAddressesInsert') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiCustomerDeliveryAddressesInsert
                @eCommerceWebsiteId = @eCommerceWebsiteId,
                @customerGuid = @customerGuid,
                @title = @title,
                @firstName = @firstName,
                @lastName = @lastName,
                @deliveryName = @deliveryName,
				-- 23Mar18 LAE
                --@companyName = @companyName,
                @address = @address,
                @city = @city,
                @region = @region,
                @postalCode = @postalCode,
                @countryCode = @countryCode,
                @phoneNumber = @phoneNumber,
                @emailAddress = @emailAddress,
                @isDefault = @isDefault,  
                @scope = @scope,
                @error = @error OUTPUT;
			RETURN;	
		END;

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	IF NOT EXISTS (
		SELECT 
			s.RestApiScope 
		FROM 
			RestApiScopeEcommerceWebsites sw
			INNER JOIN RestApiScopes s ON sw.RestApiScope = s.RestApiScope
			INNER JOIN EcommerceWebsites w ON sw.EcommerceWebsite = w.EcommerceWebsite
		WHERE
			s.RestApiScopeId = @scope
			AND w.EcommerceWebsiteId = @eCommerceWebsiteId
	)
		BEGIN
			SET @error = 'The relevant REST API scope is not enabled for the specified website.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;	

	IF @eCommerceWebsiteId IS NULL OR @eCommerceWebsiteId = ''
		BEGIN
			SET @error = 'A required parameter is missing: Website.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

    DECLARE @customer bigint;        

	IF @customerGuid IS NULL OR @customerGuid = ''
		BEGIN
			SET @error = 'A required parameter is missing: CustomerGuid.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;
    ELSE
        BEGIN
            SET @customer = (SELECT Customer FROM Customers WHERE CustomerGUID = @customerGuid);
        END;

	IF @customer IS NULL
		BEGIN
			SET @error = 'Could not find a customer with the specified CustomerGuid. Please check your input data.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

    DECLARE @crmCompany bigint;

    --IF @companyName IS NULL OR @companyName = ''
    --    BEGIN
    --        SET @error = 'A required parameter is missing: BillingName.';
    --        SELECT @error AS ErrorMessage;
    --        ROLLBACK TRANSACTION;
    --        RETURN;
    --    END;
    --ELSE
    --    BEGIN
    --        SET @crmCompany = (SELECT CRMCompany FROM CRMCompanies WHERE Customer = @customer AND CompanyName = @companyName);
    --    END;
	SET @crmCompany = (SELECT TOP 1 CRMCompany FROM CRMCompanies WHERE Customer = @customer);

	IF @crmCompany IS NULL
		BEGIN
			-- 23Mar18 LAE
			--SET @error = 'Could not find a CRM Company with the specified company name (BillingName) belonging to the specified customer. Please check your input data.';
			SET @error = 'Could not find a CRM Company belonging to the specified customer. Please check your input data.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;         

	IF @title IS NULL
		BEGIN
			SET @title = '';
		END;

	IF @firstName IS NULL
		BEGIN
			SET @firstName = '';
		END;

	IF @lastName IS NULL
		BEGIN
			SET @lastName = '';
		END;                        

	IF @deliveryName IS NULL OR @deliveryName = ''
		BEGIN
			SET @error = 'A required parameter is missing: ShippingName.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	IF @address IS NULL OR @address = ''
		BEGIN
			SET @error = 'A required parameter is missing: ShippingAddress.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	IF @city IS NULL
		BEGIN
			SET @city = '';
		END;

	IF @region IS NULL
		BEGIN
			SET @region = '';
		END;                  

	IF @postalCode IS NULL OR @postalCode = ''
		BEGIN
			SET @error = 'A required parameter is missing: ShippingPostalCode.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

    DECLARE @country bigint;      

	IF @countryCode IS NULL OR @countryCode = ''
		BEGIN
			SET @error = 'A required parameter is missing: ShippingCountryCode.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;
	ELSE
		BEGIN
			SET @country = (SELECT TOP 1 Country FROM Countries WHERE ISO3Chars = @countryCode);
		END;

	IF @country IS NULL
		BEGIN
			SET @error = 'Could not find a country with the specified ShippingCountryCode. Please check your input data, ensuring you have supplied a valid 3-character code.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	IF @phoneNumber IS NULL
		BEGIN
			SET @phoneNumber = '';
		END;

    DECLARE @date datetime;
    DECLARE @user nvarchar(20);
    DECLARE @deliveryAddress bigint;

	SET @date = GETDATE();
	SET @user = 'WinMan REST API'; 
    SET @error = '';   

	EXEC wsp_DeliveryAddressesCheck
        @DeliveryAddress = @deliveryAddress OUTPUT,
		@DelName = @deliveryName,
        @DelTitle = @title,
        @DelFirstName = @firstName,
        @DelLastName = @lastName,
        @DelAddress = @address,
        @DelCity = @city,
        @DelRegion = @region,
        @DelPostalCode = @postalCode,
        @DelCountry = @country,
        @DelPhoneNumber = @phoneNumber,
        @DelEmailAddress = @emailAddress,
        @DelNotes = '',
        @Customer = @customer,
        @Supplier = null,
        @CRMCompany = @crmCompany,
        @LastModifiedUser = @user;

    IF @isDefault = 1
        BEGIN
            UPDATE 
                Customers 
            SET 
                DeliveryAddress = @deliveryAddress, 
                LastModifiedDate = @date, 
                LastModifiedUser = @user 
            WHERE 
                Customer = @customer;
        END;

	SELECT @error AS ErrorMessage;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
