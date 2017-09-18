SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing product stock levels for the WinMan REST API in XML format.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiInventoriesSelectXML]
	@sku NVARCHAR(100) = NULL,
	@website NVARCHAR(100),
	@results NVARCHAR(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiInventoriesSelectXML') = 1 
	BEGIN
		EXEC dbo.bsp_RestApiInventoriesSelectXML
			@sku = @sku,
			@website = @website,
			@results = @results
		RETURN	
	END

	SET NOCOUNT ON;
	
	SELECT @results = 
		(SELECT
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
		FOR XML PATH('Inventory'))

	OPTION (OPTIMIZE FOR (@sku UNKNOWN, @website UNKNOWN, @results UNKNOWN))	

	SELECT @results = CONCAT('<Inventories>', @results, '</Inventories>')

	SELECT @results

END
GO
