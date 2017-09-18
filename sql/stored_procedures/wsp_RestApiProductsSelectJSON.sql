SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing products for the WinMan REST API in JSON format.
-- =============================================

CREATE PROCEDURE dbo.wsp_RestApiProductsSelectJSON
	@sku NVARCHAR(100) = NULL,
	@seconds BIGINT = 315360000,
	@website NVARCHAR(100),
	@results NVARCHAR(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiProductsSelectJSON') = 1 
	BEGIN
		EXEC dbo.bsp_RestApiProductsSelectJSON
			@sku = @sku,
			@website = @website,
			@seconds = @seconds,
			@results = @results
		RETURN	
	END

	SET NOCOUNT ON;

	DECLARE 
		@lastModifiedDate DATETIME

	SET @lastModifiedDate = (SELECT DATEADD(second,-@seconds,GETDATE()));

	SELECT @results = COALESCE(
		(SELECT
			STUFF( 
					(SELECT ',{
						"Guid":"' + CAST(Products.ProductGUID AS NVARCHAR(36)) + '",
						"Sku":"' + REPLACE(Products.ProductId, '"','&#34;') + '",
						"Name":"' + REPLACE(REPLACE(REPLACE(Products.ProductDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
						"StandardPrice":' + CAST(Products.StandardPrice AS NVARCHAR(20)) + ',
						"WebPrice":' + CAST(Products.WebPrice AS NVARCHAR(20)) + ',
						"Rrp":' + CAST(Products.WebRRP AS NVARCHAR(20)) + ',
						"Surcharge":' + CAST(Products.SurCharge AS NVARCHAR(20)) + ',
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
										TYPE).value('.','NVARCHAR(500)'), 1, 1, '')
								),
							'{}')
						 + ',
						"LongDescription":' + CASE WHEN Products.WebDescription IS NULL THEN 'null' ELSE '"' + REPLACE(REPLACE(REPLACE(Products.WebDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '"' END + ',
						"ShortDescription":' + CASE WHEN Products.WebSummary IS NULL THEN 'null' ELSE '"' + REPLACE(REPLACE(REPLACE(Products.WebSummary, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '"' END + ',
						"Taxable":' + CASE WHEN Products.Taxable = 1 THEN 'true' ELSE 'false' END + ',
						"TaxCode":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"TaxCodeId":"' + REPLACE(REPLACE(REPLACE(TaxCodeId, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"TaxCodeDescription":"' + REPLACE(REPLACE(REPLACE(TaxCodeDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"TaxRate":' + CAST(TaxRate AS NVARCHAR(20)) + '
										}' FROM TaxCodes
										WHERE Products.Taxcode = TaxCodes.TaxCode
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(500)'), 1, 1, '')
									),
							'{}')
						 + ',
						"SalesDiscount":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"DiscountId":"' + REPLACE(REPLACE(REPLACE(DiscountId, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"DiscountDescription":"' + REPLACE(REPLACE(REPLACE(DiscountDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"DiscountPercentage":' + CAST(DiscountPercentage AS NVARCHAR(20)) + ',
											"DiscountBreaks":' + (SELECT '[' + STUFF(
											(SELECT ',{
											"DiscountBreakId":"' + REPLACE(REPLACE(REPLACE(DiscountBreakId, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"TriggerType":"' + TriggerType + '",
											"TriggerValue":' + CAST(TriggerValue AS NVARCHAR(20)) + ',
											"DiscountBreakType":"' + DiscountBreakType + '",
											"DiscountBreakValue":' + CAST(DiscountBreakValue AS NVARCHAR(20)) + '
											}' FROM DiscountBreaks WHERE DiscountBreaks.Discount = Discounts.Discount FOR XML PATH(''), TYPE)											
											.value('.','NVARCHAR(max)'), 1, 1, '') + ']')
											 + '
										}' FROM Discounts
										WHERE Products.SalesDiscount = Discounts.Discount
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
								),
							'{}')
						 + ',
						"ProductPriceLists":' + 
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"PriceListId":"' + REPLACE(REPLACE(REPLACE(PriceListId, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"PriceListDescription":"' + REPLACE(REPLACE(REPLACE(PriceListDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"ProductPrices":' + (SELECT '[' + STUFF(
											(SELECT ',{
											"Quantity":' + CAST(Quantity AS NVARCHAR(20)) + ',
											"EffectiveDateStart":"' + CONVERT(NVARCHAR(50), EffectiveDateStart, 126) + '",
											"EffectiveDateEnd":"' + CONVERT(NVARCHAR(50), EffectiveDateEnd, 126) + '",
											"PriceValue":' + CAST(PriceValue AS NVARCHAR(20)) + '
											}' FROM Prices
											WHERE Prices.PriceList = pl.PriceList
												AND Prices.Product = Products.Product
											FOR XML PATH(''), TYPE)											
											.value('.','NVARCHAR(max)'), 1, 1, '') + ']')
											 + '
										}' FROM PriceLists pl
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
								+ ']'),
							'[]')
						 + ',						 
						"MetaTitle":"' + REPLACE(REPLACE(REPLACE(Products.TitleTag, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
						"MetaKeywords":"' + REPLACE(REPLACE(REPLACE(Products.KeywordsTag, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
						"MetaDescription":"' + REPLACE(REPLACE(REPLACE(Products.DescriptionTag, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
						"PackSize":' + CAST(Products.PackSize AS NVARCHAR(20)) + ',
						"Length":' + CAST(Products.[Length] AS NVARCHAR(20)) + ',
						"Width":' + CAST(Products.Width AS NVARCHAR(20)) + ',
						"Height":' + CAST(Products.Height AS NVARCHAR(20)) + ',
						"Weight":' + CAST(Products.[Weight] AS NVARCHAR(20)) + ',
						"UnitOfMeasure":' + 
							(SELECT 
								STUFF(
									(SELECT ',{
										"MeasureName":"' + REPLACE(REPLACE(REPLACE(UnitOfMeasureId, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
										"MeasureDescription":"' + REPLACE(REPLACE(REPLACE(UnitOfMeasureDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
										"MeasurePrintText":"' + REPLACE(REPLACE(REPLACE(UnitOfMeasurePrintText, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '"
									}' FROM UnitsOfMeasure
									WHERE Products.UnitOfMeasure = UnitsOfMeasure.UnitOfMeasure
									FOR XML PATH(''),
									TYPE).value('.','NVARCHAR(1000)'), 1, 1, '')
							) + ',
						"DimensionQuantity":' + CAST(Products.DimensionQuantity AS NVARCHAR(20)) + ',
						"ConfigurableProduct":' + CASE WHEN Products.ConfiguratorOption = 1 THEN 'true' ELSE 'false' END + ',
						"Brand":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"ManufacturerId":"' + REPLACE(REPLACE(REPLACE(Manufacturers.ManufacturerId, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"ManufacturerDescription":"' + REPLACE(REPLACE(REPLACE(Manufacturers.ManufacturerDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"ManufacturerLogo":"' + dbo.wfn_RestApiGetImageString(Manufacturers.ManufacturerLogo) + '"
										}' FROM Manufacturers
										WHERE Products.Manufacturer = Manufacturers.Manufacturer
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
								),
							'{}')
						 + ',
						"Barcode":"' + Products.Barcode + '",
						"CrossReference":"' + Products.CrossReference + '",
						"SalesLeadTime":' + CAST(Products.SalesLeadTime AS NVARCHAR(20)) + ',
						"RoHS":"' + Products.RoHS + '",
						"Notes":"' + REPLACE(REPLACE(REPLACE(Products.Notes, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
						"PromptText":"' + REPLACE(REPLACE(REPLACE(Products.PromptText, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
						"Classification":' + 
							(SELECT 
								STUFF(
									(SELECT ',{
										"ClassificationName":"' + REPLACE(REPLACE(REPLACE(ClassificationId, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
										"ClassificationDescription":"' + REPLACE(REPLACE(REPLACE(ClassificationDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '"
									}' FROM Classifications
									WHERE Products.Classification = Classifications.Classification
									FOR XML PATH(''),
									TYPE).value('.','NVARCHAR(500)'), 1, 1, '')
							) + ',
						"AlternativeProducts":' + 
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"AlternativeProductSku":"' + REPLACE(REPLACE(REPLACE(p.ProductId, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"AlternativeProductName":"' + REPLACE(REPLACE(REPLACE(p.ProductDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '"
										}' FROM Products p
										INNER JOIN AlternativeParts a ON a.AlternativeProduct = p.Product
										WHERE a.Product = Products.Product
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
								+ ']'),
							'[]')
						 + ',
						"RelatedProducts":' + 
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"RelatedProductSku":"' + REPLACE(REPLACE(REPLACE(p.ProductId, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"RelatedProductName":"' + REPLACE(REPLACE(REPLACE(p.ProductDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '"
										}' FROM Products p
										INNER JOIN ProductRelations r ON r.RelatedProduct = p.Product
										WHERE r.Product = Products.Product
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
								+ ']'),
							'[]')
						 + ',
						"SupersedingProduct":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"SupersedingProductSku":"' + REPLACE(REPLACE(REPLACE(pp.ProductId, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"SupersedingProductName":"' + REPLACE(REPLACE(REPLACE(pp.ProductDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '"
										}' FROM Products sp
										INNER JOIN Products pp ON sp.Product = pp.SuperceededBy
										WHERE pp.Product = Products.Product
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(500)'), 1, 1, '')
								),
							'{}')
						 + ',
						"Warranties":' + 
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"WarrantyId":"' + REPLACE(REPLACE(REPLACE(WarrantyId, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"WarrantyDescription":"' + REPLACE(REPLACE(REPLACE(WarrantyDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"WarrantyPeriod":' + CAST(WarrantyPeriod AS NVARCHAR(20)) + ',
											"WarrantyUnit":"' + WarrantyUnit + '"
										}' FROM Warranties w
										INNER JOIN ProductWarranties pw ON pw.Warranty = w.Warranty
										WHERE pw.Product = Products.Product
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
								+ ']'),
							'[]')
						 + ',
						"ProductStatus":' + 
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"ProductStatusId":"' + REPLACE(REPLACE(REPLACE(ProductStatusId, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"ProductStatusDisplayName":"' + REPLACE(REPLACE(REPLACE(DisplayName, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '"
										}' FROM ProductStatuses
										WHERE Products.ProductStatus = ProductStatuses.ProductStatus
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(500)'), 1, 1, '')
								+ ']'),
							'{}')
						 + ',
						"LastModifiedDate":"' + CONVERT(NVARCHAR(50), Products.LastModifiedDate, 126) + '",
						 "CustomColumns": ' + 
							COALESCE(
							(SELECT dbo.wfn_RestApiGetCustomColumnsJSON(Products.Product))
							, '[]') +
					'}' FROM Products 
						INNER JOIN ProductEcommerceWebsites ON Products.Product = ProductEcommerceWebsites.Product
						INNER JOIN EcommerceWebsites ON EcommerceWebsites.EcommerceWebsite = ProductEcommerceWebsites.EcommerceWebsite
					WHERE 
						Products.ProductId = COALESCE(@sku, Products.ProductId)
						AND Products.LastModifiedDate >= @lastModifiedDate
						AND EcommerceWebsites.EcommerceWebsiteId = @website
					FOR XML PATH(''), 
				TYPE).value('.','NVARCHAR(max)'), 1, 1, '' 
			)), '')

	OPTION (OPTIMIZE FOR (@sku UNKNOWN, @lastModifiedDate UNKNOWN, @website UNKNOWN, @results UNKNOWN))

	SELECT @results = REPLACE(REPLACE(REPLACE('{"Products":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), '')

	SELECT @results

END
GO
