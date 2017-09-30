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
	@salesOrder bigint = null,
	@itemType CHAR(1) = null,
	@sku nvarchar(100) = null,
	@quantity decimal(17,5) = null,
	@warrantyId nvarchar(20) = null,
	@curSurcharge money = null,
	@delName nvarchar(50) = null,
	@delTitle nvarchar(5) = null,
	@delFirstName nvarchar(25) = null,
	@delLastName nvarchar(25) = null,
	@delAddress nvarchar(200) = null,
	@delCity nvarchar(50) = null,
	@delRegion nvarchar(50) = null,
	@delPostalCode nvarchar(20) = null,
	@delCountryCode nvarchar(3) = null,
	@delPhoneNumber nvarchar(30) = null,
	@delEmailAddress nvarchar(450) = null,
	@priceListId nvarchar(15) = null,
	@freightMethodId nvarchar(15) = null,
	@discountId nvarchar(15) = null,
	@taxCodeId nvarchar(15) = null,
	@taxCodeSecondaryId nvarchar(15) = null,
	@curPrice money = null
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiSalesOrderItemsInsert') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiSalesOrderItemsInsert
				@salesOrder = @salesOrder,
				@itemType = @itemType,
				@sku = @sku,
				@quantity = @quantity,
				@warrantyId = @warrantyId,
				@curSurcharge = @curSurcharge,
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
				@priceListId = @priceListId,
				@freightMethodId = @freightMethodId,
				@discountId = @discountId,
				@taxCodeId = @taxCodeId,
				@taxCodeSecondaryId = @taxCodeSecondaryId,
				@curPrice = @curPrice;
			RETURN;
		END;

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	DECLARE @error nvarchar(100);
	SET @error = '';

	IF @salesOrder IS NULL OR @salesOrder = 0
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Sales Order Number.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;		
		END;

	IF @itemType IS NULL OR @itemType = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Item Type.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;			
			RETURN;		
		END;

	IF @curPrice IS NULL
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Price.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;			
			RETURN;		
		END;

	IF @quantity IS NULL OR @quantity = 0
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Quantity.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;			
			RETURN;
		END;

	IF @delName IS NULL OR @delName = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Delivery Name.';			
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;			
			RETURN;
		END;

	IF @delAddress IS NULL OR @delAddress = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Delivery Address.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;			
			RETURN;		
		END;

	DECLARE	@site bigint;
	DECLARE	@product bigint;
	DECLARE @taxable bit;
	DECLARE @warranty bigint;
	DECLARE @exchangeRate decimal(18,6);
	DECLARE @surcharge money;
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
	DECLARE @curTaxValue money;
	DECLARE @taxValue money;
	DECLARE @taxCodeSecondary bigint;
	DECLARE @taxRateSecondary decimal(17,5);
	DECLARE @curTaxValueSecondary money;
	DECLARE @taxValueSecondary money;
	DECLARE @curExtendedPrice money;
	DECLARE @price money;
	DECLARE @extendedPrice money;
	DECLARE @curItemValue money;
	DECLARE @curDiscountValue money;
	DECLARE @itemValue money;
	DECLARE @unitOfMeasure bigint;
	DECLARE @unitOfMeasureFactor bigint;
	DECLARE @date datetime;
	DECLARE @user nvarchar(20);

	SET @product = null;
	SET @surcharge = 0;
	SET @freightMethod = null;
	SET @discountValue = 0;
	SET @curTaxValue = 0;
	SET @taxValue = 0;
	SET @taxRateSecondary = 0;
	SET @curTaxValueSecondary = 0;
	SET @taxValueSecondary = 0;
	SET @curExtendedPrice = 0;
	SET @price = 0;
	SET @extendedPrice = 0;
	SET @curItemValue = 0;
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
			@glAccountDivision = GLAccountDivision,
			@glAccountType = GLAccountType,
			@exchangeRate = (SELECT ActualRate FROM Currencies WHERE Currency = SalesOrders.Currency),
			@priceList = CASE WHEN @priceListId IS NULL OR @priceListId = '' THEN SalesOrders.PriceList ELSE 0 END,
			@discount = CASE WHEN @discountId IS NULL OR @discountId = '' THEN SalesOrders.Discount ELSE 0 END,
			@taxCode = CASE WHEN @taxCodeId IS NULL OR @taxCodeId = '' THEN SalesOrders.TaxCode ELSE 0 END,
			@taxCodeSecondary = CASE WHEN @taxCodeSecondaryId IS NULL OR @taxCodeSecondaryId = '' THEN SalesOrders.TaxCodeSecondary ELSE 0 END
		FROM
			SalesOrders
			INNER JOIN Customers ON Customers.Customer = SalesOrders.Customer
		WHERE
			SalesOrder = @salesOrder;
	END;

	IF @priceList = 0
		BEGIN
			SET @priceList = (SELECT PriceList FROM PriceLists WHERE PriceListId = @priceListId);
			IF @priceList IS NULL
				BEGIN
					SET @error = 'ERROR: Could not find price list with the specified price list ID. Please check your input data.';
					SELECT @error AS ErrorMessage;
					ROLLBACK TRANSACTION;
					RETURN;
				END;
		END;

	IF @discount = 0
		BEGIN
			SET @discount = (SELECT Discount FROM Discounts WHERE DiscountId = @discountId);
			IF @discount IS NULL
				BEGIN
					SET @error = 'ERROR: Could not find discount with the specified discount ID. Please check your input data.';
					SELECT @error AS ErrorMessage;
					ROLLBACK TRANSACTION;
					RETURN;
				END;
		END;

	IF @taxCode = 0
		BEGIN
			SET @taxCode = (SELECT TaxCode FROM TaxCodes WHERE TaxCodeId = @taxCodeId);
			IF @taxCode IS NULL
				BEGIN
					SET @error = 'ERROR: Could not find tax code with the specified tax code ID. Please check your input data.';
					SELECT @error AS ErrorMessage;
					ROLLBACK TRANSACTION;
					RETURN;
				END;
		END;

	BEGIN
		SET @taxRate = (SELECT TaxRate FROM TaxCodes WHERE TaxCode = @taxCode);
	END;

	IF @taxCodeSecondary = 0
		BEGIN
			SET @taxCodeSecondary = (SELECT TaxCode FROM TaxCodes WHERE TaxCodeId = @taxCodeSecondaryId);
			IF @taxCodeSecondary IS NULL
				BEGIN
					SET @error = 'ERROR: Could not find secondary tax code with the specified tax code ID. Please check your input data.';
					SELECT @error AS ErrorMessage;
					ROLLBACK TRANSACTION;
					RETURN;
				END;
			ELSE
				BEGIN
					SET @taxRateSecondary = (SELECT TaxRate FROM TaxCodes WHERE TaxCode = @taxCodeSecondary);
				END;
		END;
	ELSE
		BEGIN
			SET @taxCodeSecondary = null;
		END;

	IF @itemType = 'P' AND (@sku IS NULL OR @sku = '')
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Product SKU.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;
	ELSE IF @itemType = 'P' AND @sku IS NOT NULL AND @sku <> ''
		BEGIN
			SELECT
				@product = Product,
				@unitOfMeasure = UnitOfMeasure,
				@taxable = Taxable
			FROM
				Products
			WHERE
				ProductId = @sku;

			IF @product IS NULL
				BEGIN
					SET @error = 'ERROR: Could not find product with the specified SKU. Please check your input data.';
					SELECT @error AS ErrorMessage;
					ROLLBACK TRANSACTION;
					RETURN;
				END;
			ELSE
				BEGIN
					SET @itemDescription = (SELECT ProductDescription FROM Products WHERE Product = @product);
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
			SET @error = 'ERROR: Required parameter missing: Freight Method ID.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;
	ELSE IF @itemType = 'F' AND @freightMethodId IS NOT NULL AND @freightMethodId <> ''
		BEGIN
			SET @freightMethod = (SELECT FreightMethod FROM FreightMethods WHERE FreightMethodId = @freightMethodId);
			IF @freightMethod IS NULL
				BEGIN
					SET @error = 'ERROR: Could not find freight method with the specified freight method ID. Please check your input data.';
					SELECT @error AS ErrorMessage;
					ROLLBACK TRANSACTION;
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

	IF @warrantyId IS NULL OR @warrantyId = ''
		BEGIN
			SET @warranty = 0;
		END;
	ELSE
		BEGIN
			SET @warranty = (SELECT Warranty FROM Warranties WHERE WarrantyId = @warrantyId);
		END;

	IF @warranty IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find warranty with the specified warranty ID. Please check your input data.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;	
		END;
	ELSE
		BEGIN
			SET @warranty = null;
		END;

	IF @curSurcharge <> 0
		BEGIN
			SET @surcharge = ROUND(CAST((@cursurcharge / @exchangeRate) AS FLOAT), 2);
		END;
	ELSE
		BEGIN
			SET @curSurcharge = ROUND(CAST(@surcharge AS FLOAT) * @quantity, 2);
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
			SET @error = 'ERROR: Required parameter missing: Delivery Postal Code.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;		
		END

	IF @delCountryCode IS NULL OR @delCountryCode = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Delivery Country Code.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
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
			ROLLBACK TRANSACTION;
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
			SET @curExtendedPrice = ROUND(CAST(@curPrice AS FLOAT) * @quantity, 2);
			SET @price = ROUND(CAST((@curPrice / @exchangeRate) AS FLOAT), 2);
			SET @extendedPrice = ROUND(CAST((@curExtendedPrice / @exchangeRate) AS FLOAT), 2);
			SET @curTaxValue = CASE WHEN @taxable = 1 THEN ROUND(CAST((((@curExtendedPrice - @curDiscountValue)) * (@taxRate / 100)) AS FLOAT), 2) ELSE 0 END;
			SET @taxValue = CASE WHEN @taxable = 1 THEN ROUND(CAST((@curTaxValue / @exchangeRate) AS FLOAT), 2) ELSE 0 END;
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

	IF @curPrice > 0
		BEGIN
			SET @curItemValue = ROUND(CAST((@curExtendedPrice - @curDiscountValue) AS FLOAT), 2);
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
		@Warranty = @warranty,
		@WarrantyPrice = 0,
		@CurWarrantyPrice = 0,
		@Site = @site,
		@TaxCodeSecondary = @taxCodeSecondary,
		@TaxRateSecondary = @taxRateSecondary,
		@TaxValueSecondary = @taxValueSecondary,
		@CurTaxValueSecondary = @curTaxValueSecondary,
		@CurSurcharge = @curSurcharge,
		@Surcharge = @surcharge,
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

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
