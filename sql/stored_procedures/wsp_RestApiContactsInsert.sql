SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 29 September 2017
-- Description:	Stored procedure for INSERTing new contacts into WinMan for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiContactsInsert]
	@eCommerceWebsiteId NVARCHAR(100) = NULL,
	@firstName NVARCHAR(25) = NULL,
	@lastName NVARCHAR(25) = NULL,
	@workPhoneNumber NVARCHAR(30) = NULL,
	@homePhoneNumber NVARCHAR(30) = NULL,
	@mobilePhoneNumber NVARCHAR(30) = NULL,
	@faxNumber NVARCHAR(30) = NULL,
	@homeEmailAddress NVARCHAR(50) = NULL,
	@workEmailAddress NVARCHAR(50) = NULL,
	@portalUserName NVARCHAR(50) = NULL,
	@jobTitle NVARCHAR(50) = NULL,
	@allowCommunication BIT = 0,
	@address NVARCHAR(200) = NULL,
	@city NVARCHAR(50) = NULL,
	@region NVARCHAR(50) = NULL,
	@postalCode NVARCHAR(20) = NULL,
	@countryCode NVARCHAR(3) = NULL,
	@error NVARCHAR(1000) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiContactsInsert') = 1 
	BEGIN
		EXEC dbo.bsp_RestApiContactsInsert
			@eCommerceWebsiteId = @eCommerceWebsiteId,
			@firstName = @firstName,
			@lastName = @lastName,
			@workPhoneNumber = @workPhoneNumber,
			@homePhoneNumber = @homePhoneNumber,
			@mobilePhoneNumber = @mobilePhoneNumber,
			@faxNumber = @faxNumber,
			@homeEmailAddress = @homeEmailAddress,
			@workEmailAddress = @workEmailAddress,
			@portalUserName = @portalUserName,
			@jobTitle = @jobTitle,
			@allowCommunication = @allowCommunication,
			@address = @address,
			@city = @city,
			@region = @region,
			@postalCode = @postalCode,
			@countryCode = @countryCode,
			@error = @error OUTPUT
		RETURN	
	END

	SET NOCOUNT ON;

	IF @eCommerceWebsiteId IS NULL OR @eCommerceWebsiteId = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Website.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @portalUserName IS NULL OR @portalUserName = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: User Name.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF EXISTS (SELECT 
					ctct.PortalUserName
				FROM 
					CRMContacts ctct
					INNER JOIN CRMCompanies comp ON ctct.CRMCompany = comp.CRMCompany
					INNER JOIN Customers cust ON comp.Customer = cust.Customer
					INNER JOIN EcommerceWebsiteSites ews ON cust.[Site] = ews.[Site]
					INNER JOIN EcommerceWebsites ew ON ew.EcommerceWebsite = ews.EcommerceWebsite
				WHERE 
					ew.EcommerceWebsiteId = @eCommerceWebsiteId
					AND ctct.PortalUserName = @portalUserName)
	OR EXISTS (SELECT 
					ctct.PortalUserName
				FROM 
					CRMContacts ctct
					INNER JOIN CRMCompanies comp ON ctct.CRMCompany = comp.CRMCompany
					INNER JOIN Customers cust ON comp.Customer = cust.Customer
				WHERE 
					cust.[Site] IS NULL
					AND ctct.PortalUserName = @portalUserName)
	OR EXISTS (SELECT
					ctct.PortalUserName
				FROM
					CRMContacts ctct
					INNER JOIN CRMCompanies comp ON ctct.CRMCompany = comp.CRMCompany
				WHERE
					ctct.PortalUserName = @portalUserName
					AND comp.Customer IS NULL)
		BEGIN
			SET @error = 'ERROR: Specified User Name already exists. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	DECLARE
		@site BIGINT,
		@crmCompany BIGINT,
		@name NVARCHAR(50),
		@country BIGINT,
		@department BIGINT,
		@customerIndustry BIGINT,
		@customerCurrency BIGINT,
		@customerGlAccountDivision BIGINT,
		@customerTaxCode BIGINT,
		@customerCreditTerms BIGINT,
		@customerSettlementTerms BIGINT,
		@customerGlAccountType BIGINT,
		@supplierIndustry BIGINT,
		@supplierCurrency BIGINT,
		@supplierGlAccountDivision BIGINT,
		@supplierDepartment BIGINT,
		@supplierTaxCode BIGINT,
		@supplierCreditTerms BIGINT,
		@supplierSettlementTerms BIGINT,
		@supplierGlAccountType BIGINT,
		@crmSource BIGINT,
		@crmGroup BIGINT,
		@crmRegion BIGINT,
		@crmContact BIGINT,
		@date DATETIME = GETDATE(),
		@user NVARCHAR(20) = 'WinMan REST API'

	SET @error = ''

	SET @site = (SELECT 
					[Site] 
				FROM 
					EcommerceWebsiteSites ews
					INNER JOIN EcommerceWebsites ew ON ews.EcommerceWebsite = ew.EcommerceWebsite
				WHERE 
					ew.EcommerceWebsiteId = @eCommerceWebsiteId
					AND ews.[Default] = 1)

	IF @site IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find specified website. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @firstName IS NULL OR @firstName = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: First Name.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @lastName IS NULL OR @lastName = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Last Name.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	SET @name = @firstName + ' ' + @lastName

	IF @workPhoneNumber IS NULL
		BEGIN
			SET @workPhoneNumber = ''
		END

	IF @homePhoneNumber IS NULL
		BEGIN
			SET @homePhoneNumber = ''
		END

	IF @mobilePhoneNumber IS NULL
		BEGIN
			SET @mobilePhoneNumber = ''
		END

	IF @faxNumber IS NULL
		BEGIN
			SET @faxNumber = ''
		END

	IF @homeEmailAddress IS NULL
		BEGIN
			SET @homeEmailAddress = ''
		END

	IF @workEmailAddress IS NULL
		BEGIN
			SET @workEmailAddress = ''
		END

	IF @jobTitle IS NULL
		BEGIN
			SET @jobTitle = ''
		END

	IF @address IS NULL OR @address = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Address.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @city IS NULL
		BEGIN
			SET @city = ''
		END

	IF @region IS NULL
		BEGIN
			SET @region = ''
		END

	IF @postalCode IS NULL OR @postalCode = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Postal Code.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @countryCode IS NULL OR @countryCode = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Country Code.'
			SELECT @error AS ErrorMessage
			RETURN
		END
	ELSE
		BEGIN
			SET @country = (SELECT TOP 1 Country FROM Countries WHERE ISO3Chars = @countryCode)
		END

	IF @country IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find country with specified county code. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @allowCommunication IS NULL
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Allow Communication.'
			SELECT @error AS ErrorMessage
			RETURN
		END		

	SELECT
		@department = SalesDepartment,
		@customerIndustry = SalesIndustry,
		@customerGlAccountDivision = SalesGLDivision,
		@customerTaxCode = SalesTaxcode,
		@customerCreditTerms = SalesCreditTerms,
		@customerSettlementTerms = SalesSettlementTerms,
		@customerGlAccountType = SalesArGLType,
		@supplierIndustry = PurchaseIndustry,
		@supplierGlAccountDivision = PurchaseGLDivision,
		@supplierDepartment = PurchaseDepartment,
		@supplierTaxCode = PurchaseTaxcode,
		@supplierCreditTerms = PurchaseCreditTerms,
		@supplierSettlementTerms = PurchaseSettlementTerms,
		@supplierGlAccountType = PurchaseApGLType,
		@crmSource = CRMSource,
		@crmGroup = CRMGroup,
		@crmRegion = CRMRegion
	FROM
		Sites
	WHERE
		[Site] = @site

	SELECT
		@customerCurrency = SalesCurrency,
		@supplierCurrency = PurchaseCurrency
	FROM
		ApplicationSettings

	EXEC wsp_CRMCompaniesInsert
		@CompanyName = @name,
		@Address = @address,
		@City = @city,
		@Region = @region,
		@PostalCode = @postalCode,
		@Country = @country,
		@PhoneNumber = @workPhoneNumber,
		@FaxNumber = @faxNumber,
		@EmailAddress = @workEmailAddress,
		@Website = '',
		@Department = @department,
		@Supplier = 0,
		@Customer = 0,
		@CreatedDate = @date,
		@CreatedUser = @user,
		@LastModifiedDate = @date,
		@LastModifiedUser = @user,
		@Comments = '',
		@ReselectRecord = 0,
		@New_CRMCompany = @crmCompany OUTPUT,
		@CustomerIndustry = @customerIndustry,
		@CustomerCurrency = @customerCurrency,
		@CustomerGLAccountDivision = @customerGlAccountDivision,
		@CustomerDepartment = @department,
		@CustomerTaxCode = @customerTaxCode,
		@CustomerCreditTerms = @customerCreditTerms,
		@CustomerSettlementTerms = @customerSettlementTerms,
		@CustomerGLAccountType = @customerGlAccountType,
		@SupplierIndustry = @supplierIndustry,
		@SupplierCurrency = @supplierCurrency,
		@SupplierGLAccountDivision = @supplierGlAccountDivision,
		@SupplierDepartment = @supplierDepartment,
		@SupplierTaxCode = @supplierTaxCode,
		@SupplierCreditTerms = @supplierCreditTerms,
		@SupplierSettlementTerms = @supplierSettlementTerms,
		@SupplierGLAccountType = @supplierGlAccountType,
		@CustomerBranch = '',
		@SupplierBranch = '',
		@SourceStoredProcedure = '',
		@CreditLimit = null, -- Leave null.
		@PromptText = '',
		@CompanyAlias = '',
		@CustomerNotes = '',
		@SupplierNotes = '',
		@CustomerPricingClassification = 0,
		@CompanyType1 = 0,
		@CompanyType2 = 0,
		@CompanyType3 = 0,
		@CompanyType4 = 0,
		@CompanyType5 = 0,
		@CompanyType6 = 0,
		@Longitude = 0,
		@Latitude = 0,
		@CRMCompanyId = '',
		@CorporateHeadOffice = 0,
		@CustomerPriceList = 0,
		@Territory = null, -- Leave null.
		@TimeZone = null, -- Leave null.
		@WorkSchedule = null, -- Leave null.
		@DC_001_TXT = '',
		@DC_002_TXT = '',
		@DC_003_TXT = '',
		@DC_004_TXT = '',
		@DC_005_INT = 0,
		@DC_006_DAT = null, -- Leave null.
		@CustomerDiscount = null, -- Leave null.
		@SupplierDiscount = null -- Leave null.	

	EXEC wsp_CRMContactsInsert
		@ContactName = @name,
		@FirstName = @firstName,
		@LastName = @lastName,
		@Title = '',
		@JobTitle = @jobTitle,
		@PhoneNumberHome = @homePhoneNumber,
		@PhoneNumberWork = @workPhoneNumber,
		@PhoneNumberMobile = @mobilePhoneNumber,
		@FaxNumber = @faxNumber,
		@EmailAddressHome = @homeEmailAddress,
		@EmailAddressWork = @workEmailAddress,
		@Department = @department,
		@CRMSource = @crmSource,
		@CRMGroup = @crmGroup,
		@CRMRegion = @crmRegion,
		@LeadType = 'L',
		@Active = 1,
		@CRMCompany = @crmCompany,
		@CompanyName = @name,
		@ContactCompanyAddress = @address,
		@ContactCompanyCity = @city,
		@ContactCompanyRegion = @region,
		@ContactCompanyPostalCode = @postalCode,
		@ContactCompanyCountry = @country,
		@ContactSupplier = null, -- Leave null.
		@ContactCustomer = null, -- Leave null.
		@CreatedUser = @user,
		@CreatedDate = @date,
		@LastModifiedUser = @user,
		@LastModifiedDate = @date,
		@Comments = '',
		@DC_001_TXT = '',
		@DC_002_TXT = '',
		@DC_003_TXT = '',
		@DC_004_TXT = '',
		@DC_005_TXT = '',
		@DC_006_TXT = '',
		@DC_007_TXT = '',
		@DC_008_TXT = '',
		@DC_009_TXT = '',
		@DC_010_TXT = '',
		@DC_011_TXT = '',
		@DC_012_TXT = '',
		@DC_013_INT = 0,
		@DC_014_INT = 0,
		@DC_015_INT = 0,
		@DC_016_INT = 0,
		@DC_017_DAT = @date,
		@DC_018_DAT = @date,
		@DC_019_DAT = @date,
		@DC_020_DAT = @date,
		@ReselectRecord = 0,
		@CompanyWebsite = '',
		@CustomerSecurityLevel = 0,
		@SupplierSecurityLevel = 0,
		@AllowCommunication = @allowCommunication,
		@PortalUserName = @portalUserName,
		@CRMContact = @crmContact OUTPUT

		SELECT @error AS ErrorMessage

END
GO
