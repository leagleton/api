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
-- Description:	Stored procedure for INSERTing new sales order items into WinMan for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiSalesOrderItemsInsert'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiSalesOrderItemsInsert AS PRINT ''wsp_RestApiSalesOrderItemsInsert''');
	END;
GO

ALTER PROCEDURE dbo.wsp_RestApiSalesOrderItemsInsert
	@salesOrder bigint,
	@itemType CHAR(1),
	@sku nvarchar(100) = null,
	@quantity decimal(17,5),
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
	@freightMethodId nvarchar(15) = null,
	@curValue money,
	@curTaxValue money
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiSalesOrderItemsInsert') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiSalesOrderItemsInsert
				@salesOrder = @salesOrder,
				@itemType = @itemType,
				@sku = @sku,
				@quantity = @quantity,
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
				@freightMethodId = @freightMethodId,
				@curValue = @curValue,
				@curTaxValue = @curTaxValue;
			RETURN;
		END;

	SET NOCOUNT ON;

	DECLARE @curItemValue money = 0;
	DECLARE @curExtendedPrice money = 0;
	DECLARE @curPrice money = 0;	
	DECLARE @error nvarchar(100);

	SET @error = '';

	IF @salesOrder IS NULL OR @salesOrder = 0
		BEGIN
			SET @error = 'A required parameter is missing: SalesOrder.';
			SELECT @error AS ErrorMessage;
			RETURN;		
		END;

	IF @itemType IS NULL OR @itemType = ''
		BEGIN
			SET @error = 'A required parameter is missing: ItemType.';
			SELECT @error AS ErrorMessage;	
			RETURN;		
		END;

	IF @curValue IS NULL
		BEGIN
			SET @error = 'A required parameter is missing: OrderLineValue.';
			SELECT @error AS ErrorMessage;	
			RETURN;		
		END;

	IF @curTaxValue IS NULL
		BEGIN
			SET @error = 'A required parameter is missing: OrderLineTaxValue.';
			SELECT @error AS ErrorMessage;	
			RETURN;		
		END;

	IF @curValue > 0
		BEGIN
			SET @curItemValue = @curValue - @curTaxValue;
			SET @curExtendedPrice = @curItemValue;
			SET @curPrice = CASE WHEN @curExtendedPrice > 0 THEN ROUND(CAST(@curExtendedPrice AS float) / @quantity, 2) ELSE 0 END;
		END;

	IF @quantity IS NULL OR @quantity = 0
		BEGIN
			SET @error = 'A required parameter is missing: Quantity.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;

	IF @delName IS NULL OR @delName = ''
		BEGIN
			SET @error = 'A required parameter is missing: ShippingName.';			
			SELECT @error AS ErrorMessage;	
			RETURN;
		END;

	IF @delAddress IS NULL OR @delAddress = ''
		BEGIN
			SET @error = 'A required parameter is missing: ShippingAddress.';
			SELECT @error AS ErrorMessage;	
			RETURN;		
		END;

	DECLARE	@site bigint;
	DECLARE	@product bigint;
	DECLARE @taxable bit;
	DECLARE @exchangeRate decimal(18,6);
	DECLARE	@delCountry bigint;
	DECLARE @headerLastModifiedDate datetime;
	DECLARE @itemDescription nvarchar(300);
	DECLARE	@dueDate datetime;
	DECLARE @requestedDate datetime;
	DECLARE @printSequence int;
	DECLARE @itemNumber int;
	DECLARE @salesOrderItem bigint;
	DECLARE @glChartOfAccount bigint;
	DECLARE @glAccountDivision bigint;
	DECLARE @glAccountType bigint;
	DECLARE @priceList bigint;
	DECLARE @freightMethod bigint;
	DECLARE @discount bigint;
	DECLARE @discountValue money;
	DECLARE @taxCode bigint;
	DECLARE @taxRate decimal(17,5);
	DECLARE @taxValue money;
	DECLARE @taxCodeSecondary bigint;
	DECLARE @taxRateSecondary decimal(17,5);
	DECLARE @curTaxValueSecondary money;
	DECLARE @taxValueSecondary money;
	DECLARE @price money;
	DECLARE @extendedPrice money;
	DECLARE @curDiscountValue money;
	DECLARE @itemValue money;
	DECLARE @unitOfMeasure bigint;
	DECLARE @unitOfMeasureFactor bigint;
	DECLARE @date datetime;
	DECLARE @user nvarchar(20);

	SET @product = null;
	SET @freightMethod = null;
	SET @discountValue = 0;
	SET @taxValue = 0;
	SET @taxRateSecondary = 0;
	SET @curTaxValueSecondary = 0;
	SET @taxValueSecondary = 0;
	SET @curExtendedPrice = 0;
	SET @price = 0;
	SET @extendedPrice = 0;
	SET @curDiscountValue = 0;
	SET @itemValue = 0;
	SET @date = GETDATE();
	SET @user = 'WinMan REST API';

	BEGIN 
		SELECT
			@site = SalesOrders.[Site],
			@headerLastModifiedDate = SalesOrders.LastModifiedDate,
			@dueDate = DueDate,
			@requestedDate = RequestedDate,			
			@glAccountDivision = ISNULL(Customers.GLAccountDivision, dbo.wfn_GetDefault('SalesGLDivision', SalesOrders.[Site])),
			@glAccountType = ISNULL(Customers.GLAccountType, dbo.wfn_GetDefault('SalesFreeTextGLType', SalesOrders.[Site])),
			@exchangeRate = SalesOrders.ExchangeRate,
			@priceList = SalesOrders.PriceList,
			@discount = SalesOrders.Discount,
			@taxCode = SalesOrders.TaxCode,
			@taxCodeSecondary = SalesOrders.TaxCodeSecondary
		FROM
			SalesOrders
			INNER JOIN Customers ON Customers.Customer = SalesOrders.Customer
		WHERE
			SalesOrder = @salesOrder;
	END;

	BEGIN
		SET @taxRate = (SELECT TaxRate FROM TaxCodes WHERE TaxCode = @taxCode);
	END;

	IF @itemType = 'P' AND (@sku IS NULL OR @sku = '')
		BEGIN
			SET @error = 'A required parameter is missing: Sku.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;
	ELSE IF @itemType = 'P' AND @sku IS NOT NULL AND @sku <> ''
		BEGIN
			SELECT
				@product = Product,
				@unitOfMeasure = UnitOfMeasure,
				@taxable = Taxable,
				@glAccountDivision = SalesGLDivision,
				@glAccountType = SalesGLAccount
			FROM
				Products
			WHERE
				ProductId = @sku;

			IF @product IS NULL
				BEGIN
					SET @error = 'Could not find product with the specified Sku. Please check your input data.';
					SELECT @error AS ErrorMessage;
					RETURN;
				END;
			ELSE
				BEGIN
					SET @itemDescription = (SELECT ProductDescription FROM Products WHERE Product = @product);
				END;

			IF dbo.wfn_GetProgramProfile('SalesOrders_UseSiteDivision', 'N') = 'Y'
				BEGIN
					SELECT @glAccountDivision = SalesGLDivision FROM Sites WHERE [Site] = @site;
				END;
			ELSE
				BEGIN		
					IF @glAccountDivision IS NULL
						BEGIN
							IF dbo.wfn_GetProgramProfile('SalesOrders_UsePrefixDivision','N') = 'Y'
								BEGIN
									SELECT 
										@glAccountDivision = GLAccountDivision 
									FROM
										SalesOrderPrefixes 
									WHERE
										SalesOrderPrefix = (SELECT SalesOrderPrefix FROM SalesOrders WHERE SalesOrder = @salesOrder);
								END;
							ELSE
								BEGIN
									SELECT		
										@glAccountDivision = ISNULL(Customers.GLAccountDivision, dbo.wfn_GetDefault('SalesGLDivision', SalesOrders.[Site]))
									FROM
										SalesOrders
										INNER JOIN Customers ON Customers.Customer = SalesOrders.Customer
									WHERE
										SalesOrder = @salesOrder;
								END;
						END;
				END;				

			DECLARE @percent decimal(17,5);
			DECLARE	@value decimal(17,5);

			EXEC dbo.wsp_DiscountsGetValues
				@Discount = @discount, @Quantity = 1, @Price = @curPrice,
				@DiscountPercent = @percent OUTPUT, @DiscountValue = @value OUTPUT;

			IF @value > 0 AND @percent = 0
				BEGIN
					SET @curDiscountValue = @value;
				END;

			IF @percent > 0 AND @value = 0
				BEGIN
					SET @curDiscountValue = ROUND(CAST((@curPrice * (@percent / 100) * @quantity) AS FLOAT), 2);
				END;

			SET @unitOfMeasureFactor = (SELECT UnitOfMeasurefactor FROM UnitsOfMeasureFactors WHERE UnitOfMeasure = @unitOfMeasure AND ConversionFactor = 1);
		END;

	IF @itemType = 'F' AND (@freightMethodId IS NULL OR @freightMethodId = '')
		BEGIN
			SET @error = 'A required parameter is missing: FreightMethodId.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;
	ELSE IF @itemType = 'F' AND @freightMethodId IS NOT NULL AND @freightMethodId <> ''
		BEGIN
			SELECT
				@freightMethod = FreightMethod,
				@glAccountType = GLTypeRevenue
			FROM
				FreightMethods
			WHERE
				FreightMethodId = @freightMethodId;

			IF @freightMethod IS NULL
				BEGIN
					SET @error = 'Could not find the freight method with the specified FreightMethodId. Please check your input data.';
					SELECT @error AS ErrorMessage;
					RETURN;
				END;
			ELSE
				BEGIN
					SELECT
						@itemDescription = FreightMethodDescription,
						@taxable = Taxable
					FROM
						FreightMethods
					WHERE
						FreightMethod = @freightMethod;
				END;

			SET @unitOfMeasure = (SELECT UnitOfMeasure FROM Sites WHERE [Site] = @site);
			SET @unitOfMeasureFactor = (SELECT UnitOfMeasurefactor FROM UnitsOfMeasureFactors WHERE UnitOfMeasure = @unitOfMeasure AND ConversionFactor = 1);
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
		END

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
		END

	IF @delPhoneNumber IS NULL
		BEGIN
			SET @delPhoneNumber = '';
		END;

	IF @delEmailAddress IS NULL
		BEGIN
			SET @delEmailAddress = '';
		END;

	BEGIN
		SET @printSequence = 10;
		SET @itemNumber = 1;
		IF EXISTS (SELECT SalesOrderItem FROM SalesOrderItems WHERE SalesOrder = @salesOrder)
			BEGIN
				SET @printSequence = (SELECT TOP 1 PrintSequence + 10 FROM SalesOrderItems WHERE SalesOrder = @salesOrder ORDER BY PrintSequence DESC);
				SET @itemNumber = (SELECT TOP 1 ItemNumber + 1 FROM SalesOrderItems WHERE SalesOrder = @salesOrder ORDER BY ItemNumber DESC);
			END;
	END;

	BEGIN		
		SET @glChartOfAccount = dbo.wfn_GetValidGLAccount(@glAccountDivision, @glAccountType, NULL, 0, @site);
	END;

	IF @curPrice > 0
		BEGIN
			SET @price = ROUND(CAST((@curPrice / @exchangeRate) AS FLOAT), 2);
			SET @extendedPrice = ROUND(CAST((@curExtendedPrice / @exchangeRate) AS FLOAT), 2);
			SET @taxValue = CASE WHEN @curTaxValue > 0 THEN ROUND(CAST((@curTaxValue / @exchangeRate) AS FLOAT), 2) ELSE 0 END;
		END

	IF @taxRateSecondary > 0
		BEGIN
			SET @curTaxValueSecondary = CASE WHEN @taxable = 1 THEN  ROUND(CAST((((@curExtendedPrice - @curDiscountValue)) * (@taxRateSecondary / 100)) AS FLOAT), 2) ELSE 0 END;
			SET @taxValueSecondary = CASE WHEN @taxable = 1 THEN ROUND(CAST((@curTaxValueSecondary / @exchangeRate) AS FLOAT), 2) ELSE 0 END;
		END;

	IF @curDiscountValue > 0
		BEGIN
			SET @discountValue = ROUND(CAST((@curDiscountValue / @exchangeRate) AS FLOAT), 2);
		END;

	IF @curItemValue > 0
		BEGIN
			SET @itemValue = ROUND(CAST((@curItemValue / @exchangeRate) AS FLOAT), 2);
		END;

	EXEC dbo.wsp_SalesOrderItemsInsert
		@SalesOrder = @salesOrder,
		@ItemType = @itemType, 
		@Product = @product,
		@Sundry = null,
		@FreeTextItem = null,
		@ItemDescription = @itemDescription,
		@Quantity = @quantity,
		@Price = @price,
		@ItemValue = @itemValue,
		@ItemNumber = @itemNumber,
		@Discount = @discount,
		@DiscountValue = @discountValue,
		@TaxCode = @taxCode,
		@TaxRate = @taxRate,
		@DueDate = @dueDate,
		@RequestedDate = @requestedDate,
		@SalesOrderItem = @salesOrderItem OUTPUT,
		@DeliveryAddress = 0,
		@QuantityShipped = 0,
		@GLChartOfAccount = @glChartOfAccount,
		@PriceList = @priceList,
		@TaxValue = @taxValue,
		@Crd = 0,
		@Margin = 0,
		@ModNumber = 0,
		@QuantityCancelled = 0,
		@Posted = 'N',
		@CurItemValue = @curItemValue,
		@CurPrice = @curPrice,
		@CurDiscountValue = @curDiscountValue,
		@CurTaxValue = @curTaxValue,
		@UnitOfMeasureFactor = @unitOfMeasureFactor,
		@PrintSequence = @printSequence,
		@Source = '',
		@Location = null,
		@Notes = '',
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
		@ReselectRecord = 0,
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
		@ExtendedPrice = @extendedPrice,
		@CurExtendedPrice = @curExtendedPrice,
		@DiscountValueLocked = 0,
		@PriceLocked = 0,
		@ConsignmentSale = 0,
		@Warranty = null,
		@WarrantyPrice = 0,
		@CurWarrantyPrice = 0,
		@Site = @site,
		@TaxCodeSecondary = @taxCodeSecondary,
		@TaxRateSecondary = @taxRateSecondary,
		@TaxValueSecondary = @taxValueSecondary,
		@CurTaxValueSecondary = @curTaxValueSecondary,
		@CurSurcharge = 0,
		@Surcharge = 0,
		@FreightMethod = @freightMethod,
		@StructureVersion = null,
		@ProgressPaymentItem = null,
		@Configuration = null,
		@Header_LastModifiedDate = @headerLastModifiedDate,
		@PickingLocation = null,
		@SalesOrderItemGUID = null,
		@QuoteSalesOrderItem = null,
		@QuoteStatus = null,
		@POSReceiptCode = null,
		@Promotion = null,
		@CallOffOrder = 0,
		@IndiaTaxCode = null,
		@OnHire = null,
		@OffHire = null,
		@HireInvoicedTo = null,
		@Reference = null;

	SELECT @salesOrderItem AS SalesOrderItem, @error AS ErrorMessage;

END;
GO

COMMIT TRANSACTION AlterProcedure;
