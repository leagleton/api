SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing customer price lists for the WinMan REST API in JSON format.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiCustomerPriceListsSelectJSON]
	@guid NVARCHAR(36),
	@website NVARCHAR(100),
	@seconds BIGINT = 315360000,
	@results NVARCHAR(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCustomerPriceListsSelectJSON') = 1 
	BEGIN
		EXEC dbo.bsp_RestApiCustomerPriceListsSelectJSON
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

	SELECT @results = COALESCE(
		(SELECT
			STUFF( 
				(SELECT ',{
						"Guid":"' + CAST(cust.CustomerGUID AS NVARCHAR(36)) + '",
                        "PriceList":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"PriceListId":"' + PriceListId + '",
											"PriceListDescription":"' + PriceListDescription + '",
											"CustomerPrices":' + (SELECT '[' + STUFF(
											(SELECT ',{
											"ProductSku":"' + ProductId + '",
											"Quantity":' + CAST(Quantity AS NVARCHAR(20)) + ',
											"EffectiveDateStart":"' + CONVERT(NVARCHAR(50), EffectiveDateStart, 126) + '",
											"EffectiveDateEnd":"' + CONVERT(NVARCHAR(50), EffectiveDateEnd, 126) + '",
											"PriceValue":' + CAST(PriceValue AS NVARCHAR(20)) + '
											}' FROM Prices
												INNER JOIN Products ON Products.Product = Prices.Product 
											WHERE Prices.PriceList = PriceLists.PriceList FOR XML PATH(''), TYPE)											
											.value('.','NVARCHAR(max)'), 1, 1, '') + ']')
											 + '
										}' FROM PriceLists
										WHERE cust.PriceList = PriceLists.PriceList
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
								),
							'{}')
						 + '						
					}' 
					FROM CRMContacts AS ctct
						INNER JOIN CRMCompanies AS comp ON comp.CRMCompany = ctct.CRMCompany
						INNER JOIN Customers cust ON cust.Customer = comp.Customer
						LEFT JOIN Countries AS ctry ON cust.Country = ctry.Country
					WHERE cust.CustomerGUID = COALESCE(@guid, cust.CustomerGUID)
						AND ctct.Active = 1
						AND ctct.PortalUserName <> ''
						AND ((cust.LastModifiedDate >= @lastModifiedDate) OR (ctct.LastModifiedDate >= @lastModifiedDate))
						AND ((cust.Site IS NULL) OR (cust.Site IN 
							(SELECT
								Site
							FROM
								EcommerceWebsiteSites EWS
								INNER JOIN EcommerceWebsites EW ON EW.EcommerceWebsite = EWS.EcommerceWebsite
							WHERE
								EcommerceWebsiteId = @website)
						))
					FOR XML PATH(''), 
			TYPE).value('.','NVARCHAR(max)'), 1, 1, '' 
			)), '')

	OPTION (OPTIMIZE FOR (@guid UNKNOWN, @website UNKNOWN, @lastModifiedDate UNKNOWN, @results UNKNOWN))

	SELECT @results = REPLACE(REPLACE(REPLACE('{"CustomerPriceLists":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), '')

	SELECT @results

END
GO
