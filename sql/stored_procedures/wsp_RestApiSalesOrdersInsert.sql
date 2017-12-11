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
	@customerGuid nvarchar(36) = null,
	@customerId nvarchar(10) = null,
	@customerBranch nvarchar(10) = null,
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
	@scope nvarchar(50)
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
				@scope = @scope;
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
			SELECT 'ERROR: Scope not enabled for specified website.' AS ErrorMessage;
			RETURN;
		END;	

	DECLARE	@error nvarchar(100);
	DECLARE @sql nvarchar(1000);
	DECLARE @where nvarchar(60);

	SET @error = '';

	IF @customerGuid IS NULL OR @customerGuid = ''
		IF (@customerId IS NULL OR @customerId = '') AND (@customerBranch IS NULL OR @customerBranch = '')
			BEGIN
				SET @error = 'ERROR: Required parameter missing. If Customer GUID is not supplied, both Customer ID and Customer Branch must be supplied.';
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
	DECLARE @salesOrder bigint;
	DECLARE @salesOrderId nvarchar(15);
	DECLARE @date datetime;
	DECLARE @user nvarchar(20);

	SET @date = GETDATE();
	SET @user = 'WinMan REST API';
	SET @valuePaid = 0;

	IF @eCommerceWebsiteId IS NULL OR @eCommerceWebsiteId = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Website.';
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
			SET @error = 'ERROR: Could not find specified website. Please check your input data.';
			SELECT @error AS ErrorMessage;
			RETURN;		
		END;

	BEGIN TRY
		SET @sql = 
			'SELECT 
				@customer = Customer,
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
			@discount bigint OUTPUT, @priceList bigint OUTPUT, @settlementTerms bigint OUTPUT, @site bigint OUTPUT',
			@customer OUTPUT, @taxCode OUTPUT, @taxCodeSecondary OUTPUT,
			@creditTerms OUTPUT, @department OUTPUT, @industry OUTPUT,
			@discount OUTPUT, @priceList OUTPUT, @settlementTerms OUTPUT, @site OUTPUT;
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
			SET @error = 'ERROR: Could not find specified or default site. Please check your input data.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END 	

	IF @customer IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find specified customer. Please check your input data.';
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
			SET @error = 'ERROR: Required parameter missing: Customer Order Number.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;

	IF @customerContact IS NULL OR @customerContact = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Customer Contact Name.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;

	IF @delName IS NULL OR @delName = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Delivery Name.';
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
			SET @error = 'ERROR: Required parameter missing: Delivery Address.';
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
			SET @error = 'ERROR: Required parameter missing: Delivery Postal Code.';
			SELECT @error AS ErrorMessage;
			RETURN;	
		END;

	IF @delCountryCode IS NULL OR @delCountryCode = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Delivery Country Code.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;
	ELSE
		BEGIN
			SET @delCountry = (SELECT TOP 1 Country FROM Countries WHERE ISO3Chars = @delCountryCode);
		END;

	IF @delCountry IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find country with specified county code. Please check your input data.';
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
			SET @error = 'ERROR: Required parameter missing: Currency Code.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;
	ELSE
		BEGIN
			SET @currency = (SELECT Currency FROM Currencies WHERE CurrencyId = @currencyCode);
		END;

	IF @currency IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find currency with specified currency code. Please check your input data.';
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
			SET @error = 'ERROR: Required parameter missing: Contact Username.';
			SELECT @error AS ErrorMessage;
			RETURN;			
		END;
	ELSE
		BEGIN
			SET @crmContact = (SELECT CRMContact FROM CRMContacts WHERE PortalUserName = @portalUserName);
		END;

	IF @crmContact IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find CRM contact with specified username. Please check your input data.';
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
			SET @error = 'ERROR: Could not find freight method with the specified freight method name. Please check your input data.';
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
		@RequestedDate = @orderDate,
		@Department = @department,
		@Currency = @currency,
		@CreditTerms = @creditTerms,
		@TaxCode = @taxCode,
		@Discount = @discount,
		@Notes = @notes,
		@Customer = @customer,
		@CRMCompany = null,
		@DeliveryAddress = 0,
		@EffectiveDate = @date,
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

	SELECT @salesOrder AS SalesOrder, @salesOrderId AS SalesOrderId, @error AS ErrorMessage;

END;
GO

COMMIT TRANSACTION AlterProcedure;
