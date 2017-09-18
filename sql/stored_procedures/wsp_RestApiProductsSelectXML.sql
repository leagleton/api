SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing products for the WinMan REST API in XML format.
-- =============================================

CREATE PROCEDURE dbo.wsp_RestApiProductsSelectXML
	@sku NVARCHAR(100) = NULL,
	@seconds BIGINT = 315360000,
	@website NVARCHAR(100),
	@results NVARCHAR(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiProductsSelectXML') = 1 
	BEGIN
		EXEC dbo.bsp_RestApiProductsSelectXML
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
	
	SELECT @results = 
		(SELECT
			Products.ProductGUID AS [Guid],
			Products.ProductId AS Sku,
			Products.ProductDescription AS [Name],
			Products.StandardPrice,
			Products.WebPrice,
			Products.WebRRP AS Rrp,
			Products.SurCharge AS Surcharge,
			(SELECT
				ProductPricingClassificationId,
				ProductPricingClassificationDescription
			FROM
				ProductPricingClassifications
			WHERE
				ProductPricingClassifications.ProductPricingClassification = Products.ProductPricingClassification
			FOR XML PATH(''), TYPE) AS ProductPricingClassification,
			'' AS ProductPricingClassification,
			Products.WebDescription AS LongDescription,
			Products.WebSummary AS ShortDescription,
			CASE WHEN Products.Taxable = 1 THEN 'true' ELSE 'false' END AS Taxable,
			(SELECT
				TaxCodeId,
				TaxCodeDescription,
				TaxRate
			FROM
				TaxCodes
			WHERE
				Products.Taxcode = TaxCodes.TaxCode
			FOR XML PATH(''), TYPE) AS TaxCode,
			'' AS TaxCode,
			(SELECT
				DiscountId,
				DiscountDescription,
				DiscountPercentage,
				(SELECT
					DiscountBreakId,
					TriggerType,
					TriggerValue,
					DiscountBreakType,
					DiscountBreakValue					
				FROM
					DiscountBreaks
				WHERE
					DiscountBreaks.Discount = Discounts.Discount
				FOR XML PATH('DiscountBreak'), TYPE) AS DiscountBreaks,
				'' AS DiscountBreaks
			FROM
				Discounts
			WHERE
				Products.SalesDiscount = Discounts.Discount
			FOR XML PATH(''), TYPE) AS SalesDiscount,
			'' AS SalesDiscount,
			(SELECT
				PriceListId,
				PriceListDescription,
				(SELECT
					Quantity,
					EffectiveDateStart,
					EffectiveDateEnd,
					PriceValue
				FROM 
					Prices
				WHERE 
					Prices.PriceList = pl.PriceList
					AND Prices.Product = Products.Product
				FOR XML PATH('ProductPrice'), TYPE) AS ProductPrices
			FROM
				PriceLists pl			
			FOR XML PATH('ProductPriceList'), TYPE) AS ProductPriceLists,
			'' AS ProductPriceLists,
			Products.TitleTag AS MetaTitle,
			Products.KeywordsTag AS MetaKeywords,
			Products.DescriptionTag AS MetaDescription,
			Products.PackSize,
			Products.[Length],
			Products.Width,
			Products.Height,
			Products.[Weight],
			(SELECT
				UnitOfMeasureId AS MeasureName,
				UnitOfMeasureDescription AS MeasureDescription,
				UnitOfMeasurePrintText AS MeasurePrintText
			FROM
				UnitsOfMeasure
			WHERE
				Products.UnitOfMeasure = UnitsOfMeasure.UnitOfMeasure
			FOR XML PATH(''), TYPE) AS UnitOfMeasure,
			Products.DimensionQuantity,
			CASE WHEN Products.ConfiguratorOption = 1 THEN 'true' ELSE 'false' END AS ConfigurableProduct,
			(SELECT
				ManufacturerId,
				ManufacturerDescription,
				COALESCE(ManufacturerLogo, '') AS ManufacturerLogo
			FROM
				Manufacturers
			WHERE
				Products.Manufacturer = Manufacturers.Manufacturer
			FOR XML PATH(''), TYPE) AS Brand,
			'' AS Brand,
			Products.Barcode,
			Products.CrossReference,
			Products.SalesLeadTime,
			Products.RoHS,
			Products.Notes,
			Products.PromptText,
			(SELECT
				ClassificationId,
				ClassificationDescription
			FROM
				Classifications
			WHERE
				Products.Classification = Classifications.Classification
			FOR XML PATH(''), TYPE) AS Classification,
			(SELECT
				P.ProductId AS AlternativeProductSku,
				P.ProductDescription AS AlternativeProductName
			FROM
				Products P
			INNER JOIN AlternativeParts A ON A.AlternativeProduct = P.Product
			WHERE
				Products.Product = A.Product
			FOR XML PATH('AlternativeProduct'), TYPE) AS AlternativeProducts,
			'' AS AlternativeProducts,
			(SELECT
				P.ProductId AS RelatedProductSku,
				P.ProductDescription AS RelatedProductName
			FROM
				Products P
			INNER JOIN ProductRelations R ON R.RelatedProduct = P.Product
			WHERE
				Products.Product = R.Product
			FOR XML PATH('RelatedProduct'), TYPE) AS RelatedProducts,
			'' AS RelatedProducts,
			(SELECT
				SP.ProductId AS SupersedingProductSku,
				SP.ProductDescription AS SupersedingProductName
			FROM
				Products SP
			INNER JOIN Products PP ON SP.Product = PP.SuperceededBy
			WHERE
				PP.Product = Products.Product
			FOR XML PATH(''), TYPE) AS SupersedingProduct,
			'' AS SupersedingProduct,
			(SELECT
				WarrantyId,
				WarrantyDescription,
				WarrantyUnit,
				WarrantyPeriod
			FROM
				Warranties w
				INNER JOIN ProductWarranties pw ON pw.Warranty = w.Warranty
			WHERE
				pw.Product = Products.Product
			FOR XML PATH('Warranty'), TYPE) AS Warranties,
			'' AS Warranties,
			(SELECT
				ProductStatusId AS ProductStatusId,
				DisplayName AS ProductStatusDisplayName
			FROM
				ProductStatuses
			WHERE
				Products.ProductStatus = ProductStatuses.ProductStatus
			FOR XML PATH(''), TYPE) AS ProductStatus,
			'' AS ProductStatus,
			Products.LastModifiedDate,		
			(SELECT dbo.wfn_RestApiGetCustomColumnsXML(Products.Product)) AS CustomColumns,
			'' AS CustomColumns
		FROM
			Products
			INNER JOIN ProductEcommerceWebsites ON Products.Product = ProductEcommerceWebsites.Product
			INNER JOIN EcommerceWebsites ON EcommerceWebsites.EcommerceWebsite = ProductEcommerceWebsites.EcommerceWebsite
		WHERE
			Products.ProductId = COALESCE(@sku, Products.ProductId)
			AND Products.LastModifiedDate >= @lastModifiedDate
			AND EcommerceWebsites.EcommerceWebsiteId = @website
		FOR XML PATH('Product'))

		OPTION (OPTIMIZE FOR (@sku UNKNOWN, @lastModifiedDate UNKNOWN, @website UNKNOWN, @results UNKNOWN))

	SELECT @results = CONCAT('<Products>', @results, '</Products>')

	SELECT @results

END
GO
