SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing customers for the WinMan REST API in JSON format.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiCustomersSelectJSON]
	@guid NVARCHAR(36) = NULL,
	@website NVARCHAR(100),
	@seconds BIGINT = 315360000,
	@results NVARCHAR(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCustomersSelectJSON') = 1 
	BEGIN
		EXEC dbo.bsp_RestApiCustomersSelectJSON
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
						"Site":' + CASE WHEN dbo.wfn_RestApiGetSiteName(cust.[Site]) IS NULL THEN 'null' ELSE '"' + dbo.wfn_RestApiGetSiteName(cust.[Site]) + '"' END + ',
						"CustomerId":"' + REPLACE(REPLACE(REPLACE(cust.CustomerId, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
						"Branch":"' + cust.Branch + '",
						"Address":"' + REPLACE(REPLACE(REPLACE(cust.[Address], CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
						"City":"' + cust.City + '",
						"Region":"' + cust.Region + '",
						"PostalCode":"' + cust.PostalCode + '",
						"Country":"' + ctry.ISO3Chars + '",
						"PhoneNumber":"' + cust.PhoneNumber + '",
						"FaxNumber":"' + cust.FaxNumber + '",
						"EmailAddress":"' + cust.EmailAddress + '",
						"WebSite":"' + cust.WebSite + '",
						"CustomerAlias":"' + cust.CustomerAlias + '",
						"PreferredCulture":' + CASE WHEN cust.PreferredCulture IS NULL THEN 'null' ELSE '"' + cust.PreferredCulture + '"' END + ',
						"Currency":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"CurrencyId":"' + CurrencyId + '",
											"CurrencyDescription":"' + REPLACE(REPLACE(REPLACE(CurrencyDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"ActualRate":' + CAST(ActualRate AS NVARCHAR(20)) + ',
											"StandardRate":' + CAST(StandardRate AS NVARCHAR(20)) + '
										}' FROM Currencies
										WHERE cust.Currency = Currencies.Currency
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
								),
							'{}')
						 + ',
						"CreditTerms":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"CreditTermsId":"' + CreditTermsId + '",
											"CreditTermsDescription":"' + REPLACE(REPLACE(REPLACE(CreditTermsDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"TriggerDate":"' + TriggerDate + '",
											"EndOfMonth":' + CASE WHEN EndOfMonth = 1 THEN 'true' ELSE 'false' END + ',
											"PaymentPeriod":' + CAST(PaymentUnits AS NVARCHAR(20)) + ',
											"PaymentUnit":"' + PaymentUnit + '",
											"CreditCardRequired":' + CASE WHEN CreditCardRequired = 1 THEN 'true' ELSE 'false' END + '
										}' FROM CreditTerms
										WHERE cust.CreditTerms = CreditTerms.CreditTerms
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
								),
							'{}')
						 + ',
						"Discount":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"DiscountId":"' + DiscountId + '",
											"DiscountDescription":"' + REPLACE(REPLACE(REPLACE(DiscountDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"DiscountPercentage":' + CAST(DiscountPercentage AS NVARCHAR(20)) + ',
											"DiscountBreaks":' + (SELECT '[' + STUFF(
											(SELECT ',{
											"DiscountBreakId":"' + DiscountBreakId + '",
											"TriggerType":"' + TriggerType + '",
											"TriggerValue":' + CAST(TriggerValue AS NVARCHAR(20)) + ',
											"DiscountBreakType":"' + DiscountBreakType + '",
											"DiscountBreakValue":' + CAST(DiscountBreakValue AS NVARCHAR(20)) + '
											}' FROM DiscountBreaks WHERE DiscountBreaks.Discount = Discounts.Discount FOR XML PATH(''), TYPE)											
											.value('.','NVARCHAR(max)'), 1, 1, '') + ']')
											 + '
										}' FROM Discounts
										WHERE cust.Discount = Discounts.Discount
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
								),
							'{}')
						 + ',
						"TaxCode":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"TaxCodeId":"' + TaxCodeId + '",
											"TaxCodeDescription":"' + REPLACE(REPLACE(REPLACE(TaxCodeDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"TaxRate":' + CAST(TaxRate AS NVARCHAR(20)) + '
										}' FROM TaxCodes
										WHERE cust.TaxCode = TaxCodes.TaxCode
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(500)'), 1, 1, '')
									),
							'{}')
						 + ',
						"TaxCodeSecondary":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"TaxCodeId":"' + TaxCodeId + '",
											"TaxCodeDescription":"' + REPLACE(REPLACE(REPLACE(TaxCodeDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"TaxRate":' + CAST(TaxRate AS NVARCHAR(20)) + '
										}' FROM TaxCodes
										WHERE cust.TaxCodeSecondary = TaxCodes.TaxCode
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(500)'), 1, 1, '')
									),
							'{}')
						 + ',
						"Industry":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"IndustryId":"' + IndustryId + '",
											"IndustryDescription":"' + REPLACE(REPLACE(REPLACE(IndustryDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '"
										}' FROM Industries
										WHERE cust.Industry = Industries.Industry
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(500)'), 1, 1, '')
									),
							'{}')
						 + ',
						 "CommissionAgents":' +
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"CommissionAgentId":"' + CommissionAgentId + '",
											"DefaultPercentage":' + CAST(CustomerCommissionAgents.DefaultPercentage AS NVARCHAR(20)) + ',
											"SupplierName":"' + Suppliers.SupplierName + '",
											"Address":"' + REPLACE(REPLACE(REPLACE(Suppliers.Address, CHAR(13),'&#xD;'), CHAR(10),'&#xA'), '"','&#34;') + '",
											"City":"' + Suppliers.City + '",
											"Region":"' + Suppliers.Region + '",
											"PostalCode":"' + Suppliers.PostalCode + '",
											"Country":"' + Countries.ISO3Chars + '",
											"PhoneNumber":"' + Suppliers.PhoneNumber + '",
											"FaxNumber":"' + Suppliers.FaxNumber + '",
											"EmailAddress":"' + Suppliers.EmailAddress + '"
										}' FROM CommissionAgents
											INNER JOIN CustomerCommissionAgents ON CustomerCommissionAgents.CommissionAgent = CommissionAgents.CommissionAgent
											INNER JOIN Suppliers ON CommissionAgents.Supplier = Suppliers.Supplier
											INNER JOIN Countries ON Countries.Country = Suppliers.Country
										WHERE cust.Customer = CustomerCommissionAgents.Customer
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
								+ ']'),
							'[]')					 
						 + ',
						 "Contacts":' +
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"CrmContactGuid":"' + CAST(CRMContactGUID AS NVARCHAR(36)) + '",
											"CrmContactId":"' + CRMContactId + '",
											"FirstName":"' + FirstName + '",
											"LastName":"' + LastName + '",
											"PhoneNumberWork":"' + PhoneNumberWork + '",
											"PhoneNumberHome":"' + PhoneNumberHome + '",
											"FaxNumber":"' + CRMContacts.FaxNumber + '",
											"EmailAddressWork":"' + EmailAddressWork + '",
											"EmailAddressHome":"' + EmailAddressHome + '",
											"PortalUserName":"' + PortalUserName + '",
											"JobTitle":"' + JobTitle + '",
											"AllowCommunication":' + CASE WHEN AllowCommunication = 1 THEN 'true' ELSE 'false' END + '
										}' FROM CRMContacts
											INNER JOIN CRMCompanies ON CRMCompanies.CRMCompany = CRMContacts.CRMCompany
										WHERE cust.Customer = CRMCompanies.Customer
											AND PortalUserName <> ''
											AND PortalUserName IS NOT NULL
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
								+ ']')				 
						 + ',
						"TheirIdentifier":"' + cust.TheirIdentifier + '",
						"CustomerPricingClassification":' + 
							COALESCE(
								(SELECT 
									STUFF(
										(SELECT ',{
											"CustomerPricingClassificationId":"' + CustomerPricingClassificationId + '",
											"CustomerPricingClassificationDescription":"' + CustomerPricingClassificationDescription + '"
										}' FROM CustomerPricingClassifications
										WHERE cust.CustomerPricingClassification = CustomerPricingClassifications.CustomerPricingClassification
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(500)'), 1, 1, '')
									),
							'{}')
						 + ',
						 "CrossReferences":' +
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{
											"ProductSku":"' + ProductId + '",
											"CustomersPartNumber":"' + CustomersPartNumber + '",
											"CustomersDescription":"' + CustomersDescription + '",
											"MinimumOrderQuantity":' + COALESCE(CAST(CustomerCrossReferences.MinimumOrderQuantity AS NVARCHAR(20)), 'null') + ',
											"IgnorePrice":' + CASE WHEN IgnorePrice = 1 THEN 'true' ELSE 'false' END + ',
											"Price":' + CAST(Price AS NVARCHAR(20)) + ',
											"Discount":' + 
												COALESCE(
													(SELECT 
														STUFF(
															(SELECT ',{
																"DiscountId":"' + DiscountId + '",
																"DiscountDescription":"' + DiscountDescription + '",
																"DiscountPercentage":' + CAST(DiscountPercentage AS NVARCHAR(20)) + ',
																"DiscountBreaks":' + (SELECT '[' + STUFF(
																(SELECT ',{
																"DiscountBreakId":"' + DiscountBreakId + '",
																"TriggerType":"' + TriggerType + '",
																"TriggerValue":' + CAST(TriggerValue AS NVARCHAR(20)) + ',
																"DiscountBreakType":"' + DiscountBreakType + '",
																"DiscountBreakValue":' + CAST(DiscountBreakValue AS NVARCHAR(20)) + '
																}' FROM DiscountBreaks WHERE DiscountBreaks.Discount = Discounts.Discount FOR XML PATH(''), TYPE)											
																.value('.','NVARCHAR(max)'), 1, 1, '') + ']')
																 + '
															}' FROM Discounts
															WHERE cust.Discount = Discounts.Discount
															FOR XML PATH(''),
															TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
													),
												'{}')
											 + '
										}' FROM CustomerCrossReferences
											INNER JOIN Products ON Products.Product = CustomerCrossReferences.Product
										WHERE cust.Customer = CustomerCrossReferences.Customer
										FOR XML PATH(''),
										TYPE).value('.','NVARCHAR(max)'), 1, 1, '')
								+ ']'),
							'[]')					 
						 + ',
						 "Notes":"' + cust.Notes + '",
						 "PromptText":"' + CAST(cust.PromptText AS NVARCHAR(100)) + '"
					}' 
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
					FOR XML PATH(''), 
			TYPE).value('.','NVARCHAR(max)'), 1, 1, '' 
			)), '')

	OPTION (OPTIMIZE FOR (@guid UNKNOWN, @website UNKNOWN, @lastModifiedDate UNKNOWN, @results UNKNOWN))

	SELECT @results = REPLACE(REPLACE(REPLACE('{"Customers":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), '')

	SELECT @results

END
GO
