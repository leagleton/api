SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 18 December 2017
-- Description:	Stored procedure for SELECting a Customer by CRMContacts.PortalUserName for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiCustomersSelectByPortalUserName'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiCustomersSelectByPortalUserName AS PRINT ''dbo.wsp_RestApiCustomersSelectByPortalUserName''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiCustomersSelectByPortalUserName]
	@eCommerceWebsiteId nvarchar(100),
	@portalUserName nvarchar(50),
	@scope nvarchar(50),
	@error nvarchar(1000) OUTPUT,
	@customerGuid nvarchar(36) OUTPUT,
	@customerId nvarchar(10) OUTPUT,
	@customerBranch nvarchar(4) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCustomersSelectByPortalUserName') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiContactsInsert
				@eCommerceWebsiteId = @eCommerceWebsiteId,
				@portalUserName = @portalUserName,
				@scope = @scope,
				@error = @error OUTPUT,
				@customerGuid = @customerGuid OUTPUT,
				@customerId = @customerID OUTPUT,
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

    IF dbo.wfn_GetProgramProfile('RestApi_CustomerLookup', 'N') = 'N'
        BEGIN
            SET @error = 'The specified WebsiteUserName already exists for the specified Website. If you would like to look up the Customer by the specified WebsiteUserName instead of supplying the CustomerGuid or CustomerId and CustomerBranch, please enable the REST API Program Profile: Allow Customer lookup by CRM Contact Portal User Name. Otherwise, please check your input data.';
            SELECT @error AS ErrorMessage;
            ROLLBACK TRANSACTION;
            RETURN;            
        END;

    SELECT TOP 1
        @customerGuid = Customers.CustomerGUID,
        @customerId = Customers.CustomerId,
        @customerBranch = Customers.Branch
    FROM 
        CRMContacts
        INNER JOIN CRMCompanies ON CRMContacts.CRMCompany = CRMCompanies.CRMCompany
        INNER JOIN Customers ON Customers.Customer = CRMCompanies.Customer
        INNER JOIN EcommerceWebsiteSites ON EcommerceWebsiteSites.[Site] = Customers.[Site]
        INNER JOIN EcommerceWebsites ON EcommerceWebsites.EcommerceWebsite = EcommerceWebsiteSites.EcommerceWebsite
    WHERE 
        LTRIM(RTRIM(CRMContacts.PortalUserName)) = LTRIM(RTRIM(@portalUserName))
        AND EcommerceWebsites.EcommerceWebsiteId = @eCommerceWebsiteId
    ORDER BY
        Customers.Customer;

    IF @customerGuid IS NULL OR @customerGuid = ''
        BEGIN
            SELECT TOP 1
                @customerGuid = Customers.CustomerGUID,
                @customerId = Customers.CustomerId,
                @customerBranch = Customers.Branch
            FROM 
                CRMContacts
                INNER JOIN CRMCompanies ON CRMContacts.CRMCompany = CRMCompanies.CRMCompany
                INNER JOIN Customers ON Customers.Customer = CRMCompanies.Customer
            WHERE 
                LTRIM(RTRIM(CRMContacts.PortalUserName)) = LTRIM(RTRIM(@portalUserName))
                AND Customers.[Site] IS NULL
            ORDER BY
                Customers.Customer;
        END;

    IF @customerGuid IS NULL OR @customerGuid = ''
        BEGIN
            SET @error = 'Could not find a matching Customer. Please check your input data.';
            SELECT @error AS ErrorMessage;
            ROLLBACK TRANSACTION;
            RETURN;
        END;

	SELECT @error AS ErrorMessage, @customerGuid AS CustomerGUID, @customerId AS CustomerId, @customerBranch AS CustomerBranch;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
