SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 12 December 2017
-- Description:	Stored procedure for promoting a CRM Company to Customer for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiCompaniesPromote'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiCompaniesPromote AS PRINT ''dbo.wsp_RestApiCompaniesPromote''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiCompaniesPromote]
	@eCommerceWebsiteId nvarchar(100),
	@crmCompany bigint,
	@scope nvarchar(50),
	@error nvarchar(1000) OUTPUT,
	@customerGuid nvarchar(36) OUTPUT,
	@customerId nvarchar(10) OUTPUT,
	@customerBranch nvarchar(4) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCompaniesPromote') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiCompaniesPromote
				@eCommerceWebsiteId = @eCommerceWebsiteId,
				@crmCompany = @crmCompany,
				@scope = @scope,
				@error = @error OUTPUT,
				@customerGuid = @customerGuid OUTPUT,
				@customerId = @customerId OUTPUT,
				@customerBranch = @customerBranch OUTPUT;
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

    IF NOT EXISTS (SELECT 
				    CRMCompanyId
				FROM 
					CRMCompanies
				WHERE 
					CRMCompany = @crmCompany)
        BEGIN
            SET @error = 'Could not find the specified CRM Company. Please check your input data.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
        END;

    DECLARE @site bigint;

    SELECT
	    @site = [Site]
    FROM
	    EcommerceWebsiteSites ews
	    INNER JOIN EcommerceWebsites ew ON ew.EcommerceWebsite = ews.EcommerceWebsite
    WHERE
        ew.EcommerceWebsiteId = @eCommerceWebsiteId
        AND ews.[Default] = 1;

    DECLARE @customerIdLength int;
    DECLARE @customerIdPrefix nvarchar(5);
    DECLARE @nextNumber int;

	SET @customerIdLength = dbo.wfn_GetProgramProfile('Customers_CustomerIdLength', 6);
	SET @customerIdPrefix= dbo.wfn_GetProgramProfile('Customers_CustomerIdPrefix', 'C');
	SET @nextNumber = CONVERT(int, ISNULL((SELECT 
                                        MAX(SUBSTRING(CustomerId, LEN(@customerIdPrefix) + 1, LEN(CustomerId) - LEN(@customerIdPrefix))) + 1
                                    FROM 
                                        Customers 
                                    WHERE 
                                        CustomerId LIKE @customerIdPrefix + '%'
                                        AND ISNUMERIC(SUBSTRING(CustomerId, LEN(@customerIdPrefix) + 1, LEN(CustomerId)- LEN(@customerIdPrefix))) = 1),1));

    SET @customerId = dbo.wfn_IdentifierExtender(@customerIdLength, @nextNumber, @customerIdPrefix)

	EXEC dbo.wsp_CRMCompaniesPromoteToCustomer
	    @CRMCompany = @crmCompany,
		@SalesOrder = null,
		@CustomerId = @customerId,
		@CreatedUser = 'WinMan REST API',
		@ReselectRecord = 0,
		@Site = @site,
		@Branch = null,
		@PromptText = '';
		
	SELECT TOP 1
		@customerGuid = cust.CustomerGUID,
        @customerId = cust.CustomerId,
        @customerBranch = cust.Branch
	FROM 
        CRMCompanies comp
        INNER JOIN Customers cust ON comp.Customer = cust.Customer
	WHERE 
        comp.CRMCompany = @crmCompany
    ORDER BY
        comp.CRMCompany DESC;

	SELECT @error AS ErrorMessage, @customerGuid AS CustomerGUID, @customerId AS CustomerId, @customerBranch AS CustomerBranch;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
