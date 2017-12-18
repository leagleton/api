SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 29 September 2017
-- Description:	Stored procedure for INSERTing new contacts into WinMan for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiContactsInsert'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiContactsInsert AS PRINT ''dbo.wsp_RestApiContactsInsert''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiContactsInsert]
	@eCommerceWebsiteId nvarchar(100) = null,
	@firstName nvarchar(25) = null,
	@lastName nvarchar(25) = null,
	@workPhoneNumber nvarchar(30) = null,
	@homePhoneNumber nvarchar(30) = null,
	@mobilePhoneNumber nvarchar(30) = null,
	@faxNumber nvarchar(30) = null,
	@homeEmailAddress nvarchar(50) = null,
	@workEmailAddress nvarchar(50) = null,
	@portalUserName nvarchar(50) = null,
	@jobTitle nvarchar(50) = null,
	@allowCommunication bit = 0,
	@address nvarchar(200) = null,
	@city nvarchar(50) = null,
	@region nvarchar(50) = null,
	@postalCode nvarchar(20) = null,
	@countryCode nvarchar(3) = null,
	@scope nvarchar(50),
	@error nvarchar(1000) OUTPUT,
	@contact bigint OUTPUT,
	@company bigint OUTPUT,
	@exists bit OUTPUT
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
				@scope = @scope,
				@error = @error OUTPUT,
				@contact = @contact OUTPUT,
				@company = @company OUTPUT,
				@exists = @exists OUTPUT;
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
			AND w.EcommerceWebsiteId = @eCommerceWebsiteId
	)
		BEGIN
			SET @error = 'The relevant REST API scope is not enabled for the specified website.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;	

	IF @eCommerceWebsiteId IS NULL OR @eCommerceWebsiteId = ''
		BEGIN
			SET @error = 'A required parameter is missing: Website.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	IF @portalUserName IS NULL OR @portalUserName = ''
		BEGIN
			SET @error = 'A required parameter is missing: WebsiteUserName.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

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
		BEGIN
			SET @exists = 1;
			SELECT @exists AS [Exists], @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	DECLARE @site bigint;
	DECLARE @crmCompany bigint;
	DECLARE @name nvarchar(50);
	DECLARE @country bigint;
	DECLARE @department bigint;
	DECLARE @customerIndustry bigint;
	DECLARE @customerCurrency bigint;
	DECLARE @customerGlAccountDivision bigint;
	DECLARE @customerTaxCode bigint;
	DECLARE @customerCreditTerms bigint;
	DECLARE @customerSettlementTerms bigint;
	DECLARE @customerGlAccountType bigint;
	DECLARE @supplierIndustry bigint;
	DECLARE @supplierCurrency bigint;
	DECLARE @supplierGlAccountDivision bigint;
	DECLARE @supplierDepartment bigint;
	DECLARE @supplierTaxCode bigint;
	DECLARE @supplierCreditTerms bigint;
	DECLARE @supplierSettlementTerms bigint;
	DECLARE @supplierGlAccountType bigint;
	DECLARE @crmSource bigint;
	DECLARE @crmGroup bigint;
	DECLARE @crmRegion bigint;
	DECLARE @crmContact bigint;
	DECLARE @date datetime;
	DECLARE @user nvarchar(20);

	SET @date = GETDATE();
	SET @user = 'WinMan REST API';

	SET @error = '';

	SET @site = (SELECT 
					[Site] 
				FROM 
					EcommerceWebsiteSites ews
					INNER JOIN EcommerceWebsites ew ON ews.EcommerceWebsite = ew.EcommerceWebsite
				WHERE 
					ew.EcommerceWebsiteId = @eCommerceWebsiteId
					AND ews.[Default] = 1);

	IF @site IS NULL
		BEGIN
			SET @error = 'Could not find the specified Website. Please check your input data.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	IF @firstName IS NULL OR @firstName = ''
		BEGIN
			SET @error = 'A required parameter is missing: FirstName.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	IF @lastName IS NULL OR @lastName = ''
		BEGIN
			SET @error = 'A required parameter is missing: LastName.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	SET @name = @firstName + ' ' + @lastName;

	IF @workPhoneNumber IS NULL
		BEGIN
			SET @workPhoneNumber = '';
		END;

	IF @homePhoneNumber IS NULL
		BEGIN
			SET @homePhoneNumber = '';
		END;

	IF @mobilePhoneNumber IS NULL
		BEGIN
			SET @mobilePhoneNumber = '';
		END;

	IF @faxNumber IS NULL
		BEGIN
			SET @faxNumber = '';
		END;

	IF @homeEmailAddress IS NULL
		BEGIN
			SET @homeEmailAddress = '';
		END;

	IF @workEmailAddress IS NULL
		BEGIN
			SET @workEmailAddress = '';
		END;

	IF @jobTitle IS NULL
		BEGIN
			SET @jobTitle = '';
		END;

	IF @address IS NULL OR @address = ''
		BEGIN
			SET @error = 'A required parameter is missing: Address.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	IF @city IS NULL
		BEGIN
			SET @city = '';
		END;

	IF @region IS NULL
		BEGIN
			SET @region = '';
		END;

	IF @postalCode IS NULL OR @postalCode = ''
		BEGIN
			SET @error = 'A required parameter is missing: PostalCode.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	IF @countryCode IS NULL OR @countryCode = ''
		BEGIN
			SET @error = 'A required parameter is missing: CountryCode.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;
	ELSE
		BEGIN
			SET @country = (SELECT TOP 1 Country FROM Countries WHERE ISO3Chars = @countryCode);
		END;

	IF @country IS NULL
		BEGIN
			SET @error = 'Could not find a country with the specified CountryCode. Please check your input data, ensuring you have supplied a valid 3-character code.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	IF @allowCommunication IS NULL
		BEGIN
			SET @error = 'A required parameter is missing: AllowCommunication.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;	

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
		[Site] = @site;

	SELECT
		@customerCurrency = SalesCurrency,
		@supplierCurrency = PurchaseCurrency
	FROM
		ApplicationSettings;

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
		@CreditLimit = null,
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
		@Territory = null,
		@TimeZone = null,
		@WorkSchedule = null,
		@DC_001_TXT = '',
		@DC_002_TXT = '',
		@DC_003_TXT = '',
		@DC_004_TXT = '',
		@DC_005_INT = 0,
		@DC_006_DAT = null,
		@CustomerDiscount = null,
		@SupplierDiscount = null;	

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
		@ContactSupplier = null,
		@ContactCustomer = null,
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
		@CRMContact = @crmContact OUTPUT;

	SET @contact = @crmContact;
	SET @company = @crmCompany;

	SELECT @error AS ErrorMessage, @contact AS CRMContact, @company AS CRMCompany;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
