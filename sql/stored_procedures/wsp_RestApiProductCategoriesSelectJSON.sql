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
-- Description:	Stored procedure for SELECTing product categories for the WinMan REST API in JSON format.
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
		AND p.[name] = 'wsp_RestApiProductCategoriesSelectJSON'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiProductCategoriesSelectJSON AS PRINT ''wsp_RestApiProductCategoriesSelectJSON''');
	END;
GO

-- 03Apr18 LAE Added total row count.

ALTER PROCEDURE [dbo].[wsp_RestApiProductCategoriesSelectJSON]
	@pageNumber int = 1,
	@pageSize int = 10,
	@guid nvarchar(36) = null,
	@website nvarchar(100),
	@seconds bigint = 315360000,
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiProductCategoriesSelectJSON') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiProductCategoriesSelectJSON
				@pageNumber = @pageNumber,
				@pageSize = @pageSize,			
				@guid = @guid,
				@website = @website,
				@seconds = @seconds,
				@scope = @scope,
				@results = @results;
			RETURN;	
		END;

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	DECLARE @lastModifiedDate datetime;

	SET @lastModifiedDate = (SELECT DATEADD(second,-@seconds,GETDATE()));

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
		
	-- 03Apr18 LAE
	DECLARE @total int;			

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
	),
	CTE AS
	(
		SELECT
			ROW_NUMBER() OVER (ORDER BY ProductCategory) AS rowNumber,
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
			LastModifiedDate
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
	)

	SELECT @results = COALESCE(
        (SELECT
            STUFF(
				(SELECT ',{
					"CategoryGuid":"' + CAST(CategoryGUID AS nvarchar(36)) + '",
					"CategoryPath":"' + REPLACE(REPLACE(REPLACE(CategoryPath, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
					"CategoryName":"' + REPLACE(REPLACE(REPLACE(CategoryName, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
					"SortOrder":' + CAST(ProductCategoryTree.SortOrder AS nvarchar(20)) + ',
					"CategoryImage":"' + dbo.wfn_RestApiGetImageString(CategoryImage) + '",
					"MetaTitle":"' + REPLACE(REPLACE(REPLACE(MetaTitle, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
					"MetaDescription":"' + REPLACE(REPLACE(REPLACE(MetaDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
					"MetaKeywords":"' + REPLACE(REPLACE(REPLACE(MetaKeywords, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
					"Level":' + CAST([Level] AS nvarchar(10)) + ',
					"Products":' +
						COALESCE(
							(SELECT '[' +
								STUFF(
									(SELECT ',{
										"ProductSku":"' + REPLACE(P.ProductId, '"', '&#34;') + '"
									}' FROM
										ProductProductCategories C
										INNER JOIN Products P ON C.Product = P.Product
										INNER JOIN ProductEcommerceWebsites PEW ON PEW.Product = P.Product
										INNER JOIN EcommerceWebsites EW ON EW.EcommerceWebsite = PEW.EcommerceWebsite
									WHERE
										C.ProductCategory = ProductCategoryTree.ProductCategory
										AND EW.EcommerceWebsiteId = @website
									FOR XML PATH(''),
									TYPE).value('.','nvarchar(max)'), 1, 1, '')
								+ ']'),
							'[]')
						+ '
				}' FROM
					CTE AS ProductCategoryTree
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

	SELECT @results = REPLACE(REPLACE(REPLACE(REPLACE('{"ProductCategories":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), ''), '\', '\\');

	-- 03Apr18 LAE
	--SELECT @results AS Results;
	SELECT @results AS Results, @total AS TotalCount;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
