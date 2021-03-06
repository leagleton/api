SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing products for the WinMan REST API in JSON format.
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
		AND p.[name] = 'wsp_RestApiProductsSelectJSON'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiProductsSelectJSON AS PRINT ''wsp_RestApiProductsSelectJSON''');
	END;
GO

-- 03Apr18 LAE Added total row count.

ALTER PROCEDURE dbo.wsp_RestApiProductsSelectJSON
	@pageNumber int = 1,
	@pageSize int = 10,
	@sku nvarchar(100) = null,
	@seconds bigint = 315360000,
	@website nvarchar(100),
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiProductsSelectJSON') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiProductsSelectJSON
				@pageNumber = @pageNumber,
				@pageSize = @pageSize,		
				@sku = @sku,
				@seconds = @seconds,				
				@website = @website,
				@scope = @scope,
				@results = @results;
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
			AND w.EcommerceWebsiteId = @website
	)
		BEGIN
			SELECT 'The relevant REST API scope is not enabled for the specified website.' AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	DECLARE @lastModifiedDate datetime;

	SET @lastModifiedDate = (SELECT DATEADD(second,-@seconds,GETDATE()));

	-- 03Apr18 LAE
	DECLARE @total int;

	WITH CTE AS
	(
		SELECT
			ROW_NUMBER() OVER (ORDER BY Products.Product) AS rowNumber,
			Products.ProductGUID,
			Products.ProductId,
			Products.ProductDescription,
			Products.StandardPrice,
			Products.WebPrice,
			Products.WebRRP,
			Products.SurCharge,
			Products.ProductPricingClassification,
			Products.WebDescription,
			Products.WebSummary,
			Products.Taxable,
			Products.TaxCode,
			Products.SalesDiscount,
			Products.Product,
			Products.TitleTag,
			Products.KeywordsTag,
			Products.DescriptionTag,
			Products.PackSize,
			Products.[Length],
			Products.Width,
			Products.Height,
			Products.[Weight],
			Products.UnitOfMeasure,
			Products.DimensionQuantity,
			Products.ConfiguratorOption,
			Products.Manufacturer,
			Products.Barcode,
			Products.CrossReference,
			Products.SalesLeadTime,
			Products.RoHS,
			Products.Notes,
			Products.PromptText,
			Products.Classification,
			Products.ProductStatus,
			Products.LastModifiedDate
		FROM
			Products
			INNER JOIN ProductEcommerceWebsites ON Products.Product = ProductEcommerceWebsites.Product
			INNER JOIN EcommerceWebsites ON EcommerceWebsites.EcommerceWebsite = ProductEcommerceWebsites.EcommerceWebsite

		WHERE
			Products.ProductId = COALESCE(@sku, Products.ProductId)
			AND Products.LastModifiedDate >= @lastModifiedDate
			AND EcommerceWebsites.EcommerceWebsiteId = @website	
		GROUP BY
			Products.ProductGUID,
			Products.ProductId,
			Products.ProductDescription,
			Products.StandardPrice,
			Products.WebPrice,
			Products.WebRRP,
			Products.SurCharge,
			Products.ProductPricingClassification,
			Products.WebDescription,
			Products.WebSummary,
			Products.Taxable,
			Products.TaxCode,
			Products.SalesDiscount,
			Products.Product,
			Products.TitleTag,
			Products.KeywordsTag,
			Products.DescriptionTag,
			Products.PackSize,
			Products.[Length],
			Products.Width,
			Products.Height,
			Products.[Weight],
			Products.UnitOfMeasure,
			Products.DimensionQuantity,
			Products.ConfiguratorOption,
			Products.Manufacturer,
			Products.Barcode,
			Products.CrossReference,
			Products.SalesLeadTime,
			Products.RoHS,
			Products.Notes,
			Products.PromptText,
			Products.Classification,
			Products.ProductStatus,
			Products.LastModifiedDate				
	)    

	SELECT @results = COALESCE(
		(SELECT
			STUFF( 
					(SELECT ',{
						"Guid":"' + CAST(Products.ProductGUID AS nvarchar(36)) + '",
						"Sku":"' + REPLACE(Products.ProductId, '"','&#34;') + '",
						"Name":"' + REPLACE(REPLACE(REPLACE(Products.ProductDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
						"StandardPrice":' + CAST(Products.StandardPrice AS nvarchar(20)) + ',
						"WebPrice":' + CAST(Products.WebPrice AS nvarchar(20)) + ',
						"Rrp":' + CAST(Products.WebRRP AS nvarchar(20)) + ',
						"Surcharge":' + CAST(Products.SurCharge AS nvarchar(20)) + ',
						"ProductPricingClassification":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"ProductPricingClassificationId":"' + REPLACE(ProductPricingClassificationId, '"','&#34;') + '",
											"ProductPricingClassificationDescription":"' + REPLACE(ProductPricingClassificationDescription, '"','&#34;') + '"
										}' FROM ProductPricingClassifications
										WHERE ProductPricingClassifications.ProductPricingClassification = Products.ProductPricingClassification
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(500)'), 1, 1, '')
								),
							'{}')
						 + ',
						"LongDescription":"' + REPLACE(REPLACE(REPLACE(Products.WebDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
						"ShortDescription":"' + REPLACE(REPLACE(REPLACE(Products.WebSummary, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
						"Taxable":' + CASE WHEN Products.Taxable = 1 THEN 'true' ELSE 'false' END + ',
						"TaxCode":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"TaxCodeId":"' + REPLACE(TaxCodeId, '"','&#34;') + '",
											"TaxCodeDescription":"' + REPLACE(TaxCodeDescription, '"','&#34;') + '",
											"TaxRate":' + CAST(TaxRate AS nvarchar(20)) + '
										}' FROM TaxCodes
										WHERE Products.Taxcode = TaxCodes.TaxCode
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(500)'), 1, 1, '')
									),
							'{}')
						 + ',
						"SalesDiscount":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"DiscountId":"' + REPLACE(DiscountId, '"','&#34;') + '",
											"DiscountDescription":"' + REPLACE(DiscountDescription, '"','&#34;') + '",
											"DiscountPercentage":' + CAST(DiscountPercentage AS nvarchar(20)) + ',
											"DiscountBreaks":' + COALESCE((SELECT '[' + STUFF(
											(SELECT ',{
											"DiscountBreakId":"' + REPLACE(DiscountBreakId, '"','&#34;') + '",
											"TriggerType":"' + TriggerType + '",
											"TriggerValue":' + CAST(TriggerValue AS nvarchar(20)) + ',
											"DiscountBreakType":"' + DiscountBreakType + '",
											"DiscountBreakValue":' + CAST(DiscountBreakValue AS nvarchar(20)) + '
											}' FROM DiscountBreaks WHERE DiscountBreaks.Discount = Discounts.Discount FOR XML PATH(''), TYPE)											
											.value('.','nvarchar(max)'), 1, 1, '') + ']'), '[]')
											 + '
										}' FROM Discounts
										WHERE Products.SalesDiscount = Discounts.Discount
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
								),
							'{}')
						 + ',
						"ProductPriceLists":' + 
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"PriceListId":"' + REPLACE(PriceListId, '"','&#34;') + '",
											"PriceListDescription":"' + REPLACE(PriceListDescription, '"','&#34;') + '",
											"ProductPrices":' + (SELECT '[' + STUFF(
											(SELECT ',{
											"Quantity":' + CAST(Quantity AS nvarchar(20)) + ',
											"EffectiveDateStart":"' + CONVERT(nvarchar(50), EffectiveDateStart, 126) + '",
											"EffectiveDateEnd":"' + CONVERT(nvarchar(50), EffectiveDateEnd, 126) + '",
											"PriceValue":' + CAST(PriceValue AS nvarchar(20)) + '
											}' FROM Prices
											WHERE Prices.PriceList = pl.PriceList
												AND Prices.Product = Products.Product
											FOR XML PATH(''), TYPE)											
											.value('.','nvarchar(max)'), 1, 1, '') + ']')
											 + '
										}' FROM PriceLists pl
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
								+ ']'),
							'[]')
						 + ',						 
						"MetaTitle":"' + REPLACE(REPLACE(REPLACE(Products.TitleTag, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
						"MetaKeywords":"' + REPLACE(REPLACE(REPLACE(Products.KeywordsTag, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
						"MetaDescription":"' + REPLACE(REPLACE(REPLACE(Products.DescriptionTag, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
						"PackSize":' + CAST(Products.PackSize AS nvarchar(20)) + ',
						"Length":' + CAST(Products.[Length] AS nvarchar(20)) + ',
						"Width":' + CAST(Products.Width AS nvarchar(20)) + ',
						"Height":' + CAST(Products.Height AS nvarchar(20)) + ',
						"Weight":' + CAST(Products.[Weight] AS nvarchar(20)) + ',
						"UnitOfMeasure":' + 
							(SELECT 
								STUFF(
									(SELECT ',{
										"MeasureName":"' + REPLACE(UnitOfMeasureId, '"','&#34;') + '",
										"MeasureDescription":"' + REPLACE(UnitOfMeasureDescription, '"','&#34;') + '",
										"MeasurePrintText":"' + REPLACE(UnitOfMeasurePrintText, '"','&#34;') + '"
									}' FROM UnitsOfMeasure
									WHERE Products.UnitOfMeasure = UnitsOfMeasure.UnitOfMeasure
									FOR XML PATH(''),
									TYPE).value('.','nvarchar(1000)'), 1, 1, '')
							) + ',
						"DimensionQuantity":' + CAST(Products.DimensionQuantity AS nvarchar(20)) + ',
						"ConfigurableProduct":' + CASE WHEN Products.ConfiguratorOption = 1 THEN 'true' ELSE 'false' END + ','
						+ CASE WHEN Products.ConfiguratorOption = 1 THEN
							'"ConfiguredStructureOptions":' + 
								COALESCE(
									(SELECT '[' +
										STUFF(
											(SELECT ',{
												"OptionId":"' + REPLACE(ConfiguredStructureOptions.ConfiguredStructureOptionId, '"','&#34;') + '",
												"OptionDescription":"' + REPLACE(REPLACE(REPLACE(ConfiguredStructureOptions.[Description], CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
												"AllowMultipleSelection":' + CASE WHEN ConfiguredStructureOptions.AllowMultipleSelection = 'true' THEN 'true' ELSE 'false' END + ',
												"AllowNoSelection":' + CASE WHEN ConfiguredStructureOptions.AllowNoSelection = 'true' THEN 'true' ELSE 'false' END + ',
												"UseDropDown":' + CASE WHEN ConfiguredStructureOptions.UseDropDown = 1 THEN 'true' ELSE 'false' END + ',
												"OptionItems":' +
													(SELECT '[' +
														STUFF(
															(SELECT ',{
																"OptionItemId":"' + REPLACE(ConfiguredItems.ConfiguredItemId, '"','&#34;') + '",
																"OptionItemDescription":"' + REPLACE(REPLACE(REPLACE(ConfiguredItems.[Description], CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
																"OptionItemPrice":' + ConfiguredItems.Price + ',
																"OptionItemDefault":"' + REPLACE(ConfiguredItems.[Default], '"','&#34;') + '"
															}' FROM 
																ConfiguredItems
															WHERE
																ConfiguredItems.ConfiguredStructureOption = ConfiguredStructureOptions.ConfiguredStructureOption
																AND ConfiguredItems.[Enabled] <> 'false'
																AND ConfiguredItems.Calculation = ''
															GROUP BY
																ConfiguredItems.ConfiguredItemId,
																ConfiguredItems.[Description],
																ConfiguredItems.Price,
																ConfiguredItems.[Default],
																ConfiguredItems.ItemPosition
															HAVING
																ISNUMERIC(ConfiguredItems.Price) <> 0
															ORDER BY
																ConfiguredItems.ItemPosition																
															FOR XML PATH(''),
															TYPE).value('.','nvarchar(max)'), 1, 1, '')
														+ ']')
													+ '
											}' FROM
												ConfiguredStructureOptions
												INNER JOIN ConfiguredStructures ON ConfiguredStructures.ConfiguredStructure = ConfiguredStructureOptions.ConfiguredStructure
												INNER JOIN Products p ON p.Product = ConfiguredStructures.Product											
											WHERE 
												p.ProductId = Products.ProductId
												AND ConfiguredStructureOptions.SubConfiguratorCalculation = ''
												AND EXISTS (SELECT ConfiguredItemId FROM ConfiguredItems WHERE ConfiguredItems.ConfiguredStructureOption = ConfiguredStructureOptions.ConfiguredStructureOption)
											GROUP BY
												ConfiguredStructureOptions.ConfiguredStructureOption,
												ConfiguredStructureOptions.ConfiguredStructureOptionId,
												ConfiguredStructureOptions.[Description],
												ConfiguredStructureOptions.AllowMultipleSelection,
												ConfiguredStructureOptions.AllowNoSelection,
												ConfiguredStructureOptions.UseDropDown,
												ConfiguredStructureOptions.OptionPosition
											ORDER BY
												ConfiguredStructureOptions.OptionPosition
											FOR XML PATH(''),
											TYPE).value('.','nvarchar(max)'), 1, 1, '')
									+ ']'),
								'[]')								 
							+ ','
							ELSE ''						
						END + '
						"Brand":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"ManufacturerId":"' + REPLACE(Manufacturers.ManufacturerId, '"','&#34;') + '",
											"ManufacturerDescription":"' + REPLACE(Manufacturers.ManufacturerDescription, '"','&#34;') + '",
											"ManufacturerLogo":"' + dbo.wfn_RestApiGetImageString(Manufacturers.ManufacturerLogo) + '"
										}' FROM Manufacturers
										WHERE Products.Manufacturer = Manufacturers.Manufacturer
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
								),
							'{}')
						 + ',
						"Barcode":"' + REPLACE(Products.Barcode, '"','&#34;') + '",
						"CrossReference":"' + REPLACE(Products.CrossReference, '"','&#34;') + '",
						"SalesLeadTime":' + CAST(Products.SalesLeadTime AS nvarchar(20)) + ',
						"RoHS":"' + Products.RoHS + '",
						"Notes":"' + REPLACE(REPLACE(REPLACE(Products.Notes, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
						"PromptText":"' + REPLACE(REPLACE(REPLACE(Products.PromptText, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
						"Classification":' + 
							(SELECT 
								STUFF(
									(SELECT ',{
										"ClassificationName":"' + REPLACE(ClassificationId, '"','&#34;') + '",
										"ClassificationDescription":"' + REPLACE(ClassificationDescription, '"','&#34;') + '"
									}' FROM Classifications
									WHERE Products.Classification = Classifications.Classification
									FOR XML PATH(''),
									TYPE).value('.','nvarchar(500)'), 1, 1, '')
							) + ',
						"AlternativeProducts":' + 
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"AlternativeProductSku":"' + REPLACE(p.ProductId, '"','&#34;') + '",
											"AlternativeProductName":"' + REPLACE(REPLACE(REPLACE(p.ProductDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '"
										}' FROM Products p
										INNER JOIN AlternativeParts a ON a.AlternativeProduct = p.Product
										WHERE a.Product = Products.Product
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
								+ ']'),
							'[]')
						 + ',
						"RelatedProducts":' + 
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"RelatedProductSku":"' + REPLACE(p.ProductId, '"','&#34;') + '",
											"RelatedProductName":"' + REPLACE(REPLACE(REPLACE(p.ProductDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '"
										}' FROM Products p
										INNER JOIN ProductRelations r ON r.RelatedProduct = p.Product
										WHERE r.Product = Products.Product
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
								+ ']'),
							'[]')
						 + ',
						"SupersedingProduct":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"SupersedingProductSku":"' + REPLACE(pp.ProductId, '"','&#34;') + '",
											"SupersedingProductName":"' + REPLACE(REPLACE(REPLACE(pp.ProductDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '"
										}' FROM Products sp
										INNER JOIN Products pp ON sp.Product = pp.SuperceededBy
										WHERE pp.Product = Products.Product
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(500)'), 1, 1, '')
								),
							'{}')
						 + ',
						"Warranties":' + 
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"WarrantyId":"' + REPLACE(WarrantyId, '"','&#34;') + '",
											"WarrantyDescription":"' + REPLACE(WarrantyDescription, '"','&#34;') + '",
											"WarrantyPeriod":' + CAST(WarrantyPeriod AS nvarchar(20)) + ',
											"WarrantyUnit":"' + WarrantyUnit + '"
										}' FROM Warranties w
										INNER JOIN ProductWarranties pw ON pw.Warranty = w.Warranty
										WHERE pw.Product = Products.Product
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
								+ ']'),
							'[]')
						 + ',
						"ProductStatus":' + 
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"ProductStatusId":"' + REPLACE(ProductStatusId, '"','&#34;') + '",
											"ProductStatusDisplayName":"' + REPLACE(DisplayName, '"','&#34;') + '"
										}' FROM ProductStatuses
										WHERE Products.ProductStatus = ProductStatuses.ProductStatus
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(500)'), 1, 1, '')
								+ ']'),
							'{}')
						 + ',
						"LastModifiedDate":"' + CONVERT(nvarchar(50), Products.LastModifiedDate, 126) + '",
						 "CustomColumns": ' + 
							COALESCE(
							(SELECT dbo.wfn_RestApiGetCustomColumnsJSON(Products.Product))
							, '[]') +
					'}' FROM CTE AS Products
	                WHERE 
                        (rowNumber > @pageSize * (@pageNumber - 1) )
                        AND (rowNumber <= @pageSize * @pageNumber )
                    ORDER BY
                        rowNumber                    
					FOR XML PATH(''), 
				TYPE).value('.','nvarchar(max)'), 1, 1, '' 
			-- 03Apr18 LAE
			--)), '');
			)), ''), @total = (SELECT COUNT(*) FROM CTE);

	SELECT @results = REPLACE(REPLACE(REPLACE(REPLACE('{"Products":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), ''), '\', '\\');

	-- 03Apr18 LAE
	--SELECT @results AS Results;
	SELECT @results AS Results, @total AS TotalCount;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
