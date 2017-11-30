SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 29 November 2017
-- Description:	Stored procedure for SELECTing customer delivery addresses for the WinMan REST API in XML format.
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
		AND p.[name] = 'wsp_RestApiDeliveryAddressesSelectXML'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiDeliveryAddressesSelectXML AS PRINT ''dbo.wsp_RestApiDeliveryAddressesSelectXML''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiDeliveryAddressesSelectXML]
	@guid nvarchar(36),
	@website nvarchar(100),
	@seconds bigint = 315360000,
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiDeliveryAddressesSelectXML') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiDeliveryAddressesSelectXML
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

	DECLARE	@lastModifiedDate datetime;

	SET @lastModifiedDate = (SELECT DATEADD(second,-@seconds,GETDATE()));

	SELECT @results = CONVERT(nvarchar(max),
		(SELECT 
            CustomerGUID AS [Guid],
			(SELECT 
				del.DeliveryName,
                del.[Address],
                del.City,
                del.Region,
                del.PostalCode,
                ctry.ISO3Chars AS Country,
                del.PhoneNumber,
                del.LastName,
                del.FirstName,
                del.Title,
                del.Comments,
                del.EmailAddress,
                del.Notes,
                CASE WHEN del.SalesTaxExempt = 1 THEN 'true' ELSE 'false' END AS SalesTaxExempt,
                CASE WHEN cust.DeliveryAddress = del.DeliveryAddress THEN 'true' ELSE 'false' END AS IsDefault
		    FROM
			    DeliveryAddresses del
				INNER JOIN Countries AS ctry ON ctry.Country = del.Country
			WHERE
				del.Customer = cust.Customer 
				AND del.DistinctAddress <> 0
				AND (del.LastModifiedDate >= @lastModifiedDate)
			FOR XML PATH('DeliveryAddress'), TYPE) AS DeliveryAddresses            
		FROM
			CRMContacts AS ctct
			INNER JOIN CRMCompanies AS comp ON comp.CRMCompany = ctct.CRMCompany
			INNER JOIN Customers cust ON cust.Customer = comp.Customer
		WHERE cust.CustomerGUID = COALESCE(@guid, cust.CustomerGUID)
			AND ctct.Active = 1
			AND ctct.PortalUserName <> ''
			AND ((cust.[Site] IS NULL) OR (cust.[Site] IN 
				(SELECT
					[Site]
				FROM
					EcommerceWebsiteSites ews
					INNER JOIN EcommerceWebsites ew ON ew.EcommerceWebsite = ews.EcommerceWebsite
				WHERE
					EcommerceWebsiteId = @website)
			))
		GROUP BY
			cust.CustomerGUID,
			cust.Customer,
			cust.DeliveryAddress
        FOR XML PATH('CustomerDeliveryAddress'), TYPE));

	IF @results IS NOT NULL AND @results <> ''
		BEGIN
			SELECT @results = '<CustomerDeliveryAddresses>' + @results + '</CustomerDeliveryAddresses>';
		END;
	ELSE
		BEGIN
			SELECT @results = '<CustomerDeliveryAddresses/>';
		END;

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
