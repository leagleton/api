SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing product categories for the WinMan REST API in XML format.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiProductCategoriesSelectXML]
	@guid UNIQUEIDENTIFIER = NULL,
	@website NVARCHAR(100),
	@seconds BIGINT = 315360000,
	@results NVARCHAR(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiProductCategoriesSelectXML') = 1 
	BEGIN
		EXEC dbo.bsp_RestApiProductCategoriesSelectXML
			@guid = @guid,
			@website = @website,
			@seconds = @seconds,
			@results = @results
		RETURN	
	END

	SET NOCOUNT ON;

	DECLARE 
		@lastModifiedDate DATETIME

	SET @lastModifiedDate = (SELECT DATEADD(second,-@seconds,GETDATE()));

	WITH ProductCategoryTree ( 
		CategoryGUID,
		ProductCategory,
		CategoryPath,
		CategoryName,
		SortOrder,
		CategoryImage,
		MetaTitle,
		MetaDescription,
		MetaKeywords,
		[Level],
		LastModifiedDate)
	AS (
		SELECT 
			ProductCategoryGUID AS CategoryGUID,
			ProductCategory,
			FullPath AS CategoryPath,
			ProductCategoryDescription AS CategoryName,
			ROW_NUMBER() OVER (ORDER BY SortOrder, ProductCategoryDescription) AS SortOrder,
			CategoryImage,
			TitleTag AS MetaTitle,
			DescriptionTag AS MetaDescription,
			KeywordsTag AS MetaKeywords,
			1 AS Level,
			LastModifiedDate
		FROM
			ProductCategories
		WHERE
			IsActive = 1
			AND ParentCategory IS NULL

		UNION ALL

		SELECT 
			ProductCategories.ProductCategoryGUID AS CategoryGUID,
			ProductCategories.ProductCategory,
			ProductCategories.FullPath AS CategoryPath,
			ProductCategories.ProductCategoryDescription AS CategoryName,
			ROW_NUMBER() OVER (ORDER BY ProductCategories.SortOrder, ProductCategories.ProductCategoryDescription) AS SortOrder,
			ProductCategories.CategoryImage,
			ProductCategories.TitleTag AS MetaTitle,
			ProductCategories.DescriptionTag AS MetaDescription,
			ProductCategories.KeywordsTag AS MetaKeywords,
			ProductCategoryTree.Level + 1 AS Level,
			ProductCategories.LastModifiedDate
		FROM
			ProductCategories
			INNER JOIN ProductCategoryTree ON ProductCategories.ParentCategory = ProductCategoryTree.ProductCategory
		WHERE
			IsActive = 1
	)

	SELECT @results = 
		(SELECT 
			CategoryGUID,
			CategoryPath,
			CategoryName,
			ProductCategoryTree.SortOrder,
			ProductCategoryTree.CategoryImage,
			'' AS CategoryImage,
			MetaTitle,
			MetaDescription,
			MetaKeywords,
			[Level],
			(SELECT 
				P.ProductId AS SKU 
			FROM
				ProductProductCategories C
				INNER JOIN Products P ON C.Product = P.Product
				INNER JOIN ProductEcommerceWebsites PEW ON PEW.Product = P.Product
				INNER JOIN EcommerceWebsites EW ON EW.EcommerceWebsite = PEW.EcommerceWebsite
			WHERE 
				C.ProductCategory = ProductCategoryTree.ProductCategory 
				AND EW.EcommerceWebsiteId = @website
			FOR XML PATH('Product'), TYPE) AS Products
		FROM
			ProductCategoryTree
		WHERE
			CategoryGUID = COALESCE(@guid, CategoryGUID)
			AND CategoryPath IS NOT NULL
			AND ProductCategoryTree.LastModifiedDate >= @lastModifiedDate
			AND EXISTS (SELECT 
							P.ProductId AS SKU 
						FROM
							ProductProductCategories C
							INNER JOIN Products P ON C.Product = P.Product
							INNER JOIN ProductEcommerceWebsites PEW ON PEW.Product = P.Product
							INNER JOIN EcommerceWebsites EW ON EW.EcommerceWebsite = PEW.EcommerceWebsite
						WHERE 
							C.ProductCategory = ProductCategoryTree.ProductCategory 
							AND EW.EcommerceWebsiteId = @website)
		FOR XML PATH('ProductCategory'))

	OPTION (OPTIMIZE FOR (@guid UNKNOWN, @website UNKNOWN, @lastModifiedDate UNKNOWN, @results UNKNOWN))	

	SELECT @results = CONCAT('<ProductCategories>', @results, '</ProductCategories>')

	SELECT @results

END
GO
