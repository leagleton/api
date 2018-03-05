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
-- Description:	Stored procedure for SELECTing customer sales order or quotes for the WinMan REST API in JSON format.
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
		AND p.[name] = 'wsp_RestApiSalesOrdersSelectJSON'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiSalesOrdersSelectJSON AS PRINT ''dbo.wsp_RestApiSalesOrdersSelectJSON''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiSalesOrdersSelectJSON]
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

	IF dbo.wfn_BespokeSPExists('bsp_RestApiSalesOrdersSelectJSON') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiSalesOrdersSelectJSON
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

	SELECT @results = COALESCE(
		(SELECT
			STUFF( 
				(SELECT ',{
						"' + CASE WHEN @systemType = 'O' THEN 'SalesOrderId' ELSE 'QuoteId' END + '":"' + REPLACE(so.SalesOrderId, '"','&#34;') + '",
                        "CustomerOrderNumber":"' + REPLACE(REPLACE(REPLACE(so.CustomerOrderNumber, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
                        "' + CASE WHEN @systemType = 'O' THEN 'OrderDate' ELSE 'QuoteDate' END + '":"' + CONVERT(nvarchar(23), so.EffectiveDate, 126) + '",
                        "' + CASE WHEN @systemType = 'O' THEN 'TotalOrderValue' ELSE 'TotalQuoteValue' END + '":'
                            + CAST(ISNULL((SELECT SUM(CurItemValue) + SUM(CurTaxValue) FROM SalesOrderItems WHERE SalesOrder = so.SalesOrder), 0) AS nvarchar(23)) + ',
                        "TotalTaxValue": ' + CAST(ISNULL((SELECT SUM(CurTaxValue) FROM SalesOrderItems WHERE SalesOrder = so.SalesOrder), 0) AS nvarchar(23)) + ','
                        + CASE WHEN @systemType = 'O' 
                            THEN '"OrderStatus":"' 
                                + CASE so.SystemType 
									WHEN 'N' THEN 'New'
                                    WHEN 'F' THEN 'In Progress'
                                    WHEN 'P' THEN 'In Picking'
                                    WHEN 'H' THEN 'Held'
                                    WHEN 'C' THEN 'Shipped'
									ELSE ''
                                    END
                                + '",'
                        	END
                        + CASE WHEN @systemType = 'Q' 
                            THEN '"QuoteStatus":"' 
                                + CASE WHEN so.QuoteExpiry <= GETDATE()
                                    THEN 'Expired'
									ELSE 'Active'
                                    END
                                + '",'
							ELSE ''
                        	END +
						+ CASE WHEN @systemType = 'O'
							THEN 
								'"TrackingNumber":"' + COALESCE((SELECT TOP 1 
																	REPLACE(DeliveryReference, '"','&#34;') 
																FROM 
																	Shipments 
																WHERE 
																	Shipments.SalesOrder = so.SalesOrder 
																ORDER BY Shipment DESC), '') + '",
								"TrackingUrl":"' + COALESCE((SELECT TOP 1 
														REPLACE(TrackingURL, '"','&#34;')
													FROM 
														Shipments 
														LEFT JOIN FreightMethods ON FreightMethods.FreightMethod = Shipments.FreightMethod
													WHERE 
														Shipments.SalesOrder = so.SalesOrder 			
													ORDER BY Shipment DESC), '') + '",'							
							ELSE ''
							END			
						+ CASE WHEN @systemType = 'O' 
							THEN '"PaymentType":"' + COALESCE((SELECT TOP 1
															REPLACE(CreditCardTypeId, '"','&#34;')
														FROM
															CreditCardTypes
															INNER JOIN CreditCards ON CreditCardTypes.CreditCardType = CreditCards.CreditCardType
															INNER JOIN CreditCardTransactions ON CreditCards.CreditCard = CreditCardTransactions.CreditCard
														WHERE
															CreditCardTransactions.SalesOrder = so.SalesOrder), '') + '",'
							ELSE ''
							END + '
						"Currency":"' + (SELECT CurrencyId FROM Currencies WHERE Currency = so.Currency) + '",
						"CustomerContact":"' + REPLACE(so.CustomerContact, '"','&#34;') + '",
                        "FreightMethodId":"' + (SELECT REPLACE(FreightMethodId, '"','&#34;') FROM FreightMethods WHERE FreightMethod = so.FreightMethod) + '",
						"ShippingValue":' + CAST(ISNULL((SELECT (SUM(CurItemValue) + SUM(CurTaxValue)) FROM SalesOrderItems WHERE SalesOrder = so.SalesOrder AND ItemType = 'F'), 0) AS nvarchar(23)) + ',
						"ShippingTaxValue":' + CAST(ISNULL((SELECT SUM(CurTaxValue) FROM SalesOrderItems WHERE SalesOrder = so.SalesOrder AND ItemType = 'F'), 0) AS nvarchar(23)) + ',
						' + (SELECT STUFF((SELECT '
												"ShippingName":"' + REPLACE(DeliveryAddresses.DeliveryName, '"','&#34;') + '",
												"ShippingTitle":"' + REPLACE(DeliveryAddresses.Title, '"','&#34;') + '",
												"ShippingFirstName":"' + REPLACE(DeliveryAddresses.FirstName, '"','&#34;') + '",
												"ShippingLastName":"' + REPLACE(DeliveryAddresses.LastName, '"','&#34;') + '",							"ShippingAddress":"' + REPLACE(REPLACE(REPLACE(DeliveryAddresses.[Address], CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
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
											WHERE DeliveryAddress = so.DeliveryAddress), 1, 0, '')) +
						(SELECT STUFF((SELECT '
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
											WHERE Customer = so.Customer), 1, 0, '')) + '
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
											SalesOrderItems.SalesOrder = so.SalesOrder
										ORDER BY
											SalesOrderItems.PrintSequence
										FOR XML PATH(''),
										TYPE).value('.','nvarchar(max)'), 1, 1, '')
								+ ']'),
							'[]')
						 + '
					}'
					FROM 
						CTE AS so
					WHERE 
						(rowNumber > @pageSize * (@pageNumber - 1) )
						AND (rowNumber <= @pageSize * @pageNumber )
					ORDER BY
						rowNumber 
					FOR XML PATH(''), 
			TYPE).value('.','nvarchar(max)'), 1, 1, '' 
			)), '');

	SELECT @results = REPLACE(REPLACE(REPLACE(REPLACE('{"CustomerOrders":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), ''), '\', '\\');

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
