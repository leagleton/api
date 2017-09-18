SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing customer price lists for the WinMan REST API in XML format.
-- =============================================

CREATE PROCEDURE dbo.wsp_RestApiCustomerPriceListsSelectXML
	@guid NVARCHAR(36),
	@website NVARCHAR(100),
	@seconds BIGINT = 315360000,
	@results NVARCHAR(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCustomerPriceListsSelectXML') = 1 
	BEGIN
		EXEC dbo.bsp_RestApiCustomerPriceListsSelectXML
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

	SELECT @results =
		(SELECT
			cust.CustomerGUID AS [Guid],
			(SELECT
				PriceListId,
				PriceListDescription,
				(SELECT 
					ProductId AS ProductSku,
					Quantity,
					EffectiveDateStart,
					EffectiveDateEnd,
					PriceValue
				FROM 
					Prices
					INNER JOIN Products ON Products.Product = Prices.Product 
				WHERE 
					Prices.PriceList = PriceLists.PriceList 
				FOR XML PATH('CustomerPrice'), TYPE) AS CustomerPrices
			FROM
				PriceLists
			WHERE
				cust.PriceList = PriceLists.PriceList
			FOR XML PATH(''), TYPE) AS PriceList,
			'' AS PriceList
		FROM CRMContacts AS ctct
			INNER JOIN CRMCompanies AS comp ON comp.CRMCompany = ctct.CRMCompany
			INNER JOIN Customers cust ON cust.Customer = comp.Customer
			LEFT JOIN Countries AS ctry ON cust.Country = ctry.Country
		WHERE cust.CustomerGUID = @guid
			AND ctct.Active = 1
			AND ctct.PortalUserName <> ''
			AND ctct.PortalUserName IS NOT NULL
			AND ((cust.LastModifiedDate >= @lastModifiedDate) OR (ctct.LastModifiedDate >= @lastModifiedDate))
			AND ((cust.[Site] IS NULL) OR (cust.[Site] IN 
				(SELECT
					Site
				FROM
					EcommerceWebsiteSites EWS
					INNER JOIN EcommerceWebsites EW ON EW.EcommerceWebsite = EWS.EcommerceWebsite
				WHERE
					EcommerceWebsiteId = @website)
			))
		FOR XML PATH('CustomerPriceList'))

	OPTION (OPTIMIZE FOR (@guid UNKNOWN, @website UNKNOWN, @lastModifiedDate UNKNOWN, @results UNKNOWN))

	IF (@results IS NOT NULL)
		SELECT @results = CONCAT('<CustomerPriceLists>', @results, '</CustomerPriceLists>')

	SELECT @results

END
GO