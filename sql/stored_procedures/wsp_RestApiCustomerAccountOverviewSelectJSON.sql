SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 20 February 2018
-- Description:	Stored procedure for SELECTing customer account overview for the WinMan REST API in JSON format.
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
		AND p.[name] = 'wsp_RestApiCustomerAccountOverviewSelectJSON'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiCustomerAccountOverviewSelectJSON AS PRINT ''dbo.wsp_RestApiCustomerAccountOverviewSelectJSON''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiCustomerAccountOverviewSelectJSON]
    @website nvarchar(100),
	@customerGuid nvarchar(36) = null,
    @customerId nvarchar(10) = null,
    @customerBranch nvarchar(4) = null,
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCustomerAccountOverviewSelectJSON') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiCustomerAccountOverviewSelectJSON
				@website = @website,
				@customerGuid = @customerGuid,
                @customerBranch = @customerBranch,
                @customerId = @customerId,
				@scope = @scope,
				@results = @results OUTPUT;
			RETURN;	
		END;


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
			SELECT 'The relevant REST API scope is not enabled for the specified website.' AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

    DECLARE @customer bigint;

	IF @customerGuid IS NULL OR @customerGuid = ''
		IF (@customerId IS NULL OR @customerId = '') AND (@customerBranch IS NULL OR @customerBranch = '')
			BEGIN
				SELECT 'A required parameter is missing. If customerguid is not supplied, both customerid and customerbranch must be supplied.' AS ErrorMessage;
				ROLLBACK TRANSACTION;
                RETURN;
			END;
        ELSE
            BEGIN
                SET @customer = (SELECT
                                    Customer
                                FROM
                                    Customers
                                WHERE
                                    CustomerId = @customerId
                                    AND Branch = @customerBranch);
            END;       
	ELSE
        BEGIN
            SET @customer = (SELECT
                                Customer
                            FROM
                                Customers
                            WHERE
                                CustomerGUID = @customerGuid);
        END;

	IF @customer IS NULL
		BEGIN
			SELECT 'Could not find specified customer. Please check your input data.' AS ErrorMessage;
            ROLLBACK TRANSACTION;
			RETURN;		
		END; 

	SELECT @results = COALESCE(
		(SELECT
			STUFF( 
				(SELECT ',{
						"CustomerGuid":"' + CAST(Customers.CustomerGUID AS nvarchar(36)) + '",
						"CustomerId":"' + REPLACE(Customers.CustomerId, '"','&#34;') + '",
						"CustomerBranch":"' + REPLACE(Customers.Branch, '"','&#34;') + '",
						"AccountStatus":"' + COALESCE(REPLACE(CreditTerms.CreditTermsId, '"','&#34;'), '') + '",
						"AccountBalance":"' + CAST(ISNULL((SELECT SUM(SalesInvoices.CurInvoiceValueOutstanding) FROM SalesInvoices WHERE SalesInvoices.Customer = Customers.Customer), 0) AS nvarchar(23)) + '",
						"OverdueBalance":"' + CAST(ISNULL((SELECT SUM(SalesInvoices.CurInvoiceValueOutstanding) FROM SalesInvoices WHERE SalesInvoices.Customer = Customers.Customer AND SalesInvoices.DueDate <= GETDATE()), 0) AS nvarchar(23)) + '"
					}' 
					FROM Customers
						LEFT JOIN CreditTerms ON CreditTerms.CreditTerms = Customers.CreditTerms
					WHERE
						Customers.Customer = @customer
					GROUP BY
						Customers.Customer,
						Customers.CustomerGUID,
						Customers.CustomerId,
						Customers.Branch,
						CreditTerms.CreditTermsId
					FOR XML PATH(''), 
			TYPE).value('.','nvarchar(max)'), 1, 1, '' 
			)), '');

	SELECT @results = REPLACE(REPLACE(REPLACE(REPLACE('{"CustomerAccountOverviews":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), ''), '\', '\\');

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
