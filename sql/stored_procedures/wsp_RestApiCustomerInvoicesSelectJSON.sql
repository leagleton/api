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
-- Description:	Stored procedure for SELECTing a customer invoice for the WinMan REST API in JSON format.
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
		AND p.[name] = 'wsp_RestApiCustomerInvoicesSelectJSON'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiCustomerInvoicesSelectJSON AS PRINT ''dbo.wsp_RestApiCustomerInvoicesSelectJSON''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiCustomerInvoicesSelectJSON]
    @website nvarchar(100),
	@customerGuid nvarchar(36) = null,
    @customerId nvarchar(10) = null,
    @customerBranch nvarchar(4) = null,
    @salesInvoiceId nvarchar(25) = null,
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCustomerInvoicesSelectJSON') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiCustomerInvoicesSelectJSON
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

	SELECT @results = COALESCE(
		(SELECT
			STUFF( 
				(SELECT ',{
                        "InvoiceId":"' + REPLACE(SalesInvoices.SalesInvoiceId, '"','&#34;') + '",
                        "InvoiceDate":"' + CONVERT(nvarchar(23), SalesInvoices.EffectiveDate, 126) + '",
                        "InvoiceDueDate":"' + CONVERT(nvarchar(23), SalesInvoices.DueDate, 126) + '",
                        "InvoiceStatus":"' + CASE
                            WHEN SalesInvoices.CurInvoiceValueOutstanding = 0 THEN 'Paid'
                            WHEN SalesInvoices.DueDate < GETDATE() THEN 'Overdue'
                            ELSE 'Outstanding'
                            END + '",
                        "InvoiceTotal":' + CAST(ISNULL(SalesInvoices.CurInvoiceValue, 0) AS nvarchar(23)) + ',
                        "OutstandingBalance":' + CAST(ISNULL(SalesInvoices.CurInvoiceValueOutstanding, 0) AS nvarchar(23)) + ',
                        "CustomerOrderNumber":"' + REPLACE(REPLACE(REPLACE(SalesOrders.CustomerOrderNumber, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
                        "FreightMethodId":"' + REPLACE(FreightMethods.FreightMethodId, '"','&#34;') + '",
						"ShippingValue":' + CAST(ISNULL((SELECT (SUM(CurItemValue) + SUM(CurTaxValue)) FROM SalesOrderItems WHERE SalesOrder = SalesOrders.SalesOrder AND ItemType = 'F'), 0) AS nvarchar(23)) + ',
						"ShippingTaxValue":' + CAST(ISNULL((SELECT SUM(CurTaxValue) FROM SalesOrderItems WHERE SalesOrder = SalesOrders.SalesOrder AND ItemType = 'F'), 0) AS nvarchar(23)) + ',
                        "TotalOrderValue":' + CAST(ISNULL((SELECT (SUM(CurItemValue) + SUM(CurTaxValue)) FROM SalesOrderItems WHERE SalesOrder = SalesOrders.SalesOrder), 0) AS nvarchar(23)) + ',
						"TotalTaxValue":' + CAST(ISNULL((SELECT SUM(CurTaxValue) FROM SalesOrderItems WHERE SalesOrder = SalesOrders.SalesOrder), 0) AS nvarchar(23)) + ',
						"Currency":"' + (SELECT CurrencyId FROM Currencies WHERE Currency = SalesOrders.Currency) + '",'
						+ (SELECT STUFF((SELECT '
												"ShippingName":"' + REPLACE(DeliveryAddresses.DeliveryName, '"','&#34;') + '",
												"ShippingTitle":"' + REPLACE(DeliveryAddresses.Title, '"','&#34;') + '",
												"ShippingFirstName":"' + REPLACE(DeliveryAddresses.FirstName, '"','&#34;') + '",
												"ShippingLastName":"' + REPLACE(DeliveryAddresses.LastName, '"','&#34;') + '",
                                                "ShippingAddress":"' + REPLACE(REPLACE(REPLACE(DeliveryAddresses.[Address], CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
												"ShippingCity":"' + REPLACE(DeliveryAddresses.City, '"','&#34;') + '",
												"ShippingRegion":"' + REPLACE(DeliveryAddresses.Region, '"','&#34;') + '",
												"ShippingPostalCode":"' + REPLACE(DeliveryAddresses.PostalCode, '"','&#34;') + '",
												"ShippingCountryCode":"' + Countries.ISO3Chars + '",
												"ShippingPhoneNumber":"' + REPLACE(DeliveryAddresses.PhoneNumber, '"','&#34;') + '",
												"ShippingEmailAddress":"' + REPLACE(DeliveryAddresses.EmailAddress, '"','&#34;') + '",
												'
											FROM 
												DeliveryAddresses
												INNER JOIN Countries ON DeliveryAddresses.Country = Countries.Country
											WHERE DeliveryAddress = SalesOrders.DeliveryAddress), 1, 0, ''))
						+ (SELECT STUFF((SELECT '
												"BillingName":"' + REPLACE(Customers.CustomerName, '"','&#34;') + '",
												"BillingAddress":"' + REPLACE(REPLACE(REPLACE(Customers.[Address], CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
												"BillingCity":"' + REPLACE(Customers.City, '"','&#34;') + '",
												"BillingRegion":"' + REPLACE(Customers.Region, '"','&#34;') + '",
												"BillingPostalCode":"' + REPLACE(Customers.PostalCode, '"','&#34;') + '",
												"BillingCountryCode":"' + Countries.ISO3Chars + '",
												"BillingPhoneNumber":"' + REPLACE(Customers.PhoneNumber, '"','&#34;') + '",
												"BillingEmailAddress":"' + REPLACE(Customers.EmailAddress, '"','&#34;') + '",
												'
											FROM 
												Customers
												INNER JOIN Countries ON Customers.Country = Countries.Country
											WHERE Customer = SalesOrders.Customer), 1, 0, '')) + '
						"OrderItems":' + 
							COALESCE(
								(SELECT '[' +
									STUFF(
										(SELECT ',{' + 
											CASE WHEN SalesOrderItems.ItemType = 'P'
												THEN 
													'"Sku":"' + REPLACE(Products.ProductId, '"','&#34;') + '",' +
													'"ProductName":"' + REPLACE(REPLACE(REPLACE(Products.ProductDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",'
												ELSE ''
												END +
											CASE WHEN SalesOrderItems.ItemType = 'F'
												THEN '"FreightMethodId":"' + REPLACE(FreightMethods.FreightMethodId, '"','&#34;') + '",'
												ELSE ''
												END +
											CASE WHEN SalesOrderItems.ItemType = 'S'
												THEN '"SundryId":"' + REPLACE(Sundries.SundryId, '"','&#34;') + '",'
												ELSE ''
												END +
											CASE WHEN SalesOrderItems.ItemType = 'N'
												THEN '"FreeTextItem":"' + REPLACE(SalesOrderItems.FreeTextItem, '"','&#34;') + '",'
												ELSE ''
												END +
											CASE SalesOrderItems.ItemType
												WHEN 'N' THEN '"Description":"' + REPLACE(REPLACE(REPLACE(SalesOrderItems.Notes, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",'
												WHEN 'P' THEN '"ShortDescription":"' + REPLACE(REPLACE(REPLACE(Products.WebSummary, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",'
												ELSE '"Description":"' + REPLACE(REPLACE(REPLACE(SalesOrderItems.ItemDescription, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",'
												END + '
											"UnitPrice":' + CAST(SalesOrderItems.CurPrice AS nvarchar(23)) + ',
											"Quantity":' + CAST(SalesOrderItems.Quantity AS nvarchar(23)) + ',
											"LineValue":' + CAST(SalesOrderItems.CurItemValue + SalesOrderItems.CurTaxValue AS nvarchar(23)) + ',
											"LineTaxValue":' + CAST(SalesOrderItems.CurTaxValue AS nvarchar(23)) + ',
											"DiscountAmount":' + CAST(SalesOrderItems.CurDiscountValue AS nvarchar(23)) + '
										}' FROM 
											SalesOrderItems
											LEFT JOIN Products ON Products.Product = SalesOrderItems.Product
											LEFT JOIN FreightMethods ON FreightMethods.FreightMethod = SalesOrderItems.FreightMethod
											LEFT JOIN Sundries ON Sundries.Sundry = SalesOrderItems.Sundry
										WHERE 
											SalesOrderItems.SalesOrder = SalesOrders.SalesOrder
										ORDER BY
											SalesOrderItems.PrintSequence
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
								+ ']'),
							'[]')
						 + '
					}'
					FROM 
						SalesInvoices
	                    INNER JOIN SalesOrders ON SalesOrders.SalesOrder = SalesInvoices.SalesOrder
	                    INNER JOIN FreightMethods ON FreightMethods.FreightMethod = SalesOrders.FreightMethod                        
					WHERE 
						SalesInvoices.SalesInvoice = @salesInvoice
						AND SalesInvoices.Customer = @customer
					FOR XML PATH(''), 
			TYPE).value('.','nvarchar(max)'), 1, 1, '' 
			)), '');

	SELECT @results = REPLACE(REPLACE(REPLACE(REPLACE('{"CustomerInvoices":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), ''), '\', '\\');

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
