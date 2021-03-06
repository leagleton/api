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

-- 13Mar18 LAE Add configurator products #0000139388

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
	@curTaxValue money,
	-- 13Mar18 LAE
	@configuration uniqueidentifier = null,
	@pseudoSku nvarchar(100) = null
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

	DECLARE @curItemValue money;
	DECLARE @curExtendedPrice money;
	DECLARE @curPrice money;	
	DECLARE @error nvarchar(100);

	SET @curItemValue = 0;
	SET @curExtendedPrice = 0;
	SET @curPrice = 0;
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
			DECLARE @useConfigurator bit;

			SELECT
				@product = Product,
				@unitOfMeasure = UnitOfMeasure,
				@taxable = Taxable,
				@glAccountDivision = SalesGLDivision,
				@glAccountType = SalesGLAccount,
				@useConfigurator = ConfiguratorOption
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

			IF @useConfigurator = 1
				BEGIN
					SET @error = 'The product ' + @sku + ' is a configurable product but you have not specified any option information. Please check your input data.';
					SELECT @error AS ErrorMessage;
					RETURN;
				END;

			SET @itemDescription = (SELECT ProductDescription FROM Products WHERE Product = @product);

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

	-- 13Mar18 LAE
	DECLARE @identifier nvarchar(100);

	IF @itemType = 'N' AND (@sku IS NULL OR @sku = '')
		BEGIN
			SET @error = 'A required parameter is missing: Sku.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;
	ELSE IF @itemType = 'N' AND (@pseudoSku IS NULL OR @pseudoSku = '')
		BEGIN
			SET @error = 'A required parameter is missing: ConfiguredSku.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;	
	ELSE IF @itemType = 'N' AND @sku IS NOT NULL AND @sku <> ''
		BEGIN
			DECLARE @configuredProduct bigint;
			SET @configuredProduct = (SELECT Product FROM Products WHERE ProductId = @sku AND ConfiguratorOption = 1);

			IF @configuredProduct IS NULL
				BEGIN
					SET @error = 'Could not find the specified product: ' + @sku + '. Please check your input data.';
					SELECT @error AS ErrorMessage;	
					RETURN;		
				END;

			IF dbo.wfn_GetProgramProfile('Configurator_BuildIdentifier', 'N') = 'Y'
				BEGIN
					DECLARE @itemCursor cursor;
					DECLARE @delineator nvarchar(10);
					DECLARE @optionItemPrefix nvarchar(100);

					SET @delineator = dbo.wfn_GetProgramProfile('Configurator_Delineator', '');
					SET @identifier = (SELECT Prefix FROM ConfiguredStructures WHERE Product = @configuredProduct);

					SET @itemCursor = CURSOR FAST_FORWARD
										FOR
											SELECT
												ConfiguredItems.Prefix
											FROM
												ConfiguredItems
												INNER JOIN ConfiguredItemValues ON ConfiguredItemValues.ConfiguredItem = ConfiguredItems.ConfiguredItem
												INNER JOIN ConfiguredStructureOptions ON ConfiguredStructureOptions.ConfiguredStructureOption = ConfiguredItems.ConfiguredStructureOption
											WHERE
												ConfiguredItemValues.[Configuration] = @configuration
												AND ConfiguredItemValues.[Value] = 1
											ORDER BY
												ConfiguredStructureOptions.OptionPosition,
												ConfiguredItems.ItemPosition;

					OPEN @itemCursor
						FETCH NEXT FROM
							@itemCursor
						INTO
							@optionItemPrefix;

						WHILE @@FETCH_STATUS = 0
							BEGIN
								SET @identifier = @identifier + @delineator + @optionItemPrefix;

								FETCH NEXT FROM
									@itemCursor
								INTO
									@optionItemPrefix;
							END;				
					CLOSE @itemCursor;

					DEALLOCATE @itemCursor;
				END;
			ELSE
				BEGIN
					EXEC wsp_ConfiguredStructuresGetConfiguredProductId
						@ConfiguredProduct = @configuredProduct,
						@ConfiguredProductId = @identifier OUTPUT;
				END;

			DECLARE @description nvarchar(max);
			DECLARE @notes nvarchar(max);

			SET @description = '';
			SET @notes = '';

			DECLARE	@cursor	cursor;
			DECLARE @salesOrderDescription nvarchar(max);
			DECLARE @salesOrderNotes nvarchar(max);
			DECLARE @configuredStructureOptionId nvarchar(100);
			DECLARE @configuredItemId nvarchar(100);
			DECLARE @configuredItemDescription nvarchar(300);
			DECLARE @useDescriptionExpression char(1);
			DECLARE @useOptionDescriptions char(1);
			DECLARE @mandatoryOptions nvarchar(1000);
			DECLARE @singleSelectionOptions nvarchar(1000);

			SET @useDescriptionExpression = dbo.wfn_GetProgramProfile('Configurator_UseDescriptionExpression', 'N');
			SET @useOptionDescriptions = dbo.wfn_GetProgramProfile('Configurator_UseOptionDescriptions', 'N');

			SET @mandatoryOptions = (SELECT STUFF(
										(SELECT ', ' + 
											ConfiguredStructureOptionId
										FROM
											ConfiguredStructureOptions
										WHERE
											ConfiguredStructure = 2
											AND AllowNoSelection = 'false'
											AND ConfiguredStructureOption NOT IN (SELECT
																						ConfiguredStructureOption
																					FROM
																						ConfiguredItems
																						INNER JOIN ConfiguredItemValues ON ConfiguredItemValues.ConfiguredItem = ConfiguredItems.ConfiguredItem
																					WHERE
																						ConfiguredItemValues.[Configuration] = @configuration)
										ORDER BY
											ConfiguredStructureOption
										FOR XML PATH(''), TYPE).value('.', 'nvarchar(1000)'), 1, 1, ''
									));

			IF @mandatoryOptions IS NOT NULL
				BEGIN
					SET @error = 'For the product: ' + @sku + ', you have not specified any option information for the following options:' + @mandatoryOptions + '. In order to purchase this product, a selection must be made for these options. Please check your input data.';
					SELECT @error AS ErrorMessage;	
					RETURN;				
				END;

			SET @singleSelectionOptions = (SELECT STUFF(
											(SELECT ', ' + 
												ConfiguredStructureOptionId
											FROM
												ConfiguredItemValues 
												INNER JOIN ConfiguredItems ON ConfiguredItems.ConfiguredItem = ConfiguredItemValues.ConfiguredItem
												INNER JOIN ConfiguredStructureOptions ON ConfiguredStructureOptions.ConfiguredStructureOption = ConfiguredItems.ConfiguredStructureOption
											WHERE
												ConfiguredItemValues.[Configuration] = @configuration
												AND AllowMultipleSelection = 'false'
											GROUP BY
												ConfiguredStructureOptionId
											HAVING
												COUNT(ConfiguredItemValue) > 1
											FOR XML PATH(''), TYPE).value('.', 'nvarchar(1000)'), 1, 1, ''
										));

			IF @singleSelectionOptions IS NOT NULL
				BEGIN
					SET @error = 'For the product: '+ @sku + ', you have specified multiple selections for the following options:' + @singleSelectionOptions + '. These options only allow one selection. Please check your input data.';
					SELECT @error AS ErrorMessage;	
					RETURN;				
				END;								

			SET @cursor = CURSOR FAST_FORWARD
							FOR
								SELECT
									ConfiguredStructureOptions.ConfiguredStructureOptionId,
									ConfiguredItems.ConfiguredItemId,
									ConfiguredItems.SalesOrderDescription,
									ConfiguredItems.SalesOrderNotes,
									ConfiguredItems.[Description]
								FROM
									ConfiguredItems
									INNER JOIN ConfiguredItemValues ON ConfiguredItemValues.ConfiguredItem = ConfiguredItems.ConfiguredItem
									INNER JOIN ConfiguredStructureOptions ON ConfiguredItems.ConfiguredStructureOption = ConfiguredStructureOptions.ConfiguredStructureOption
								WHERE
									ConfiguredItemValues.[Configuration] = @configuration;

			OPEN @cursor
				FETCH NEXT FROM
					@cursor
				INTO
					@configuredStructureOptionId,
					@configuredItemId,
					@salesOrderDescription,
					@salesOrderNotes,
					@configuredItemDescription;

				WHILE @@FETCH_STATUS = 0
					BEGIN
						IF @useDescriptionExpression = 'Y'
							BEGIN
								IF @salesOrderDescription <> ''
									BEGIN
										SET @description = @description + @salesOrderDescription + CHAR(13) + CHAR(10);
										SET @notes = @description;
									END;
							END;
						ELSE
							BEGIN
								IF @useOptionDescriptions = 'N'
									BEGIN
										IF @salesOrderDescription <> ''
											BEGIN
												SET @description = @description + @configuredStructureOptionId + ' : ' + @configuredItemId + CHAR(13) + CHAR(10);
											END;
									END;
								ELSE
									BEGIN
										IF @salesOrderDescription <> ''
											BEGIN
												SET @description = @description + @configuredStructureOptionId + ' : ' + @configuredItemDescription + CHAR(13) + CHAR(10);
											END;
									END;

								IF @salesOrderNotes <> ''
									BEGIN
										SET @notes = @notes + @salesOrderNotes + CHAR(13) + CHAR(10);
									END;
							END;

						FETCH NEXT FROM
							@cursor
						INTO
							@configuredStructureOptionId,
							@configuredItemId,
							@salesOrderDescription,
							@salesOrderNotes,
							@configuredItemDescription;
					END;
			CLOSE @cursor;

			DEALLOCATE @cursor;

			EXEC wsp_ConfiguredConfigurationsInsert
				@Configuration = @configuration,
				@ConfiguredStructureOption = NULL,
				@ConfigurationDescription = @description,
				@ConfigurationNotes = @notes,
				@ConfigurationIdentifier = @identifier,
				@ConfigurationMinPrice = @extendedPrice,
				@ConfigurationPrice = @extendedPrice,
				@ConfigurationMaxPrice = @extendedPrice,
				@ValidForCompletion = 1,
				@UserName = @user,
				@Product = @configuredProduct,
				@ConfigurationDiscountValue = 0;

			SET @itemDescription = @pseudoSku;
		END;		

	EXEC dbo.wsp_SalesOrderItemsInsert
		@SalesOrder = @salesOrder,
		@ItemType = @itemType, 
		@Product = @product,
		@Sundry = null,
		-- 12Mar18 LAE
		--@FreeTextItem = null,
		@FreeTextItem = @identifier,
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
		-- 13Mar18 LAE
		--@Configuration = null,
		@Configuration = @configuration,
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
