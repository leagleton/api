SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 February 2018
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
		AND p.[name] = 'wsp_RestApiSalesOrdersSelectXML'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiSalesOrdersSelectXML AS PRINT ''dbo.wsp_RestApiSalesOrdersSelectXML''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiSalesOrdersSelectXML]
	@pageNumber int = 1,
	@pageSize int = 10,
    @website nvarchar(100),
	@customerGuid nvarchar(36) = null,
    @customerId nvarchar(10) = null,
    @customerBranch nvarchar(4) = null,
    @systemType char(1) = 'O',
    @orderBy nvarchar(19) = 'SalesOrderId',
    @salesOrderId nvarchar(15) = null,
    @customerOrderNumber nvarchar(50) = null,
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiSalesOrdersSelectXML') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiSalesOrdersSelectXML
				@pageNumber = @pageNumber,
				@pageSize = @pageSize,
                @website = @website,
				@customerGuid = @customerGuid,
                @customerId = @customerId,
                @customerBranch = @customerBranch,
                @systemType = @systemType,
                @orderBy = @orderBy,
                @salesOrderId = @salesOrderId,
                @customerOrderNumber = @customerOrderNumber,
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

	WITH CTE AS
	(
		SELECT
			ROW_NUMBER() OVER (ORDER BY 
                                CASE @orderBy
                                    WHEN 'CustomerOrderNumber' THEN so.CustomerOrderNumber
                                    WHEN 'EffectiveDate' THEN CAST(so.EffectiveDate AS nvarchar(23))
                                    WHEN 'SystemType' THEN so.SystemType
                                    WHEN 'OrderValue' THEN CAST(so.OrderValue AS nvarchar(25))
                                    ELSE so.SalesOrderId
                                END) AS rowNumber,
			so.SalesOrderId,
            so.SalesOrder,
            so.CustomerOrderNumber,
            so.EffectiveDate,
            so.SystemType,
            so.OrderValue,
            so.FreightMethod,
			so.Currency,
			so.QuoteExpiry,
			so.Customer,
			so.CustomerContact,
			so.DeliveryAddress
		FROM 
			SalesOrders so
		WHERE 
			so.Customer = @customer
			AND so.SystemType LIKE CASE WHEN @systemType = 'Q' THEN 'Q' ELSE '[^Q]' END
		GROUP BY
			so.SalesOrderId,
            so.SalesOrder,
            so.CustomerOrderNumber,
            so.EffectiveDate,
            so.SystemType,
            so.OrderValue,
            so.FreightMethod,
			so.Currency,
			so.QuoteExpiry,
			so.Customer,
			so.CustomerContact,
			so.DeliveryAddress
	)

	SELECT @results = 
		CONVERT(nvarchar(max), (SELECT
			CASE WHEN @systemType = 'O' 
				THEN so.SalesOrderId
			END AS SalesOrderId,
			CASE WHEN @systemType = 'Q' 
				THEN so.SalesOrderId
			END AS QuoteId,
			so.CustomerOrderNumber,
			CASE WHEN @systemType = 'O' 
				THEN so.EffectiveDate
			END AS OrderDate,
			CASE WHEN @systemType = 'Q' 
				THEN so.EffectiveDate
			END AS QuoteDate,
			CASE WHEN @systemType = 'O' 
				THEN ISNULL((SELECT SUM(CurItemValue) + SUM(CurTaxValue) FROM SalesOrderItems WHERE SalesOrder = so.SalesOrder), 0)
			END AS TotalOrderValue,
			CASE WHEN @systemType = 'Q' 
				THEN ISNULL((SELECT SUM(CurItemValue) + SUM(CurTaxValue) FROM SalesOrderItems WHERE SalesOrder = so.SalesOrder), 0)
			END AS TotalQuoteValue,
			ISNULL((SELECT SUM(CurTaxValue) FROM SalesOrderItems WHERE SalesOrder = so.SalesOrder), 0) AS TotalTaxValue,
			CASE WHEN @systemType = 'O'
				THEN
					CASE so.SystemType
						WHEN 'N' THEN 'New'
                    	WHEN 'F' THEN 'In Progress'
                        WHEN 'P' THEN 'In Picking'
                        WHEN 'H' THEN 'Held'
                        WHEN 'C' THEN 'Shipped'
						ELSE ''
                    END
			END AS OrderStatus,
			CASE WHEN @systemType = 'Q'
				THEN
					CASE WHEN so.QuoteExpiry <= GETDATE()
						THEN 'Expired'
						ELSE 'Active'
					END
			END AS QuoteStatus,
			CASE WHEN @systemType = 'O'
				THEN COALESCE((SELECT TOP 1
									DeliveryReference
								FROM 
									Shipments
								WHERE
									Shipments.SalesOrder = so.SalesOrder 
								ORDER BY Shipment DESC), '')
			END AS TrackingNumber,
			CASE WHEN @systemType = 'O'
				THEN COALESCE((SELECT TOP 1
									TrackingURL
								FROM 
									Shipments
									LEFT JOIN FreightMethods ON FreightMethods.FreightMethod = Shipments.FreightMethod
								WHERE
									Shipments.SalesOrder = so.SalesOrder 
								ORDER BY Shipment DESC), '')
			END AS TrackingUrl,
			CASE WHEN @systemType = 'O'
				THEN (SELECT TOP 1
							CreditCardTypeId
						FROM
							CreditCardTypes
							INNER JOIN CreditCards ON CreditCardTypes.CreditCardType = CreditCards.CreditCardType
							INNER JOIN CreditCardTransactions ON CreditCards.CreditCard = CreditCardTransactions.CreditCard
						WHERE
							CreditCardTransactions.SalesOrder = so.SalesOrder)
			END	AS PaymentType,
			CASE WHEN @systemType = 'O'
				THEN ''
			END AS PaymentType,
			(SELECT CurrencyId FROM Currencies WHERE Currency = so.Currency) AS Currency,
			so.CustomerContact,			
			(SELECT FreightMethodId FROM FreightMethods WHERE FreightMethod = so.FreightMethod) AS FreightMethodId,
			ISNULL((SELECT (SUM(CurItemValue) + SUM(CurTaxValue)) FROM SalesOrderItems WHERE SalesOrder = so.SalesOrder AND ItemType = 'F'), 0) AS ShippingValue,
			ISNULL((SELECT SUM(CurTaxValue) FROM SalesOrderItems WHERE SalesOrder = so.SalesOrder AND ItemType = 'F'), 0) AS ShippingTaxValue,
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
				CASE WHEN SalesOrderItems.ItemType = 'P'
					THEN Products.ProductId
				END AS Sku,
				CASE WHEN SalesOrderItems.ItemType = 'P'
					THEN Products.ProductDescription
				END AS ProductName,	
				CASE WHEN SalesOrderItems.ItemType = 'F'
					THEN FreightMethods.FreightMethodId
				END AS FreightMethodId,
				CASE WHEN SalesOrderItems.ItemType = 'S'
					THEN Sundries.SundryId
				END AS SundryId,
				CASE WHEN SalesOrderItems.ItemType = 'N'
					THEN SalesOrderItems.FreeTextItem
				END AS FreeTextItem,
				CASE WHEN SalesOrderItems.ItemType LIKE '[FS]'
					THEN SalesOrderItems.ItemDescription
				END AS [Description],
				CASE WHEN SalesOrderItems.ItemType = 'N'
					THEN SalesOrderItems.Notes
				END AS [Description],
				CASE WHEN SalesOrderItems.ItemType = 'P'
					THEN Products.WebSummary
				END AS ShortDescription,		
				SalesOrderItems.CurPrice AS UnitPrice,
				SalesOrderItems.Quantity AS Quantity,
				(SalesOrderItems.CurItemValue + SalesOrderItems.CurTaxValue) AS LineValue,
				SalesOrderItems.CurTaxValue AS LineTaxValue,
				SalesOrderItems.CurDiscountValue AS DiscountAmount
			FROM
				SalesOrderItems
				LEFT JOIN Products ON Products.Product = SalesOrderItems.Product
				LEFT JOIN FreightMethods ON FreightMethods.FreightMethod = SalesOrderItems.FreightMethod
				LEFT JOIN Sundries ON Sundries.Sundry = SalesOrderItems.Sundry
			WHERE
				SalesOrderItems.SalesOrder = so.SalesOrder
			ORDER BY
				SalesOrderItems.PrintSequence
			FOR XML PATH('OrderItem'), TYPE) AS OrderItems,
			'' AS OrderItems		
		FROM
			CTE AS so
			INNER JOIN DeliveryAddresses ON DeliveryAddresses.DeliveryAddress = so.DeliveryAddress
			INNER JOIN Customers ON Customers.Customer = so.Customer
		WHERE
			(rowNumber > @pageSize * (@pageNumber - 1))
			AND (rowNumber <= @pageSize * @pageNumber)
		ORDER BY
			rowNumber
		FOR XML PATH('CustomerOrder'), TYPE));	

	IF @results IS NOT NULL AND @results <> ''
		BEGIN
			SELECT @results = '<CustomerOrders>' + @results + '</CustomerOrders>';
		END;
	ELSE
		BEGIN
			SELECT @results = '<CustomerOrders/>';
		END;

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
