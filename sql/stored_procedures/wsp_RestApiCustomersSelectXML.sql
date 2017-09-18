SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing customers for the WinMan REST API in XML format.
-- =============================================

CREATE PROCEDURE dbo.wsp_RestApiCustomersSelectXML
	@guid NVARCHAR(36) = NULL,
	@website NVARCHAR(100),
	@seconds BIGINT = 315360000,
	@results NVARCHAR(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCustomersSelectXML') = 1 
	BEGIN
		EXEC dbo.bsp_RestApiCustomersSelectXML
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
			COALESCE(dbo.wfn_RestApiGetSiteName(cust.[Site]), '') AS [Site],
			'' AS [Site],
			cust.CustomerId,
			cust.Branch,
			cust.[Address],
			cust.City,
			cust.Region,
			cust.PostalCode,
			ctry.ISO3Chars AS Country,
			cust.PhoneNumber,
			cust.FaxNumber,
			cust.EmailAddress,
			cust.WebSite,
			cust.CustomerAlias,
			cust.PreferredCulture,
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
				FirstName,
				LastName,
				PhoneNumberWork,
				PhoneNumberHome,
				PhoneNumberMobile,
				CRMContacts.FaxNumber,
				EmailAddressWork,
				EmailAddressHome,
				PortalUserName,
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
		FROM Customers cust
			INNER JOIN Countries AS ctry ON cust.Country = ctry.Country
		WHERE cust.CustomerGUID = COALESCE(@guid, cust.CustomerGUID)
			AND (cust.LastModifiedDate >= @lastModifiedDate)
			AND ((cust.Site IS NULL) OR (cust.Site IN 
				(SELECT
					Site
				FROM
					EcommerceWebsiteSites EWS
					INNER JOIN EcommerceWebsites EW ON EW.EcommerceWebsite = EWS.EcommerceWebsite
				WHERE
					EcommerceWebsiteId = @website)
			))
		FOR XML PATH('Customer'))

	OPTION (OPTIMIZE FOR (@guid UNKNOWN, @website UNKNOWN, @lastModifiedDate UNKNOWN, @results UNKNOWN))

	IF (@results IS NOT NULL)
		SELECT @results = CONCAT('<Customers>', @results, '</Customers>')

	SELECT @results

END
GO