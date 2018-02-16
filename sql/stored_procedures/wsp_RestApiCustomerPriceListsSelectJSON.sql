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
-- Description:	Stored procedure for SELECTing customer price lists for the WinMan REST API in JSON format.
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
		AND p.[name] = 'wsp_RestApiCustomerPriceListsSelectJSON'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiCustomerPriceListsSelectJSON AS PRINT ''dbo.wsp_RestApiCustomerPriceListsSelectJSON''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiCustomerPriceListsSelectJSON]
	@guid nvarchar(36),
	@website nvarchar(100),
	@seconds bigint = 315360000,
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCustomerPriceListsSelectJSON') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiCustomerPriceListsSelectJSON
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

	DECLARE	@lastModifiedDate datetime;

	SET @lastModifiedDate = (SELECT DATEADD(second,-@seconds,GETDATE()));

	SELECT @results = COALESCE(
		(SELECT
			STUFF( 
				(SELECT ',{
						"Guid":"' + CAST(cust.CustomerGUID AS nvarchar(36)) + '",
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
											"Quantity":' + CAST(Quantity AS nvarchar(20)) + ',
											"EffectiveDateStart":"' + CONVERT(nvarchar(50), EffectiveDateStart, 126) + '",
											"EffectiveDateEnd":"' + CONVERT(nvarchar(50), EffectiveDateEnd, 126) + '",
											"PriceValue":' + CAST(PriceValue AS nvarchar(20)) + '
											}' FROM Prices
												INNER JOIN Products ON Products.Product = Prices.Product 
											WHERE Prices.PriceList = PriceLists.PriceList FOR XML PATH(''), TYPE)											
											.value('.','nvarchar(max)'), 1, 1, '') + ']')
											 + '
										}' FROM PriceLists
										WHERE cust.PriceList = PriceLists.PriceList
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
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
					GROUP BY
						cust.CustomerGUID,
						cust.PriceList
					FOR XML PATH(''), 
			TYPE).value('.','nvarchar(max)'), 1, 1, '' 
			)), '');

	SELECT @results = REPLACE(REPLACE(REPLACE(REPLACE('{"CustomerPriceLists":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), ''), '\', '\\');

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
