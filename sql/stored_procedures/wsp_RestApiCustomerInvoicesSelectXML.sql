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
-- Description:	Stored procedure for SELECTing customer sales order or quotes for the WinMan REST API in XML format.
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
		AND p.[name] = 'wsp_RestApiCustomerInvoicesSelectXML'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiCustomerInvoicesSelectXML AS PRINT ''dbo.wsp_RestApiCustomerInvoicesSelectXML''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiCustomerInvoicesSelectXML]
    @website nvarchar(100),
	@customerGuid nvarchar(36) = null,
    @customerId nvarchar(10) = null,
    @customerBranch nvarchar(4) = null,
    @salesInvoiceId nvarchar(25) = null,
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCustomerInvoicesSelectXML') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiCustomerInvoicesSelectXML
                @website = @website,
				@customerGuid = @customerGuid,
                @customerId = @customerId,
                @customerBranch = @customerBranch,
                @salesInvoiceId = @salesInvoiceId,
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

    IF @salesInvoiceId IS NULL OR @salesInvoiceId = ''
        BEGIN
			SELECT 'A required parameter is missing: salesinvoiceid.' AS ErrorMessage;
			ROLLBACK TRANSACTION;
            RETURN;
        END;
    ELSE
        BEGIN
            SET @salesInvoice = (SELECT
                                    SalesInvoice
                                FROM
                                    SalesInvoices
                                WHERE
                                    SalesInvoiceId = @salesInvoiceId
                                    AND SalesInvoices.SourceType = 'I');
        END;

    IF @salesInvoice IS NULL
        BEGIN
			SELECT 'Could not find specified sales invoice. Please check your input data.' AS ErrorMessage;
            ROLLBACK TRANSACTION;
			RETURN;
        END;        

	SELECT @results = 
		CONVERT(nvarchar(max), (SELECT
            SalesInvoices.SalesInvoiceId AS InvoiceId,
			SalesOrders.SalesOrderId AS SalesOrderId,
            SalesInvoices.EffectiveDate AS InvoiceDate,
            SalesInvoices.DueDate AS InvoiceDueDate,
            CASE
                WHEN SalesInvoices.CurInvoiceValueOutstanding = 0 THEN 'Paid'
                WHEN SalesInvoices.DueDate < GETDATE() THEN 'Overdue'
                ELSE 'Outstanding'
            END AS InvoiceStatus,
            ISNULL(SalesInvoices.CurInvoiceValue, 0) AS InvoiceTotal,
            ISNULL(SalesInvoices.CurInvoiceValueOutstanding, 0) AS OutstandingBalance,
            SalesOrders.CustomerOrderNumber,
            FreightMethods.FreightMethodId,
			ISNULL((SELECT (SUM(CurItemValue) + SUM(CurTaxValue)) FROM SalesInvoiceItems WHERE SalesInvoice = SalesInvoices.SalesInvoice AND ItemType = 'F'), 0) AS ShippingValue,
			ISNULL((SELECT SUM(CurTaxValue) FROM SalesInvoiceItems WHERE SalesInvoice = SalesInvoices.SalesInvoice AND ItemType = 'F'), 0) AS ShippingTaxValue,
			ISNULL((SELECT (SUM(CurItemValue) + SUM(CurTaxValue)) FROM SalesInvoiceItems WHERE SalesInvoice = SalesInvoices.SalesInvoice AND ItemType <> 'T'), 0) AS TotalOrderValue,
			ISNULL((SELECT SUM(CurTaxValue) FROM SalesInvoiceItems WHERE SalesInvoice = SalesInvoices.SalesInvoice), 0) AS TotalTaxValue,             
            (SELECT CurrencyId FROM Currencies WHERE Currency = SalesOrders.Currency) AS Currency,
            DeliveryAddresses.DeliveryName AS ShippingName,
			DeliveryAddresses.[Address] AS ShippingAddress,
			DeliveryAddresses.Title AS ShippingTitle,
			DeliveryAddresses.FirstName AS ShippingFirstName,
			DeliveryAddresses.LastName AS ShippingLastName,
			DeliveryAddresses.City AS ShippingCity,
			DeliveryAddresses.Region AS ShippingRegion,
			DeliveryAddresses.PostalCode AS ShippingPostalCode,
			(SELECT Countries.ISO3Chars FROM Countries WHERE Countries.Country = DeliveryAddresses.Country) AS ShippingCountryCode,
			DeliveryAddresses.PhoneNumber AS ShippingPhoneNumber,
			DeliveryAddresses.EmailAddress AS ShippingEmailAddress,
			Customers.CustomerName AS BillingName,
			Customers.[Address] AS BillingAddress,
			Customers.City AS BillingCity,
			Customers.Region AS BillingRegion,
			Customers.PostalCode AS BillingPostalCode,
			(SELECT Countries.Country FROM Countries WHERE Countries.Country = Customers.Country) AS BillingCountryCode,
			Customers.PhoneNumber AS BillingPhoneNumber,
			Customers.EmailAddress AS BillingEmailAddress,
			(SELECT
				CASE WHEN SalesInvoiceItems.ItemType = 'P'
					THEN Products.ProductId
				END AS Sku,
				CASE WHEN SalesInvoiceItems.ItemType = 'P'
					THEN Products.ProductDescription
				END AS ProductName,	
				CASE WHEN SalesInvoiceItems.ItemType = 'F'
					THEN FreightMethods.FreightMethodId
				END AS FreightMethodId,
				CASE WHEN SalesInvoiceItems.ItemType = 'S'
					THEN Sundries.SundryId
				END AS SundryId,
				CASE WHEN SalesInvoiceItems.ItemType = 'N'
					THEN SalesInvoiceItems.FreeTextItem
				END AS FreeTextItem,
				CASE WHEN SalesInvoiceItems.ItemType LIKE '[FSN]'
					THEN SalesInvoiceItems.ItemDescription
				END AS [Description],
				CASE WHEN SalesInvoiceItems.ItemType = 'P'
					THEN Products.WebSummary
				END AS ShortDescription,		
				SalesInvoiceItems.CurPrice AS UnitPrice,
				SalesInvoiceItems.Quantity AS Quantity,
				(SalesInvoiceItems.CurItemValue + SalesInvoiceItems.CurTaxValue) AS LineValue,
				SalesInvoiceItems.CurTaxValue AS LineTaxValue,
				SalesInvoiceItems.CurDiscountValue AS DiscountAmount
			FROM
				SalesInvoiceItems
				LEFT JOIN Products ON Products.Product = SalesInvoiceItems.Product
				LEFT JOIN FreightMethods ON FreightMethods.FreightMethod = SalesInvoiceItems.FreightMethod
				LEFT JOIN Sundries ON Sundries.Sundry = SalesInvoiceItems.Sundry
			WHERE
				SalesInvoiceItems.SalesInvoice = SalesInvoices.SalesInvoice
			ORDER BY
				SalesInvoiceItems.PrintSequence
			FOR XML PATH('InvoiceItem'), TYPE) AS InvoiceItems,
			'' AS InvoiceItems		
		FROM
			SalesInvoices
            INNER JOIN SalesOrders ON SalesOrders.SalesOrder = SalesInvoices.SalesOrder
            INNER JOIN FreightMethods ON FreightMethods.FreightMethod = SalesOrders.FreightMethod
            INNER JOIN DeliveryAddresses ON DeliveryAddresses.DeliveryAddress = SalesOrders.DeliveryAddress
            INNER JOIN Customers ON Customers.Customer = SalesOrders.Customer
		WHERE
			SalesInvoices.SalesInvoice = @salesInvoice
            AND SalesInvoices.Customer = @customer
		FOR XML PATH('CustomerInvoice'), TYPE));

	IF @results IS NOT NULL AND @results <> ''
		BEGIN
			SELECT @results = '<CustomerInvoices>' + @results + '</CustomerInvoices>';
		END;
	ELSE
		BEGIN
			SELECT @results = '<CustomerInvoices/>';
		END;

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
