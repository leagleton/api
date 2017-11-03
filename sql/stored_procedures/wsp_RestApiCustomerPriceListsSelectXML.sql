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
-- Description:	Stored procedure for SELECTing customer price lists for the WinMan REST API in XML format.
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
		AND p.[name] = 'wsp_RestApiCustomerPriceListsSelectXML'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiCustomerPriceListsSelectXML AS PRINT ''dbo.wsp_RestApiCustomerPriceListsSelectXML''');
	END;
GO

ALTER PROCEDURE dbo.wsp_RestApiCustomerPriceListsSelectXML
	@guid nvarchar(36),
	@website nvarchar(100),
	@seconds bigint = 315360000,
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCustomerPriceListsSelectXML') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiCustomerPriceListsSelectXML
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
			SELECT 'ERROR: Scope not enabled for specified website.' AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	DECLARE @lastModifiedDate datetime;

	SET @lastModifiedDate = (SELECT DATEADD(second,-@seconds,GETDATE()));

	SELECT @results =
		CONVERT(nvarchar(max), (SELECT
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
		GROUP BY
			cust.CustomerGUID,
			cust.PriceList			
		FOR XML PATH('CustomerPriceList'), TYPE));

	--OPTION (OPTIMIZE FOR (@guid UNKNOWN, @website UNKNOWN, @lastModifiedDate UNKNOWN));

	IF @results IS NOT NULL AND @results <> ''
		BEGIN
			SELECT @results = '<CustomerPriceLists>' + @results + '</CustomerPriceLists>';
		END;
	ELSE
		BEGIN
			SELECT @results = '<CustomerPriceLists/>';
		END;

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
