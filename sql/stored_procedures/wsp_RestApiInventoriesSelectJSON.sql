SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing product stock levels for the WinMan REST API in JSON format.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiInventoriesSelectJSON]
	@sku NVARCHAR(100) = NULL,
	@website NVARCHAR(100),
	@results NVARCHAR(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiInventoriesSelectJSON') = 1 
	BEGIN
		EXEC dbo.bsp_RestApiInventoriesSelectJSON
			@sku = @sku,
			@website = @website,
			@results = @results
		RETURN	
	END

	SET NOCOUNT ON;
	
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
										TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
								+ ']'),
							'[]')
						 + '
		}' FROM
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
					FOR XML PATH(''), 
				TYPE).value('.','NVARCHAR(max)'), 1, 1, '' 
			)), '')

	OPTION (OPTIMIZE FOR (@sku UNKNOWN, @website UNKNOWN, @results UNKNOWN))		

	SELECT @results = REPLACE(REPLACE(REPLACE('{"Inventories":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), '')

	SELECT @results

END
GO
