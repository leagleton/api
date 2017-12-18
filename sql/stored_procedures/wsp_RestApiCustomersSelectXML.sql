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
-- Description:	Stored procedure for SELECTing customers for the WinMan REST API in XML format.
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
		AND p.[name] = 'wsp_RestApiCustomersSelectXML'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiCustomersSelectXML AS PRINT ''wsp_RestApiCustomersSelectXML''');
	END;
GO

ALTER PROCEDURE dbo.wsp_RestApiCustomersSelectXML
	@pageNumber int = 1,
	@pageSize int = 10,
	@guid nvarchar(36) = null,
	@website nvarchar(100),
	@seconds bigint = 315360000,
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCustomersSelectXML') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiCustomersSelectXML
				@pageNumber = @pageNumber,
				@pageSize = @pageSize,			
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

	WITH CTE AS
	(
		SELECT
			ROW_NUMBER() OVER (ORDER BY cust.Customer) AS rowNumber,
			cust.Customer,
			cust.CustomerName,
			cust.CustomerGUID,
			cust.[Site],
			cust.CustomerId,
			cust.Branch,
			cust.[Address],
			cust.City,
			cust.Region,
			cust.PostalCode,
			ctry.ISO3Chars,
			cust.PhoneNumber,
			cust.FaxNumber,
			cust.EmailAddress,
			cust.WebSite,
			cust.CustomerAlias,
			cust.PreferredCulture,
			cust.TaxNumber,
			cust.Currency,
			cust.CreditTerms,
			cust.Discount,
			cust.TaxCode,
			cust.TaxCodeSecondary,
			cust.Industry,
			cust.TheirIdentifier,
			cust.CustomerPricingClassification,
			cust.Notes,
			CAST(cust.PromptText AS nvarchar(max)) AS PromptText
		FROM Customers cust
			INNER JOIN Countries AS ctry ON cust.Country = ctry.Country
			INNER JOIN CRMCompanies comp ON comp.Customer = cust.Customer
			INNER JOIN CRMContacts ctct ON ctct.CRMCompany = comp.CRMCompany
		WHERE cust.CustomerGUID = COALESCE(@guid, cust.CustomerGUID)
			AND (cust.LastModifiedDate >= @lastModifiedDate)
			AND ((cust.[Site] IS NULL) OR (cust.[Site] IN 
				(SELECT
					[Site]
				FROM
					EcommerceWebsiteSites EWS
					INNER JOIN EcommerceWebsites EW ON EW.EcommerceWebsite = EWS.EcommerceWebsite
				WHERE
					EcommerceWebsiteId = @website)
			))	
			AND ctct.PortalUserName <> ''
			AND ctct.PortalUserName IS NOT NULL
		GROUP BY
			cust.Customer,
			cust.CustomerName,
			cust.CustomerGUID,
			cust.[Site],
			cust.CustomerId,
			cust.Branch,
			cust.[Address],
			cust.City,
			cust.Region,
			cust.PostalCode,
			ctry.ISO3Chars,
			cust.PhoneNumber,
			cust.FaxNumber,
			cust.EmailAddress,
			cust.WebSite,
			cust.CustomerAlias,
			cust.PreferredCulture,
			cust.TaxNumber,
			cust.Currency,
			cust.CreditTerms,
			cust.Discount,
			cust.TaxCode,
			cust.TaxCodeSecondary,
			cust.Industry,
			cust.TheirIdentifier,
			cust.CustomerPricingClassification,
			cust.Notes,
			CAST(cust.PromptText AS nvarchar(max))			
	)	

	SELECT @results =    
		CONVERT(nvarchar(max), (SELECT
			cust.CustomerGUID AS [Guid],
			cust.CustomerName,
			COALESCE(dbo.wfn_RestApiGetSiteName(cust.[Site]), '') AS [Site],
			'' AS [Site],
			cust.CustomerId,
			cust.Branch,
			cust.[Address],
			cust.City,
			cust.Region,
			cust.PostalCode,
			cust.ISO3Chars AS Country,
			cust.PhoneNumber,
			cust.FaxNumber,
			cust.EmailAddress,
			cust.WebSite,
			cust.CustomerAlias,
			cust.PreferredCulture,
			'' AS PreferredCulture,
			cust.TaxNumber,
			'' AS TaxNumber,
			(SELECT
				CurrencyId,
				CurrencyDescription,
				ActualRate,
				StandardRate
			FROM
				Currencies
			WHERE
				cust.Currency = Currencies.Currency
			FOR XML PATH(''), TYPE) AS Currency,
			'' AS Currency,
			(SELECT
				CreditTermsId,
				CreditTermsDescription,
				TriggerDate,
				CASE WHEN EndOfMonth = 1 THEN 'true' ELSE 'false' END AS EndOfMonth,
				PaymentUnits AS PaymentPeriod,
				PaymentUnit,
				CASE WHEN CreditCardRequired = 1 THEN 'true' ELSE 'false' END AS CreditCardRequired
			FROM
				CreditTerms
			WHERE
				cust.CreditTerms = CreditTerms.CreditTerms
			FOR XML PATH(''), TYPE) AS CreditTerms,
			'' AS CreditTerms,
			(SELECT
				DiscountId,
				DiscountDescription,
				DiscountPercentage,
				(SELECT
					DiscountBreakId,
					TriggerType,
					TriggerValue,
					DiscountBreakType,
					DiscountBreakValue					
				FROM
					DiscountBreaks
				WHERE
					DiscountBreaks.Discount = Discounts.Discount
				FOR XML PATH('DiscountBreak'), TYPE) AS DiscountBreaks,
				'' AS DiscountBreaks
			FROM
				Discounts
			WHERE
				cust.Discount = Discounts.Discount
			FOR XML PATH(''), TYPE) AS Discount,
			'' AS Discount,
			(SELECT
				TaxCodeId,
				TaxCodeDescription,
				TaxRate
			FROM
				TaxCodes
			WHERE
				cust.TaxCode = TaxCodes.TaxCode
			FOR XML PATH(''), TYPE) AS TaxCode,
			'' AS TaxCode,
			(SELECT
				TaxCodeId,
				TaxCodeDescription,
				TaxRate
			FROM
				TaxCodes
			WHERE
				cust.TaxCodeSecondary = TaxCodes.TaxCode
			FOR XML PATH(''), TYPE) AS TaxCodeSecondary,
			'' AS TaxCodeSecondary,
			(SELECT
				IndustryId,
				IndustryDescription
			FROM
				Industries
			WHERE
				cust.Industry = Industries.Industry
			FOR XML PATH(''), TYPE) AS Industry,
			'' AS Industry,
			(SELECT
				CommissionAgentId,
				CustomerCommissionAgents.DefaultPercentage,
				Suppliers.SupplierName,
				Suppliers.Address,
				Suppliers.City,
				Suppliers.Region,
				Suppliers.PostalCode,
				Countries.ISO3Chars As Country,
				Suppliers.PhoneNumber,
				Suppliers.FaxNumber,
				Suppliers.EmailAddress
			FROM
				CommissionAgents
				INNER JOIN CustomerCommissionAgents ON CustomerCommissionAgents.CommissionAgent = CommissionAgents.CommissionAgent
				INNER JOIN Suppliers ON CommissionAgents.Supplier = Suppliers.Supplier
				INNER JOIN Countries ON Countries.Country = Suppliers.Country
			WHERE
				cust.Customer = CustomerCommissionAgents.Customer
			FOR XML PATH('CommissionAgent'), TYPE) AS CommissionAgents,
			'' AS CommissionAgents,
			(SELECT
				CRMContactGUID AS CrmContactGuid,
				CRMContactId AS CrmContactId,
				Title,
				FirstName,
				LastName,
				PhoneNumberWork,
				PhoneNumberHome,
				PhoneNumberMobile,
				CRMContacts.FaxNumber,
				EmailAddressWork,
				EmailAddressHome,
				PortalUserName AS WebsiteUserName,
				JobTitle,
				CASE WHEN AllowCommunication = 1 THEN 'true' ELSE 'false' END AS AllowCommunication
			FROM
				CRMContacts
				INNER JOIN CRMCompanies ON CRMCompanies.CRMCompany = CRMContacts.CRMCompany
			WHERE
				cust.Customer = CRMCompanies.Customer
				AND PortalUserName <> ''
			FOR XML PATH('Contact'), TYPE) AS Contacts,
			'' AS Contacts,
			cust.TheirIdentifier,
			(SELECT
				CustomerPricingClassificationId,
				CustomerPricingClassificationDescription
			FROM
				CustomerPricingClassifications
			WHERE
				cust.CustomerPricingClassification = CustomerPricingClassifications.CustomerPricingClassification
			FOR XML PATH(''), TYPE) AS CustomerPricingClassification,
			'' AS CustomerPricingClassification,
			(SELECT
				ProductId AS ProductSku,
				CustomersPartNumber,
				CustomersDescription,
				CustomerCrossReferences.MinimumOrderQuantity As MinimumOrderQuantity,
				'' AS MinimumOrderQuantity,
				CASE WHEN IgnorePrice = 1 THEN 'true' ELSE 'false' END AS IgnorePrice,
				Price,
				'' AS Price,
				(SELECT
					DiscountId,
					DiscountDescription,
					DiscountPercentage,
					(SELECT
						DiscountBreakId,
						TriggerType,
						TriggerValue,
						DiscountBreakType,
						DiscountBreakValue					
					FROM
						DiscountBreaks
					WHERE
						DiscountBreaks.Discount = Discounts.Discount
					FOR XML PATH('DiscountBreak'), TYPE) AS DiscountBreaks,
					'' AS DiscountBreaks
				FROM
					Discounts
				WHERE
					cust.Discount = Discounts.Discount
				FOR XML PATH(''), TYPE) AS Discount,
				'' AS Discount
			FROM
				CustomerCrossReferences
				INNER JOIN Products ON Products.Product = CustomerCrossReferences.Product
			WHERE
				cust.Customer = CustomerCrossReferences.Customer
			FOR XML PATH('CrossReference'), TYPE) AS CrossReferences,
			'' AS CrossReferences,
			cust.Notes,
			cust.PromptText
		FROM 
			CTE AS cust
		WHERE 
			(rowNumber > @pageSize * (@pageNumber - 1) )
			AND (rowNumber <= @pageSize * @pageNumber )
		ORDER BY
			RowNumber
		FOR XML PATH('Customer'), TYPE));

	--OPTION (OPTIMIZE FOR (@guid UNKNOWN, @website UNKNOWN, @lastModifiedDate UNKNOWN));

	IF @results IS NOT NULL AND @results <> ''
		BEGIN
			SELECT @results = '<Customers>' + @results + '</Customers>';
		END;
	ELSE
		BEGIN
			SELECT @results = '<Customers/>';
		END;

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
