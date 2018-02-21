SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 21 February 2018
-- Description:	Stored procedure for SELECTing customer statements for the WinMan REST API in JSON format.
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
		AND p.[name] = 'wsp_RestApiCustomerStatementsSelectJSON'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiCustomerStatementsSelectJSON AS PRINT ''dbo.wsp_RestApiCustomerStatementsSelectJSON''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiCustomerStatementsSelectJSON]
	@pageNumber int = 1,
	@pageSize int = 20,
    @website nvarchar(100),
	@customerGuid nvarchar(36) = null,
    @customerId nvarchar(10) = null,
    @customerBranch nvarchar(4) = null,
	@outstanding bit = 0,
    @orderBy nvarchar(19) = 'SalesInvoiceId',
    @salesInvoiceId nvarchar(25) = null,
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiCustomerStatementsSelectJSON') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiCustomerStatementsSelectJSON
				@pageNumber = @pageNumber,
				@pageSize = @pageSize,
                @website = @website,
				@customerGuid = @customerGuid,
                @customerId = @customerId,
                @customerBranch = @customerBranch,
                @orderBy = @orderBy,
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
			SalesInvoices.SalesInvoiceId,
			SalesInvoices.EffectiveDate,
			Currencies.CurrencyId,
			CASE 
				SalesInvoices.SourceType
				WHEN 'I' THEN 'Invoice'
				WHEN 'C' THEN 'Credit'
				WHEN 'R' THEN 'Payment'
				ELSE ''
			END AS ItemType,
			CASE 
				WHEN SalesInvoices.SourceType = 'I' THEN CASE
															WHEN SalesInvoices.CurInvoiceValueOutstanding = 0 THEN 'Paid'
															WHEN SalesInvoices.DueDate < GETDATE() THEN 'Overdue'
															ELSE 'Outstanding'
														END
				ELSE ''
			END AS InvoiceStatus,
			COALESCE((CASE
							WHEN SalesInvoices.SourceType LIKE '[IC]' THEN SalesInvoices.SalesInvoiceId
							ELSE CASE (SELECT TOP 1
											CashItems.SourceType
										FROM
											CashItems
										WHERE
											CashItems.SourceSalesInvoice = SalesInvoices.SalesInvoice)
									WHEN 'M' THEN (SELECT TOP 1 si.SalesInvoiceId FROM CashItems INNER JOIN SalesInvoices si ON CashItems.TargetSalesInvoice = si.SalesInvoice WHERE CashItems.SourceSalesInvoice = SalesInvoices.SalesInvoice)
									ELSE (SELECT TOP 1 si.SalesInvoiceId FROM CashItems INNER JOIN SalesInvoices si ON CashItems.SourceSalesInvoice = si.SalesInvoice WHERE CashItems.TargetSalesInvoice = SalesInvoices.SalesInvoice)
									END
						END), '') AS InvoiceId,
			CASE (SELECT TOP 1 
						Cash.PaymentType 
					FROM
						CashItems 
						LEFT JOIN Cash ON Cash.Cash = CashItems.Cash 
					WHERE 
						CashItems.TargetSalesInvoice = SalesInvoices.SalesInvoice) 
				WHEN 'B' THEN 'BACS' 
				WHEN 'C' THEN 'Cheque' 
				WHEN 'H' THEN 'Cash' 
				ELSE CASE WHEN (SELECT TOP 1 
									CreditCardTransaction
								FROM
									CreditCardTransactions
									INNER JOIN CashItems ON CashItems.Cash = CreditCardTransactions.Cash
								WHERE
									CashItems.TargetSalesInvoice = SalesInvoices.SalesInvoice AND CashItems.SourceType = 'R') IS NOT NULL
						THEN 'Credit Card'
						WHEN (SELECT TOP 1 
									CreditCardTransaction
								FROM
									CreditCardTransactions
									INNER JOIN CashItems ON CashItems.Cash = CreditCardTransactions.Cash
									INNER JOIN CashItems ci ON CashItems.TargetSalesInvoice = ci.SourceSalesInvoice
								WHERE
									ci.TargetSalesInvoice = SalesInvoices.SalesInvoice AND ci.SourceType = 'M') IS NOT NULL
						THEN 'Credit Card'
						ELSE ''
					END
			END AS PaymentType,
			CASE SalesInvoices.SourceType 
				WHEN 'I' THEN SalesInvoices.CurInvoiceValue
				ELSE 0
			END AS 'Debit',
			CASE 
				WHEN SalesInvoices.SourceType LIKE '[RC]' THEN SalesInvoices.CurInvoiceValue
				ELSE 0
			END AS 'Credit'
		FROM
			SalesInvoices
			INNER JOIN Currencies ON SalesInvoices.Currency = Currencies.Currency
		WHERE
			SalesInvoices.Customer = @customer
			AND SalesInvoices.SystemType = 'F'
			AND SalesInvoices.SourceType LIKE '[IRC]'
			AND ((SalesInvoices.CurInvoiceValueOutstanding > 0 AND @outstanding = 1) OR (@outstanding = 0))
			AND SalesInvoices.SalesInvoiceId = COALESCE(@salesInvoiceId, SalesInvoices.SalesInvoiceId)
		GROUP BY
			SalesInvoices.SalesInvoice,
			SalesInvoices.CurInvoiceValue,
			SalesInvoices.EffectiveDate,
			Currencies.CurrencyId,
			SalesInvoices.SourceType,
			SalesInvoices.CurInvoiceValueOutstanding,
			SalesInvoices.DueDate,
			SalesInvoices.SalesInvoiceId,
			SalesInvoices.SalesOrder,
			SalesInvoices.CurInvoiceValue
	),
	Statements AS
	(
		SELECT
			ROW_NUMBER() OVER (ORDER BY 
                                CASE @orderBy
                                    WHEN 'EffectiveDate' THEN CAST(SalesInvoices.EffectiveDate AS nvarchar(23))
									WHEN 'CurInvoiceValue' THEN CAST(SalesInvoices.CurInvoiceValue AS nvarchar(23))
									WHEN 'InvoiceStatus' THEN CTE.InvoiceStatus
                                    ELSE CTE.InvoiceId
                                END) AS rowNumber,
			CTE.EffectiveDate,
			CTE.CurrencyId,
			CTE.ItemType,
			CTE.InvoiceStatus,
			CTE.InvoiceId,
			COALESCE(SalesOrders.SalesOrderId, '') AS SalesOrderId,
			COALESCE(SalesOrders.CustomerOrderNumber, '') AS CustomerOrderNumber,
			CTE.PaymentType,
			CTE.Debit,
			CTE.Credit
		FROM
			CTE
			LEFT JOIN SalesInvoices ON SalesInvoices.SalesInvoiceId = CTE.InvoiceId
			LEFT JOIN SalesOrders ON SalesOrders.SalesOrder = SalesInvoices.SalesOrder			
	)

	SELECT @results = COALESCE(
		(SELECT
			STUFF( 
				(SELECT ',{
						"Date":"' + CONVERT(nvarchar(23), EffectiveDate, 126) + '",
						"StatementLineType":"' + ItemType + '",
						"Currency":"' + REPLACE(CurrencyId, '"','&#34;') + '",
						"Status":"' + InvoiceStatus + '",
						"InvoiceId":"' + REPLACE(InvoiceId, '"','&#34;') + '",
						"SalesOrderId":"' + REPLACE(SalesOrderId, '"','&#34;') + '",
						"CustomerOrderNumber":"' + REPLACE(REPLACE(REPLACE(CustomerOrderNumber, CHAR(13),'&#xD;'), CHAR(10),'&#xA;'), '"','&#34;') + '",
						"PaymentType":"' + PaymentType + '",
						"Debit":"' + CAST(Debit AS nvarchar(23)) + '",
						"Credit":"' + CAST(Credit AS nvarchar(23)) + '"
					}'
					FROM 
						Statements
					WHERE 
						(rowNumber > @pageSize * (@pageNumber - 1) )
						AND (rowNumber <= @pageSize * @pageNumber )
					ORDER BY
						rowNumber 
					FOR XML PATH(''), 
			TYPE).value('.','nvarchar(max)'), 1, 1, '' 
			)), '');

	SELECT @results = REPLACE(REPLACE(REPLACE(REPLACE('{"CustomerStatements":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), ''), '\', '\\');

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
