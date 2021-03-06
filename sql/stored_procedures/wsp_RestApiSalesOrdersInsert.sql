SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 29 September 2017
-- Description:	Stored procedure for INSERTing new sales orders into WinMan for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiSalesOrdersInsert'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiSalesOrdersInsert AS PRINT ''wsp_RestApiSalesOrdersInsert''');
	END;
GO

ALTER PROCEDURE dbo.wsp_RestApiSalesOrdersInsert
	@eCommerceWebsiteId nvarchar(100),
	@customerGuid nvarchar(36),
	@customerId nvarchar(10),
	@customerBranch nvarchar(10),
	@dueDate datetime = null,
	@orderDate datetime = null,
	@customerOrderNumber nvarchar(50),
	@customerContact nvarchar(50),
	@delName nvarchar(50),
	@delTitle nvarchar(5) = null,
	@delFirstName nvarchar(25) = null,
	@delLastName nvarchar(25) = null,
	@delAddress nvarchar(200),
	@delCity nvarchar(50) = null,
	@delRegion nvarchar(50) = null,
	@delPostalCode nvarchar(20),
	@delCountryCode nvarchar(3),
	@delPhoneNumber nvarchar(30) = null,
	@delEmailAddress nvarchar(450) = null,
	@currencyCode nvarchar(3),
	@portalUserName nvarchar(50),
	@freightMethodId nvarchar(15) = null,
	@notes nvarchar(max) = null,
	@coupon nvarchar(500) = null,
	@curValuePaid money = 0,
	@scope nvarchar(50),
	@error nvarchar(1000) OUTPUT,
	@salesOrder bigint OUTPUT,
	@salesOrderId nvarchar(15) OUTPUT,
	@guid nvarchar(36) OUTPUT,
	@id nvarchar(10) OUTPUT,
	@branch nvarchar(4) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiSalesOrdersInsert') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiSalesOrdersInsert
				@eCommerceWebsiteId = @eCommerceWebsiteId,
				@customerGuid = @customerGuid,
				@customerId = @customerId,
				@customerBranch = @customerBranch,
				@dueDate = @dueDate,
				@orderDate = @orderDate,
				@customerOrderNumber = @customerOrderNumber,
				@customerContact = @customerContact,
				@delName = @delName,
				@delTitle = @delTitle,
				@delFirstName = @delFirstName,
				@delLastName = @delLastName,
				@delAddress = @delAddress,
				@delCity = @delCity,
				@delRegion = @delRegion,
				@delPostalCode = @delPostalCode,
				@delCountryCode = @delCountryCode,
				@delPhoneNumber = @delPhoneNumber,
				@delEmailAddress = @delEmailAddress,
				@currencyCode = @currencyCode,
				@portalUserName = @portalUserName,
				@freightMethodId = @freightMethodId,
				@notes = @notes,
				@coupon = @coupon,
				@scope = @scope,
				@error = @error OUTPUT,
				@salesOrder = @salesOrder OUTPUT,
				@salesOrderId = @salesOrderId OUTPUT,
				@guid = @guid OUTPUT,
				@id = @id OUTPUT,
				@branch = @branch OUTPUT;
			RETURN;
		END;

	SET NOCOUNT ON;

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
			SELECT 'The relevant REST API scope is not enabled for the specified website.' AS ErrorMessage;
			RETURN;
		END;	

	DECLARE @sql nvarchar(1000);
	DECLARE @where nvarchar(60);

	SET @error = '';

	IF @customerGuid IS NULL OR @customerGuid = ''
		IF (@customerId IS NULL OR @customerId = '') AND (@customerBranch IS NULL OR @customerBranch = '')
			BEGIN
				SET @error = 'A required parameter is missing. If CustomerGuid is not supplied, both CustomerId and CustomerBranch must be supplied.';
				SELECT @error AS ErrorMessage;
				RETURN;
			END;
		ELSE
			SET @where = ' CustomerId=''' + @customerId + ''' AND Branch=''' + @customerBranch + '''';
	ELSE
		SET @where = ' CustomerGUID=''' + @customerGuid + '''';

	DECLARE	@eCommerceWebsite bigint;
	DECLARE @site bigint;
	DECLARE @customer bigint;
	DECLARE @taxCode bigint;
	DECLARE @taxCodeSecondary bigint;
	DECLARE @valuePaid money;
	DECLARE @department bigint;
	DECLARE @industry bigint;
	DECLARE @discount bigint;
	DECLARE @priceList bigint;
	DECLARE @settlementTerms bigint;
	DECLARE @creditTerms bigint;
	DECLARE @delCountry bigint;
	DECLARE @currency bigint;
	DECLARE @crmContact bigint;
	DECLARE @exchangeRate decimal(18,6);
	DECLARE @freightMethod bigint;
	DECLARE @shippingMethod bigint;
	DECLARE @shippingTerm bigint;
	DECLARE @salesOrderPrefix bigint;
	DECLARE @salesOrderNumber int;
	DECLARE @salesOrderSource bigint;
	DECLARE @date datetime;
	DECLARE @user nvarchar(20);

	SET @date = GETDATE();
	SET @user = 'WinMan REST API';
	SET @valuePaid = 0;

	IF @eCommerceWebsiteId IS NULL OR @eCommerceWebsiteId = ''
		BEGIN
			SET @error = 'A required parameter is missing: Website.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;
	ELSE
		BEGIN
			SET @eCommerceWebsite = (SELECT
										EcommerceWebsite
									FROM
										EcommerceWebsites
									WHERE
										EcommerceWebsiteId = @eCommerceWebsiteId);
		END;

	IF @eCommerceWebsite IS NULL
		BEGIN
			SET @error = 'Could not find specified Website. Please check your input data.';
			SELECT @error AS ErrorMessage;
			RETURN;		
		END;

	BEGIN TRY
		SET @sql = 
			'SELECT 
				@customer = Customer,
				@guid = CustomerGUID,
				@id = CustomerId,
				@branch = Branch,
				@taxCode = TaxCode,
				@taxCodeSecondary = TaxCodeSecondary,
				@department = Department,
				@industry = Industry,
				@discount = Discount,
				@priceList = PriceList,
				@settlementTerms = SettlementTerms,
				@creditTerms = CreditTerms,
				@site = [Site]
			FROM 
				Customers
			WHERE' + @where;
		EXECUTE SP_EXECUTESQL @sql, 
			N'@customer bigint OUTPUT, @taxCode bigint OUTPUT, @taxCodeSecondary bigint OUTPUT,
			@creditTerms bigint OUTPUT, @department bigint OUTPUT, @industry bigint OUTPUT,
			@discount bigint OUTPUT, @priceList bigint OUTPUT, @settlementTerms bigint OUTPUT,
			@guid nvarchar(36) OUTPUT, @id nvarchar(10) OUTPUT, @branch nvarchar(4) OUTPUT, @site bigint OUTPUT',
			@customer OUTPUT, @taxCode OUTPUT, @taxCodeSecondary OUTPUT,
			@creditTerms OUTPUT, @department OUTPUT, @industry OUTPUT,
			@discount OUTPUT, @priceList OUTPUT, @settlementTerms OUTPUT,
			@guid OUTPUT, @id OUTPUT, @branch OUTPUT, @site OUTPUT;
	END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE() AS ErrorMessage;
		RETURN;
	END CATCH;

	IF @site IS NULL OR @site = 0
		BEGIN
			SET @site = (SELECT 
							[Site] 
						FROM 
							EcommerceWebsiteSites ews
							INNER JOIN EcommerceWebsites ew ON ews.EcommerceWebsite = ew.EcommerceWebsite
						WHERE 
							ew.EcommerceWebsiteId = @eCommerceWebsiteId
							AND ews.[Default] = 1);
		END;

	IF @site IS NULL OR @site = 0
		BEGIN
			SET @error = 'Could not find the specified or default Site. Please check your input data.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END 	

	IF @customer IS NULL
		BEGIN
			SET @error = 'Could not find the specified Customer. Please check your input data.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;

	IF @orderDate IS NULL OR @orderDate = ''
		BEGIN
			SET @orderDate = @date;
		END;

	IF @dueDate IS NULL OR @dueDate = ''
		BEGIN
			SET @dueDate = @date;
		END;		

	IF @customerOrderNumber IS NULL OR @customerOrderNumber = ''
		BEGIN
			SET @error = 'A required parameter is missing: CustomerOrderNumber.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;

	IF @customerContact IS NULL OR @customerContact = ''
		BEGIN
			SET @error = 'A required parameter is missing: CustomerContact.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;

	IF @delName IS NULL OR @delName = ''
		BEGIN
			SET @error = 'A required parameter is missing: ShippingName.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;

	IF @delTitle IS NULL
		BEGIN
			SET @delTitle = '';
		END;

	IF @delFirstName IS NULL
		BEGIN
			SET @delFirstName = '';
		END;

	IF @delLastName IS NULL
		BEGIN
			SET @delLastName = '';
		END;

	IF @delAddress IS NULL OR @delAddress = ''
		BEGIN
			SET @error = 'A required parameter is missing: ShippingAddress.';
			SELECT @error AS ErrorMessage;
			RETURN;		
		END;

	IF @delCity IS NULL
		BEGIN
			SET @delCity = '';
		END;

	IF @delRegion IS NULL
		BEGIN
			SET @delRegion = '';
		END;

	IF @delPostalCode IS NULL OR @delPostalCode = ''
		BEGIN
			SET @error = 'A required parameter is missing: ShippingPostalCode.';
			SELECT @error AS ErrorMessage;
			RETURN;	
		END;

	IF @delCountryCode IS NULL OR @delCountryCode = ''
		BEGIN
			SET @error = 'A required parameter is missing: ShippingCountryCode.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;
	ELSE
		BEGIN
			SET @delCountry = (SELECT TOP 1 Country FROM Countries WHERE ISO3Chars = @delCountryCode);
		END;

	IF @delCountry IS NULL
		BEGIN
			SET @error = 'Could not find a country with the specified CountryCode. Please check your input data, ensuring you have supplied a valid 3-character code.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;

	IF @delPhoneNumber IS NULL
		BEGIN
			SET @delPhoneNumber = '';
		END;

	IF @delEmailAddress IS NULL
		BEGIN
			SET @delEmailAddress = '';
		END;

	IF @currencyCode IS NULL OR @currencyCode = ''
		BEGIN
			SET @error = 'A required parameter is missing: CurrencyCode.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;
	ELSE
		BEGIN
			SET @currency = (SELECT Currency FROM Currencies WHERE CurrencyId = @currencyCode);
		END;

	IF @currency IS NULL
		BEGIN
			SET @error = 'Could not find a currency with the specified CurrencyCode. Please check your input data.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;

	BEGIN
		SET @exchangeRate = (SELECT StandardRate FROM Currencies WHERE Currency = @currency);
		IF @curValuePaid > 0
			BEGIN
				SET @valuePaid = ROUND(CAST((@curValuePaid / @exchangeRate) AS FLOAT), 2);
			END;
	END;

	IF @portalUserName IS NULL OR @portalUserName = ''
		BEGIN
			SET @error = 'A required parameter is missing: WebsiteUserName.';
			SELECT @error AS ErrorMessage;
			RETURN;			
		END;
	ELSE
		BEGIN
            SELECT TOP 1
                @crmContact = CRMContacts.CRMContact
            FROM 
                CRMContacts
                INNER JOIN CRMCompanies ON CRMContacts.CRMCompany = CRMCompanies.CRMCompany
                INNER JOIN Customers ON Customers.Customer = CRMCompanies.Customer
            WHERE 
                LTRIM(RTRIM(CRMContacts.PortalUserName)) = LTRIM(RTRIM(@portalUserName))
                AND Customers.Customer = @customer
            ORDER BY
                Customers.Customer;
		END;

	IF @crmContact IS NULL
		BEGIN
			SET @error = 'Could not find a CRM Contact with specified WebsiteUserName, or the CRM Contact with the specified WebsiteUserName does not belong to the Customer with the specified CustomerGuid or CustomerId. Please check your input data.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;

	IF @freightMethodId IS NULL OR @freightMethodId = ''
		BEGIN
			SET @freightMethod = (SELECT SalesFreightMethod FROM Sites WHERE [Site] = @site);
		END;
	ELSE
		BEGIN
			SET @freightMethod = (SELECT FreightMethod FROM FreightMethods WHERE FreightMethodId = @freightMethodId);
		END;

	IF @freightMethod IS NULL
		BEGIN
			SET @error = 'Could not find a freight method with the specified FreightMethodId. Please check your input data.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;

	BEGIN
		SET @shippingMethod = (SELECT ShippingMethod FROM FreightMethods WHERE FreightMethod = @freightMethod);
		SET @shippingTerm = (SELECT SalesShippingTerm FROM Sites WHERE [Site] = @site);
	END;

	IF @notes IS NULL
		BEGIN
			SET @notes = '';
		END;

	IF @coupon IS NULL
		BEGIN
			SET @coupon = '';
		END;			

	BEGIN
		SET @salesOrderPrefix = (SELECT SalesOrderPrefix FROM EcommerceWebsites WHERE EcommerceWebsiteId = @eCommerceWebsiteId);
	END;

	BEGIN
		EXEC dbo.wsp_SalesOrderPrefixesIncrement
			@SalesOrderPrefix = @salesOrderPrefix, @NextNumber = @salesOrderNumber OUTPUT;
	END;

	IF NOT EXISTS (SELECT SalesOrderSource FROM SalesOrderSources WHERE SalesOrderSourceId = @user)
		BEGIN
			INSERT INTO SalesOrderSources 
				(SalesOrderSourceId, SalesOrderSourceDescription, CreatedUser, CreatedDate, LastModifiedUser, LastModifiedDate, Comments)
			VALUES(@user, @user, @user, @date, @user, @date, '');

			SET @salesOrderSource = (SELECT SCOPE_IDENTITY());
		END;
	ELSE
		BEGIN
			SET @salesOrderSource = (SELECT SalesOrderSource FROM SalesOrderSources WHERE SalesOrderSourceId = @user);
		END;

	EXEC dbo.wsp_SalesOrdersInsert
		@SalesOrderPrefix = @salesOrderPrefix,
		@SalesOrderNumber = @salesOrderNumber,
		@CustomerOrderNumber = @customerOrderNumber,
		@CustomerContact = @customerContact,
		@DueDate = @dueDate,
		@RequestedDate = @dueDate,
		@Department = @department,
		@Currency = @currency,
		@CreditTerms = @creditTerms,
		@TaxCode = @taxCode,
		@Discount = @discount,
		@Notes = @notes,
		@Customer = @customer,
		@CRMCompany = null,
		@DeliveryAddress = 0,
		@EffectiveDate = @orderDate,
		@ExchangeRate = @exchangeRate,
		@PriceList = @priceList,
		@SystemType = 'F',
		@Messages = '',
		@ModNumber = 0,
		@Industry = @industry,
		@FreightMethod = @freightMethod,
		@Printed = 0,
		@ValuePaid = @valuePaid,
		@CurValuePaid = @curValuePaid,
		@FromLocation = null,
		@PartShip = 0,
		@NotifyFirm = '',
		@NotifyShip = '',
		@CreatedUser = @user,
		@CreatedDate = @date,
		@LastModifiedUser = @user,
		@LastModifiedDate = @date,
		@Comments = '',
		@DC_001_TXT = '',
		@DC_002_TXT = '',
		@DC_003_TXT = '',
		@DC_004_TXT = '',
		@DC_005_INT = '',
		@DC_006_DAT = 0,
		@DelName = @delName,
		@DelTitle = @delTitle,
		@DelLastName = @delLastName,
		@DelFirstName = @delFirstName,
		@DelAddress = @delAddress,
		@DelCity = @delCity,
		@DelRegion = @delRegion,
		@DelPostalCode = @delPostalCode,
		@DelCountry = @delCountry,
		@DelPhoneNumber = @delPhoneNumber,
		@DelEmailAddress = @delEmailAddress,
		@DelNotes = '',
		@ReselectRecord = 0,
		@SalesOrderSource = @salesOrderSource,
		@ConsignmentSale = 0,
		@SalesOrder = @salesOrder OUTPUT,
		@Site = @site,
		@PurchaseOrder = null,
		@TaxCodeSecondary = @taxCodeSecondary,
		@CRMProject = null,
		@CRMContact = @crmContact,
		@SettlementTerms = @settlementTerms,
		@LeaseCompany = null,
		@ShippingMethod = @shippingMethod,
		@ShippingTerm = @shippingTerm,
		@PickingLocation = null,
		@QuotePrinted = null,
		@QuoteExpiry = null,
		@QuoteFollowUp = null,
		@SalesOrderGUID = null,
		@SupportCase = null,
		@SalesOrderId = @salesOrderId OUTPUT,
		@Coupon = @coupon,
		@CustomerAccount = '',
		@CallOffOrder = 0;

	SELECT 
		@salesOrder AS SalesOrder,
		@salesOrderId AS SalesOrderId,
		@error AS ErrorMessage,
		@guid AS CustomerGUID,
		@id AS CustomerId,
		@branch AS CustomerBranch;

END;
GO

COMMIT TRANSACTION AlterProcedure;
