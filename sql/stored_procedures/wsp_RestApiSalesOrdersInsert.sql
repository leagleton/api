SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 29 September 2017
-- Description:	Stored procedure for INSERTing new sales orders into WinMan for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiSalesOrdersInsert]
	@eCommerceWebsiteId NVARCHAR(100) = NULL,
	@siteName NVARCHAR(20) = NULL,
	@customerGuid NVARCHAR(36) = NULL,
	@customerId NVARCHAR(10) = NULL,
	@customerBranch NVARCHAR(10) = NULL,
	@creditTermsId NVARCHAR(15) = NULL,
	@effectiveDate DATETIME = NULL,
	@customerOrderNumber NVARCHAR(50) = NULL,
	@customerContact NVARCHAR(50) = NULL,
	@delName NVARCHAR(50) = NULL,
	@delTitle NVARCHAR(5) = NULL,
	@delFirstName NVARCHAR(25) = NULL,
	@delLastName NVARCHAR(25) = NULL,
	@delAddress NVARCHAR(200) = NULL,
	@delCity NVARCHAR(50) = NULL,
	@delRegion NVARCHAR(50) = NULL,
	@delPostalCode NVARCHAR(20) = NULL,
	@delCountryCode NVARCHAR(3) = NULL,
	@delPhoneNumber NVARCHAR(30) = NULL,
	@delEmailAddress NVARCHAR(450) = NULL,
	@currencyCode NVARCHAR(3) = NULL,
	@portalUserName NVARCHAR(50) = NULL,
	@freightMethodId NVARCHAR(15) = NULL,
	@salesOrderPrefixId NVARCHAR(15) = NULL
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiSalesOrdersInsert') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiSalesOrdersInsert
				@eCommerceWebsiteId = @eCommerceWebsiteId,
				@siteName = @siteName,
				@customerGuid = @customerGuid,
				@customerId = @customerId,
				@customerBranch = @customerBranch,
				@creditTermsId = @creditTermsId,
				@effectiveDate = @effectiveDate,
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
				@salesOrderPrefixId = @salesOrderPrefixId
			RETURN	
		END

	SET NOCOUNT ON;

	DECLARE
		@error NVARCHAR(100) = '',
		@sql NVARCHAR(1000),
		@where NVARCHAR(60)

	IF @customerGuid IS NULL OR @customerGuid = ''
		IF (@customerId IS NULL OR @customerId = '') AND (@customerBranch IS NULL OR @customerBranch = '')
			BEGIN
				SET @error = 'ERROR: Required parameter missing. If Customer GUID is not supplied, both Customer ID and Customer Branch must be supplied.'
				SELECT @error AS ErrorMessage
				RETURN
			END
		ELSE
			SET @where = ' CustomerId ''' + @customerId + ''' AND Branch=''' + @customerBranch + ''''
	ELSE
		SET @where = ' CustomerGUID=''' + @customerGuid + ''''

	DECLARE
		@eCommerceWebsite BIGINT,
		@site BIGINT,
		@customer BIGINT,
		@taxCode BIGINT,
		@taxCodeSecondary BIGINT,
		@crmCompany BIGINT,
		@department BIGINT,
		@industry BIGINT,
		@discount BIGINT,
		@priceList BIGINT,
		@settlementTerms BIGINT,
		@creditTerms BIGINT,
		@delCountry BIGINT,
		@currency BIGINT,
		@crmContact BIGINT,
		@exchangeRate DECIMAL(18,6),
		@freightMethod BIGINT,
		@shippingMethod BIGINT,
		@shippingTerm BIGINT,
		@salesOrderPrefix BIGINT,
		@salesOrderNumber INT,
		@salesOrderSource BIGINT,
		@salesOrder BIGINT,
		@salesOrderId NVARCHAR(15),
		@date DATETIME = GETDATE(),
		@user NVARCHAR(20) = 'WinMan REST API'

	IF @eCommerceWebsiteId IS NULL OR @eCommerceWebsiteId = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Website.'
			SELECT @error AS ErrorMessage
			RETURN
		END 
	ELSE
		BEGIN
			SET @eCommerceWebsite = (SELECT
										EcommerceWebsite
									FROM
										EcommerceWebsites
									WHERE
										EcommerceWebsiteId = @eCommerceWebsiteId)
		END

	IF @eCommerceWebsite IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find specified website. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN			
		END

	IF @siteName IS NULL OR @siteName = ''
		BEGIN 
			SET @site = (SELECT 
							[Site] 
						FROM 
							EcommerceWebsiteSites ews
							INNER JOIN EcommerceWebsites ew ON ews.EcommerceWebsite = ew.EcommerceWebsite
						WHERE 
							ew.EcommerceWebsiteId = @eCommerceWebsiteId
							AND ews.[Default] = 1)
		END
	ELSE
		BEGIN
			SET @site = (SELECT [Site] FROM Sites WHERE SiteName = @siteName)
		END

	IF @site IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find specified or default site. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN
		END 

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
				@creditTerms = CASE WHEN @creditTermsId IS NULL OR @creditTermsId = '''' THEN CreditTerms ELSE 0 END
			FROM 
				Customers
			WHERE' + @where
		EXECUTE SP_EXECUTESQL @sql, 
			N'@customer BIGINT OUTPUT, @taxCode BIGINT OUTPUT, @taxCodeSecondary BIGINT OUTPUT,
			@creditTerms BIGINT OUTPUT, @department BIGINT OUTPUT, @industry BIGINT OUTPUT,
			@discount BIGINT OUTPUT, @priceList BIGINT OUTPUT, @settlementTerms BIGINT OUTPUT,
			@creditTermsId NVARCHAR(15)',
			@customer OUTPUT, @taxCode OUTPUT, @taxCodeSecondary OUTPUT,
			@creditTerms OUTPUT, @department OUTPUT, @industry OUTPUT,
			@discount OUTPUT, @priceList OUTPUT, @settlementTerms OUTPUT,
			@creditTermsId = @creditTermsId;
	END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE()
		RETURN
	END CATCH

	IF @customer IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find specified customer. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF EXISTS (SELECT CustomerOrderNumber FROM SalesOrders WHERE Customer = @customer AND CustomerOrderNumber = @customerOrderNumber)
		BEGIN
			SET @error = 'ERROR: Customer Order Number already exists. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN				
		END

	BEGIN
		SELECT
			@crmCompany = CRMCompany
		FROM
			CRMCompanies
		WHERE
			Customer = @customer
	END

	IF @creditTerms = 0
		BEGIN
			SET @creditTerms = (SELECT CreditTerms FROM CreditTerms WHERE CreditTermsId = @creditTermsId)
		END

	IF @creditTerms IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find credit terms with specified ID. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @effectiveDate IS NULL OR @effectiveDate = ''
		BEGIN
			SET @effectiveDate = @date
		END

	IF @customerOrderNumber IS NULL OR @customerOrderNumber = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Customer Order Number.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @customerContact IS NULL OR @customerContact = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Customer Contact Name.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @delName IS NULL OR @delName = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Delivery Name.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @delTitle IS NULL
		BEGIN
			SET @delTitle = ''
		END

	IF @delFirstName IS NULL
		BEGIN
			SET @delFirstName = ''
		END

	IF @delLastName IS NULL
		BEGIN
			SET @delLastName = ''
		END

	IF @delAddress IS NULL OR @delAddress = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Delivery Address.'
			SELECT @error AS ErrorMessage
			RETURN			
		END

	IF @delCity IS NULL
		BEGIN
			SET @delCity = ''
		END

	IF @delRegion IS NULL
		BEGIN
			SET @delRegion = ''
		END

	IF @delPostalCode IS NULL OR @delPostalCode = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Delivery Postal Code.'
			SELECT @error AS ErrorMessage
			RETURN			
		END

	IF @delCountryCode IS NULL OR @delCountryCode = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Delivery Country Code.'
			SELECT @error AS ErrorMessage
			RETURN
		END
	ELSE
		BEGIN
			SET @delCountry = (SELECT TOP 1 Country FROM Countries WHERE ISO3Chars = @delCountryCode)
		END

	IF @delCountry IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find country with specified county code. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @delPhoneNumber IS NULL
		BEGIN
			SET @delPhoneNumber = ''
		END

	IF @delEmailAddress IS NULL
		BEGIN
			SET @delEmailAddress = ''
		END

	IF @currencyCode IS NULL OR @currencyCode = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Currency Code.'
			SELECT @error AS ErrorMessage
			RETURN
		END
	ELSE
		BEGIN
			SET @currency = (SELECT Currency FROM Currencies WHERE CurrencyId = @currencyCode)
		END

	IF @currency IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find currency with specified currency code. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	BEGIN
		SET @exchangeRate = (SELECT StandardRate FROM Currencies WHERE Currency = @currency)
	END

	IF @portalUserName IS NULL OR @portalUserName = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Contact Username.'
			SELECT @error AS ErrorMessage
			RETURN			
		END
	ELSE
		BEGIN
			SET @crmContact = (SELECT CRMContact FROM CRMContacts WHERE PortalUserName = @portalUserName)
		END

	IF @crmContact IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find CRM contact with specified username. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @freightMethodId IS NULL OR @freightMethodId = ''
		BEGIN
			SET @freightMethod = (SELECT SalesFreightMethod FROM Sites WHERE [Site] = @site)
		END
	ELSE
		BEGIN
			SET @freightMethod = (SELECT FreightMethod FROM FreightMethods WHERE FreightMethodId = @freightMethodId)
		END

	IF @freightMethod IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find freight method with the specified freight method name. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	BEGIN
		SET @shippingMethod = (SELECT ShippingMethod FROM FreightMethods WHERE FreightMethod = @freightMethod)
		SET @shippingTerm = (SELECT SalesShippingTerm FROM Sites WHERE [Site] = @site)
	END

	IF @salesOrderPrefixId IS NULL OR @salesOrderPrefixId = ''
		BEGIN
			SET @salesOrderPrefix = (SELECT SalesOrderPrefix FROM EcommerceWebsites WHERE EcommerceWebsiteId = @eCommerceWebsiteId)
		END
	ELSE
		BEGIN
			SET @salesOrderPrefix = (SELECT SalesOrderPrefix FROM SalesOrderPrefixes WHERE SalesOrderPrefixId = @salesOrderPrefixId)
		END

	IF @salesOrderPrefix IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find sales order prefix with the specified sales order prefix ID. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	BEGIN
		EXEC dbo.wsp_SalesOrderPrefixesIncrement
			@SalesOrderPrefix = @salesOrderPrefix, @NextNumber = @salesOrderNumber OUTPUT
	END

	IF NOT EXISTS (SELECT SalesOrderSource FROM SalesOrderSources WHERE SalesOrderSourceId = @user)
		BEGIN
			INSERT INTO SalesOrderSources 
				(SalesOrderSourceId, SalesOrderSourceDescription, CreatedUser, CreatedDate, LastModifiedUser, LastModifiedDate, Comments)
			VALUES(@user, @user, @user, @date, @user, @date, '')

			SET @salesOrderSource = (SELECT SCOPE_IDENTITY())
		END
	ELSE
		BEGIN
			SET @salesOrderSource = (SELECT SalesOrderSource FROM SalesOrderSources WHERE SalesOrderSourceId = @user)
		END

	EXEC dbo.wsp_SalesOrdersInsert
		@SalesOrderPrefix = @salesOrderPrefix,
		@SalesOrderNumber = @salesOrderNumber,
		@CustomerOrderNumber = @customerOrderNumber,
		@CustomerContact = @customerContact,
		@DueDate = @date,
		@RequestedDate = @date,
		@Department = @department,
		@Currency = @currency,
		@CreditTerms = @creditTerms,
		@TaxCode = @taxCode,
		@Discount = @discount,
		@Notes = '',
		@Customer = @customer,
		@CRMCompany = @crmCompany,
		@DeliveryAddress = 0,
		@EffectiveDate = @effectiveDate,
		@ExchangeRate = @exchangeRate,
		@PriceList = @priceList,
		@SystemType = 'F',
		@Messages = '',
		@ModNumber = 0,
		@Industry = @industry,
		@FreightMethod = @freightMethod,
		@Printed = 0,
		@ValuePaid = 0,
		@CurValuePaid = 0,
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
		@Coupon = '',
		@CustomerAccount = '',
		@CallOffOrder = 0

	SELECT @salesOrder AS SalesOrder, @salesOrderId AS SalesOrderId, @error AS ErrorMessage

END
GO
