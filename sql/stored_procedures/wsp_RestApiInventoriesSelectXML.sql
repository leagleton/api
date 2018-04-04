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
-- Description:	Stored procedure for SELECTing product stock levels for the WinMan REST API in XML format.
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
		AND p.[name] = 'wsp_RestApiInventoriesSelectXML'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiInventoriesSelectXML AS PRINT ''wsp_RestApiInventoriesSelectXML''');
	END;
GO

-- 03Apr18 LAE Added total row count.

ALTER PROCEDURE [dbo].[wsp_RestApiInventoriesSelectXML]
	@pageNumber int = 1,
	@pageSize int = 10,
	@sku nvarchar(100) = null,
	@website nvarchar(100),
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiInventoriesSelectXML') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiInventoriesSelectXML
				@pageNumber = @pageNumber,
				@pageSize = @pageSize,			
				@sku = @sku,
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

	-- 03Apr18 LAE
	DECLARE @total int;			

	WITH CTE AS
	(
		SELECT
			ROW_NUMBER() OVER (ORDER BY p.Product) AS rowNumber,
			p.ProductId,
			p.Product
		FROM
			Products p
		WHERE
			p.ProductId = COALESCE(@sku, p.ProductId)
			AND EXISTS (SELECT
							pew.Product
						FROM
							ProductEcommerceWebsites pew
							INNER JOIN EcommerceWebsites ew ON pew.EcommerceWebsite = ew.EcommerceWebsite
						WHERE
							pew.Product = p.Product
							AND ew.EcommerceWebsiteId = @website)
	)
	
	SELECT @results = 
		CONVERT(nvarchar(max), (SELECT
			p.Product,
			(SELECT
				COALESCE(dbo.wfn_RestApiGetSiteName(i.[Site]), '') AS [Site],
				dbo.wfn_RestApiGetStockLevelsXML(p.Product, i.[Site])
			FROM
				Inventory i
			WHERE
				i.Product = p.Product
				AND EXISTS (SELECT 
								ews.[Site]
							FROM 
								EcommerceWebsiteSites ews 
								INNER JOIN EcommerceWebsites ew ON ews.EcommerceWebsite = ew.EcommerceWebsite 
							WHERE 
								ews.[Site] = i.[Site]
								AND ew.EcommerceWebsiteId = COALESCE(@website, ew.EcommerceWebsiteId))
			GROUP BY
				i.[Site]
			FOR XML PATH('ProductInventory'), TYPE) AS ProductInventories,
			'' AS ProductInventories
		FROM
			CTE AS p
		WHERE
			(rowNumber > @pageSize * (@pageNumber - 1))
			AND (rowNumber <= @pageSize * @pageNumber)
		ORDER BY
			rowNumber
		-- 03Apr18 LAE
		--FOR XML PATH('Inventory'), TYPE));
		FOR XML PATH('Inventory'), TYPE)), @total = (SELECT COUNT(*) FROM CTE);		

	IF @results IS NOT NULL AND @results <> ''
		BEGIN
			SELECT @results = '<Inventories>' + @results + '</Inventories>';
		END;
	ELSE
		BEGIN
			SELECT @results = '<Inventories/>';
		END;

	-- 03Apr18 LAE
	--SELECT @results AS Results;
	SELECT @results AS Results, @total AS TotalCount;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
