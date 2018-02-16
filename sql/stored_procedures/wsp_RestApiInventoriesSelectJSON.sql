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
-- Description:	Stored procedure for SELECTing product stock levels for the WinMan REST API in JSON format.
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
		AND p.[name] = 'wsp_RestApiInventoriesSelectJSON'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiInventoriesSelectJSON AS PRINT ''wsp_RestApiInventoriesSelectJSON''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiInventoriesSelectJSON]
	@pageNumber int = 1,
	@pageSize int = 10,
	@sku nvarchar(100) = null,
	@website nvarchar(100),
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiInventoriesSelectJSON') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiInventoriesSelectJSON
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
	
	SELECT @results = COALESCE(
		(SELECT
			STUFF(
				(SELECT ',{
					"ProductSku":"' + p.ProductId + '",
					"ProductInventories":' +
						COALESCE(
							(SELECT '[' +
								STUFF(
									(SELECT ',{
										"Site":"' + COALESCE(dbo.wfn_RestApiGetSiteName(i.[Site]), '') + '",
										' + dbo.wfn_RestApiGetStockLevelsJSON(p.Product, i.[Site]) + '
									}' FROM
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
									FOR XML PATH(''),
									TYPE).value('.','nvarchar(max)'), 1, 1, '')
								+ ']'),
							'[]')
						+ '
				}' FROM 
					CTE AS p
				WHERE
					(rowNumber > @pageSize * (@pageNumber - 1))
					AND (rowNumber <= @pageSize * @pageNumber)
				ORDER BY
					rowNumber
				FOR XML PATH(''),
				TYPE).value('.','nvarchar(max)'), 1, 1, ''
		)), '');	

	SELECT @results = REPLACE(REPLACE(REPLACE(REPLACE('{"Inventories":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), ''), '\', '\\');

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
