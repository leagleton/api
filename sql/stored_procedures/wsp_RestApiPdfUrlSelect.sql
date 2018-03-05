SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 22 February 2018
-- Description:	Stored procedure for SELECTing an SSRS URL for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiPdfUrlSelect'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiPdfUrlSelect AS PRINT ''dbo.wsp_RestApiPdfUrlSelect''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiPdfUrlSelect]
    @website nvarchar(100),
	@customerGuid nvarchar(36) = null,
    @customerId nvarchar(10) = null,
    @customerBranch nvarchar(4) = null,
    @reportType nvarchar(15) = 'Acknowledgement',
    @parameterName nvarchar(15) = 'SalesOrderId',
    @parameterValue nvarchar(25) = null,
	@scope nvarchar(50),
	@results nvarchar(200) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiPdfUrlSelect') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiPdfUrlSelect
                @website = @website,
				@customerGuid = @customerGuid,
                @customerId = @customerId,
                @customerBranch = @customerBranch,
                @reportType = @reportType,
                @parameterName = @parameterName,
                @parameterValue = @parameterValue,
				@scope = @scope,
				@results = @results OUTPUT;
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
			SELECT 'The relevant REST API scope is not enabled for the specified website.' AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

    DECLARE @customer bigint;
    DECLARE @site bigint;
    DECLARE @salesOrder bigint;
    DECLARE @salesInvoice bigint;

	IF @customerGuid IS NULL OR @customerGuid = ''
		IF (@customerId IS NULL OR @customerId = '') AND (@customerBranch IS NULL OR @customerBranch = '')
			BEGIN
				SELECT 'A required parameter is missing. If customerguid is not supplied, both customerid and customerbranch must be supplied.' AS ErrorMessage;
				ROLLBACK TRANSACTION;
                RETURN;
			END;
        ELSE
            BEGIN
                SELECT
                    @customer = Customer,
                    @customerGuid = CustomerGUID
                FROM
                    Customers
                WHERE
                    CustomerId = @customerId
                    AND Branch = @customerBranch;
            END;       
	ELSE
        BEGIN
            SELECT
                @customer = Customer,
                @customerId = CustomerId,
                @customerBranch = Branch
            FROM
                Customers
            WHERE
                CustomerGUID = @customerGuid;        
        END;

	IF @customer IS NULL
		BEGIN
			SELECT 'Could not find specified customer. Please check your input data.' AS ErrorMessage;
            ROLLBACK TRANSACTION;
			RETURN;		
		END;

    IF (@parameterValue IS NULL OR @parameterValue = '') AND @reportType <> 'Statement'
        BEGIN
			SELECT 
                CASE @reportType 
                    WHEN 'Acknowledgement' THEN 'A required parameter is missing: salesorderid.'
                    WHEN 'Quotation' THEN 'A required parameter is missing: quoteid.'
                    WHEN 'Sales%20Invoice' THEN 'A required parameter is missing: salesinvoiceid.'
                END AS ErrorMessage;
			ROLLBACK TRANSACTION;
            RETURN;
        END;

    SET @site = (SELECT [Site] FROM Customers WHERE Customer = @customer);

    IF @site IS NULL
        BEGIN
            SET @site = (SELECT DefaultSite FROM ApplicationSettings);
        END;

    IF @reportType = 'Acknowledgement'
        BEGIN
            SET @salesOrder = (SELECT SalesOrder FROM SalesOrders WHERE SalesOrderId = @parameterValue AND Customer = @customer ANd SystemType LIKE '[^Q]');

            IF @salesOrder IS NULL
                BEGIN
                    SELECT 'Could not find specified sales order. Please check your input data.' AS ErrorMessage;
                    ROLLBACK TRANSACTION;
                    RETURN;
                END;           
        END;

    IF @reportType = 'Quotation'
        BEGIN
            SET @salesOrder = (SELECT SalesOrder FROM SalesOrders WHERE SalesOrderId = @parameterValue AND Customer = @customer AND SystemType = 'Q');

            IF @salesOrder IS NULL
                BEGIN
                    SELECT 'Could not find specified quote. Please check your input data.' AS ErrorMessage;
                    ROLLBACK TRANSACTION;
                    RETURN;
                END;           
        END;

    IF @reportType = 'Sales%20Invoice'
        BEGIN
            SET @salesInvoice = (SELECT SalesInvoice FROM SalesInvoices WHERE SalesInvoiceId = @parameterValue AND Customer = @customer AND SourceType = 'I');

            IF @salesInvoice IS NULL
                BEGIN
                    SELECT 'Could not find specified sales invoice. Please check your input data.' AS ErrorMessage;
                    ROLLBACK TRANSACTION;
                    RETURN;
                END;           
        END;        

	SELECT @results = (SELECT
                            ApplicationSettings.ReportServer
                            + '?/' + DB_NAME() + '/StandardPrints/' 
                            + @reportType 
                            + '&rs:Command=Render&rs:Format=PDF'
                            + '&' +
                            CASE 
                                WHEN @reportType <> 'Statement' THEN @parameterName + '=' + @parameterValue
                                ELSE 'CustomerId=' + @customerId
                            END
                            + '&Site='
                            + CAST(@site AS nvarchar(10))                            
                        FROM
                            ApplicationSettings)

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
