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
-- Description:	Stored procedure for SELECTing customers for the WinMan REST API in JSON format.
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
		AND p.[name] = 'wsp_RestApiCustomersSelectJSON'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiCustomersSelectJSON AS PRINT ''dbo.wsp_RestApiCustomersSelectJSON''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiCustomersSelectJSON]
	@pageNumber int = 1,
	@pageSize int = 10,
	@guid nvarchar(36) = null,
	@website nvarchar(100),
	@seconds bigint = 315360000,
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCustomersSelectJSON') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiCustomersSelectJSON
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

	SELECT @results = COALESCE(
		(SELECT
			STUFF( 
				(SELECT ',{
						"Guid":"' + CAST(cust.CustomerGUID AS nvarchar(36)) + '",
						"Site":' + CASE WHEN dbo.wfn_RestApiGetSiteName(cust.[Site]) IS NULL THEN 'null' ELSE '"' + dbo.wfn_RestApiGetSiteName(cust.[Site]) + '"' END + ',
						"CustomerId":"' + REPLACE(cust.CustomerId, '"','&#34;') + '",
						"Branch":"' + REPLACE(cust.Branch, '"','&#34;') + '",
						"Address":"' + REPLACE(REPLACE(REPLACE(cust.[Address], CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
						"City":"' + REPLACE(cust.City, '"','&#34;') + '",
						"Region":"' + REPLACE(cust.Region, '"','&#34;') + '",
						"PostalCode":"' + REPLACE(cust.PostalCode, '"','&#34;') + '",
						"Country":"' + cust.ISO3Chars + '",
						"PhoneNumber":"' + REPLACE(cust.PhoneNumber, '"','&#34;') + '",
						"FaxNumber":"' + REPLACE(cust.FaxNumber, '"','&#34;') + '",
						"EmailAddress":"' + REPLACE(cust.EmailAddress, '"','&#34;') + '",
						"WebSite":"' + REPLACE(cust.WebSite, '"','&#34;') + '",
						"CustomerAlias":"' + REPLACE(cust.CustomerAlias, '"','&#34;') + '",
						"PreferredCulture":' + CASE WHEN cust.PreferredCulture IS NULL THEN 'null' ELSE '"' + cust.PreferredCulture + '"' END + ',
						"Currency":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"CurrencyId":"' + REPLACE(CurrencyId, '"','&#34;') + '",
											"CurrencyDescription":"' + REPLACE(REPLACE(REPLACE(CurrencyDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"ActualRate":' + CAST(ActualRate AS nvarchar(20)) + ',
											"StandardRate":' + CAST(StandardRate AS nvarchar(20)) + '
										}' FROM Currencies
										WHERE cust.Currency = Currencies.Currency
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
								),
							'{}')
						 + ',
						"CreditTerms":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"CreditTermsId":"' + REPLACE(CreditTermsId, '"','&#34;') + '",
											"CreditTermsDescription":"' + REPLACE(REPLACE(REPLACE(CreditTermsDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"TriggerDate":"' + TriggerDate + '",
											"EndOfMonth":' + CASE WHEN EndOfMonth = 1 THEN 'true' ELSE 'false' END + ',
											"PaymentPeriod":' + CAST(PaymentUnits AS nvarchar(20)) + ',
											"PaymentUnit":"' + PaymentUnit + '",
											"CreditCardRequired":' + CASE WHEN CreditCardRequired = 1 THEN 'true' ELSE 'false' END + '
										}' FROM CreditTerms
										WHERE cust.CreditTerms = CreditTerms.CreditTerms
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
								),
							'{}')
						 + ',
						"Discount":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"DiscountId":"' + REPLACE(DiscountId, '"','&#34;') + '",
											"DiscountDescription":"' + REPLACE(REPLACE(REPLACE(DiscountDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"DiscountPercentage":' + CAST(DiscountPercentage AS nvarchar(20)) + ',
											"DiscountBreaks":' + (SELECT '[' + STUFF(
											(SELECT ',{
											"DiscountBreakId":"' + REPLACE(DiscountBreakId, '"','&#34;') + '",
											"TriggerType":"' + TriggerType + '",
											"TriggerValue":' + CAST(TriggerValue AS nvarchar(20)) + ',
											"DiscountBreakType":"' + DiscountBreakType + '",
											"DiscountBreakValue":' + CAST(DiscountBreakValue AS nvarchar(20)) + '
											}' FROM DiscountBreaks WHERE DiscountBreaks.Discount = Discounts.Discount FOR XML PATH(''), TYPE)			
											.value('.','nvarchar(max)'), 1, 1, '') + ']')
											 + '
										}' FROM Discounts
										WHERE cust.Discount = Discounts.Discount
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
								),
							'{}')
						 + ',
						"TaxCode":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"TaxCodeId":"' + REPLACE(TaxCodeId, '"','&#34;') + '",
											"TaxCodeDescription":"' + REPLACE(REPLACE(REPLACE(TaxCodeDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"TaxRate":' + CAST(TaxRate AS nvarchar(20)) + '
										}' FROM TaxCodes
										WHERE cust.TaxCode = TaxCodes.TaxCode
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(500)'), 1, 1, '')
									),
							'{}')
						 + ',
						"TaxCodeSecondary":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"TaxCodeId":"' + REPLACE(TaxCodeId, '"','&#34;') + '",
											"TaxCodeDescription":"' + REPLACE(REPLACE(REPLACE(TaxCodeDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"TaxRate":' + CAST(TaxRate AS nvarchar(20)) + '
										}' FROM TaxCodes
										WHERE cust.TaxCodeSecondary = TaxCodes.TaxCode
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(500)'), 1, 1, '')
									),
							'{}')
						 + ',
						"Industry":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"IndustryId":"' + REPLACE(IndustryId, '"','&#34;') + '",
											"IndustryDescription":"' + REPLACE(REPLACE(REPLACE(IndustryDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '"
										}' FROM Industries
										WHERE cust.Industry = Industries.Industry
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(500)'), 1, 1, '')
									),
							'{}')
						 + ',
						 "CommissionAgents":' +
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"CommissionAgentId":"' + REPLACE(CommissionAgentId, '"','&#34;') + '",
											"DefaultPercentage":' + CAST(CustomerCommissionAgents.DefaultPercentage AS nvarchar(20)) + ',
											"SupplierName":"' + REPLACE(Suppliers.SupplierName, '"','&#34;') + '",
											"Address":"' + REPLACE(REPLACE(REPLACE(Suppliers.Address, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"City":"' + REPLACE(Suppliers.City, '"','&#34;') + '",
											"Region":"' + REPLACE(Suppliers.Region, '"','&#34;') + '",
											"PostalCode":"' + REPLACE(Suppliers.PostalCode, '"','&#34;') + '",
											"Country":"' + Countries.ISO3Chars + '",
											"PhoneNumber":"' + REPLACE(Suppliers.PhoneNumber, '"','&#34;') + '",
											"FaxNumber":"' + REPLACE(Suppliers.FaxNumber, '"','&#34;') + '",
											"EmailAddress":"' + REPLACE(Suppliers.EmailAddress, '"','&#34;') + '"
										}' FROM CommissionAgents
											INNER JOIN CustomerCommissionAgents ON CustomerCommissionAgents.CommissionAgent = CommissionAgents.CommissionAgent
											INNER JOIN Suppliers ON CommissionAgents.Supplier = Suppliers.Supplier
											INNER JOIN Countries ON Countries.Country = Suppliers.Country
										WHERE cust.Customer = CustomerCommissionAgents.Customer
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
								+ ']'),
							'[]')					 
						 + ',
						 "Contacts":' +
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"CrmContactGuid":"' + CAST(CRMContactGUID AS nvarchar(36)) + '",
											"CrmContactId":"' + REPLACE(CRMContactId, '"','&#34;') + '",
											"FirstName":"' + REPLACE(FirstName, '"','&#34;') + '",
											"LastName":"' + REPLACE(LastName, '"','&#34;') + '",
											"PhoneNumberWork":"' + REPLACE(PhoneNumberWork, '"','&#34;') + '",
											"PhoneNumberHome":"' + REPLACE(PhoneNumberHome, '"','&#34;') + '",
											"FaxNumber":"' + REPLACE(CRMContacts.FaxNumber, '"','&#34;') + '",
											"EmailAddressWork":"' + REPLACE(EmailAddressWork, '"','&#34;') + '",
											"EmailAddressHome":"' + REPLACE(EmailAddressHome, '"','&#34;') + '",
											"WebsiteUserName":"' + REPLACE(PortalUserName, '"','&#34;') + '",
											"JobTitle":"' + REPLACE(JobTitle, '"','&#34;') + '",
											"AllowCommunication":' + CASE WHEN AllowCommunication = 1 THEN 'true' ELSE 'false' END + '
										}' FROM CRMContacts
											INNER JOIN CRMCompanies ON CRMCompanies.CRMCompany = CRMContacts.CRMCompany
										WHERE cust.Customer = CRMCompanies.Customer
											AND PortalUserName <> ''
											AND PortalUserName IS NOT NULL
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
								+ ']')				 
						 + ',
						"TheirIdentifier":"' + REPLACE(cust.TheirIdentifier, '"','&#34;') + '",
						"CustomerPricingClassification":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"CustomerPricingClassificationId":"' + REPLACE(CustomerPricingClassificationId, '"','&#34;') + '",
											"CustomerPricingClassificationDescription":"' + REPLACE(CustomerPricingClassificationDescription, '"','&#34;') + '"
										}' FROM CustomerPricingClassifications
										WHERE cust.CustomerPricingClassification = CustomerPricingClassifications.CustomerPricingClassification
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(500)'), 1, 1, '')
									),
							'{}')
						 + ',
						 "CrossReferences":' +
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"ProductSku":"' + REPLACE(ProductId, '"','&#34;') + '",
											"CustomersPartNumber":"' + REPLACE(CustomersPartNumber, '"','&#34;') + '",
											"CustomersDescription":"' + REPLACE(CustomersDescription, '"','&#34;') + '",
											"MinimumOrderQuantity":' + COALESCE(CAST(CustomerCrossReferences.MinimumOrderQuantity AS nvarchar(20)), 'null') + ',
											"IgnorePrice":' + CASE WHEN IgnorePrice = 1 THEN 'true' ELSE 'false' END + ',
											"Price":' + COALESCE(CAST(Price AS nvarchar(20)), 'null') + ',
											"Discount":' + 
												COALESCE(
													(SELECT 
														STUFF(
															(SELECT ',{
																"DiscountId":"' + REPLACE(DiscountId, '"','&#34;') + '",
																"DiscountDescription":"' + REPLACE(DiscountDescription, '"','&#34;') + '",
																"DiscountPercentage":' + CAST(DiscountPercentage AS nvarchar(20)) + ',
																"DiscountBreaks":' + (SELECT '[' + STUFF(
																(SELECT ',{
																"DiscountBreakId":"' + REPLACE(DiscountBreakId, '"','&#34;') + '",
																"TriggerType":"' + TriggerType + '",
																"TriggerValue":' + CAST(TriggerValue AS nvarchar(20)) + ',
																"DiscountBreakType":"' + DiscountBreakType + '",
																"DiscountBreakValue":' + CAST(DiscountBreakValue AS nvarchar(20)) + '
																}' FROM DiscountBreaks WHERE DiscountBreaks.Discount = Discounts.Discount FOR XML PATH(''), TYPE)											
																.value('.','nvarchar(max)'), 1, 1, '') + ']')
																 + '
															}' FROM Discounts
															WHERE cust.Discount = Discounts.Discount
															FOR XML PATH(''),
															TYPE).value('.','nvarchar(max)'), 1, 1, '')
													),
												'{}')
											 + '
										}' FROM CustomerCrossReferences
											INNER JOIN Products ON Products.Product = CustomerCrossReferences.Product
										WHERE cust.Customer = CustomerCrossReferences.Customer
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
								+ ']'),
							'[]')					 
						 + ',
						 "Notes":"' + REPLACE(REPLACE(REPLACE(cust.Notes, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
						 "PromptText":"' + REPLACE(REPLACE(REPLACE(cust.PromptText, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '"
					}' 
					FROM 
						CTE AS cust
					WHERE 
						(rowNumber > @pageSize * (@pageNumber - 1) )
						AND (rowNumber <= @pageSize * @pageNumber )
					ORDER BY
						RowNumber 
					FOR XML PATH(''), 
			TYPE).value('.','nvarchar(max)'), 1, 1, '' 
			)), '');

	--OPTION (OPTIMIZE FOR (@guid UNKNOWN, @website UNKNOWN, @lastModifiedDate UNKNOWN));

	SELECT @results = REPLACE(REPLACE(REPLACE('{"Customers":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), '');

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
