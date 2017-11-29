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
-- Description:	Stored procedure for SELECTing customer delivery addresses for the WinMan REST API in JSON format.
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
		AND p.[name] = 'wsp_RestApiDeliveryAddressesSelectJSON'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiDeliveryAddressesSelectJSON AS PRINT ''dbo.wsp_RestApiDeliveryAddressesSelectJSON''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiDeliveryAddressesSelectJSON]
	@guid nvarchar(36),
	@website nvarchar(100),
	@seconds bigint = 315360000,
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiDeliveryAddressesSelectJSON') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiDeliveryAddressesSelectJSON
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

	SELECT @results = COALESCE(
		(SELECT
			STUFF( 
				(SELECT 
					',{
						"Guid":"' + CAST(cust.CustomerGUID AS nvarchar(36)) + '",
						"DeliveryAddresses":' +
							(SELECT '[' + 
								STUFF(
									(SELECT ',{
										"DeliveryName":"' + REPLACE(del.DeliveryName, '"','&#34;') + '",
										"Address":"' + REPLACE(REPLACE(REPLACE(del.[Address], CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
										"City":"' + REPLACE(del.City, '"','&#34;') + '",
										"Region":"' + REPLACE(del.Region, '"','&#34;') + '",
										"PostalCode":"' + REPLACE(del.PostalCode, '"','&#34;') + '",
										"Country":"' + ctry.ISO3Chars + '",
										"PhoneNumber":"' + REPLACE(del.PhoneNumber, '"','&#34;') + '",
										"LastName":"' + REPLACE(del.LastName, '"','&#34;') + '",
										"FirstName":"' + REPLACE(del.FirstName, '"','&#34;') + '",
										"Title":"' + REPLACE(del.Title, '"','&#34;') + '",
										"Comments":"' + REPLACE(REPLACE(REPLACE(del.Comments, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
										"EmailAddress":"' + REPLACE(del.EmailAddress, '"','&#34;') + '",
										"Notes":"' + REPLACE(REPLACE(REPLACE(del.Notes, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
										"SalesTaxExempt":' + CASE WHEN del.SalesTaxExempt = 1 THEN 'true' ELSE 'false' END + ',
										"IsDefault":' + CASE WHEN cust.DeliveryAddress = del.DeliveryAddress THEN 'true' ELSE 'false' END																	
									+ '}'
									FROM
										DeliveryAddresses del
										INNER JOIN Countries AS ctry ON ctry.Country = del.Country
									WHERE
										del.Customer = cust.Customer
										AND del.DistinctAddress <> 0
										AND (del.LastModifiedDate >= @lastModifiedDate)
									FOR XML PATH(''), TYPE)
								.value('.','nvarchar(max)'), 1, 1, '')
							+ ']')
						+ '
					}' 
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
				FOR XML PATH(''), 
			TYPE).value('.','nvarchar(max)'), 1, 1, '' 
		)), '');

	SELECT @results = REPLACE(REPLACE(REPLACE('{"CustomerDeliveryAddresses":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), '');

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
