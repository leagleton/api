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
-- Description:	Stored procedure for adding payment information to a sales order in WinMan for the WinMan REST API.
-- =============================================

IF NOT EXISTS
(
    SELECT * FROM sys.procedures p
    JOIN sys.schemas s
    ON p.schema_id = s.schema_id
    WHERE
        p.[type] = 'P'
    AND
        p.[name] = 'wsp_RestApiSalesOrdersPayment'
    AND
        s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiSalesOrdersPayment AS PRINT ''wsp_RestApiSalesOrdersPayment''');
	END;
GO

ALTER PROCEDURE dbo.wsp_RestApiSalesOrdersPayment
	@salesOrder bigint,
	@creditCardTypeId nvarchar(20),
	@curTransactionValue money,
	@error nvarchar(1000) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiSalesOrdersPayment') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiSalesOrdersPayment
				@salesOrder = @salesOrder,
				@creditCardTypeId = @creditCardTypeId,
				@curTransactionValue = @curTransactionValue,
				@error = @error OUTPUT
			RETURN;
		END;

	SET NOCOUNT ON;

	DECLARE	@customer bigint;
	DECLARE @creditCard bigint;
	DECLARE @creditCardType bigint;
	DECLARE @country bigint;
	DECLARE @site bigint;
	DECLARE @exchangeRate decimal(18,6);
	DECLARE @currency bigint;
	DECLARE @originalLastModifiedDate datetime;
	DECLARE @creditCardTransaction bigint;
	DECLARE @user nvarchar(20);

	SET @user = 'WinMan REST API';		
	SET @error = '';

	IF @salesOrder IS NULL OR @salesOrder = 0
		BEGIN
			SET @error = 'A required parameter is missing: SalesOrder.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;
	ELSE
		BEGIN
			SELECT
				@customer = Customer,
				@site = [Site],
				@exchangeRate = ExchangeRate,
				@currency = Currency,
				@originalLastModifiedDate = LastModifiedDate
			FROM
				SalesOrders
			WHERE
				SalesOrder = @salesOrder;
		END;

	SET @country = dbo.wfn_GetDefault('Country', @site);		

	IF @curTransactionValue IS NULL
		BEGIN
			SET @error = 'A required parameter is missing: CardPaymentReceived. This field is required when the PaymentType is not On Account.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;

	IF @creditCardTypeId IS NULL OR @creditCardTypeId = ''
		BEGIN
			SET @error = 'A required parameter is missing: PaymentType.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;
	ELSE
		BEGIN
			SET @creditCardType = (SELECT CreditCardType FROM CreditCardTypes WHERE CreditCardTypeId = @creditCardTypeId);
		END;

	IF @creditCardType IS NULL
		BEGIN
			SET @error = 'Could not find the credit card type with the specified PaymentType. Please check your input data.';
			SELECT @error AS ErrorMessage;
			RETURN;
		END;

	EXEC dbo.wsp_SalesOrdersAddCreditCard
		@SalesOrder = @salesOrder,
		@Customer = @customer,
		@CreditCard = @creditCard OUTPUT,
		@CreditCardType = @creditCardType,
		@CardName = '',
		@CardNumber = '',
		@LastDigits = '',
		@StartMonth = '',
		@StartYear = '',
		@ExpiryMonth = '',
		@ExpiryYear = '',
		@Issue = '',
		@Address = '',
		@City = '',
		@Region = '',
		@PostalCode = '',
		@Country = @country,
		@Active = 1,
		@LastModifiedUser = @user,
		@Original_LastModifiedDate = @originalLastModifiedDate;

	EXEC dbo.wsp_CreditCardTransactionsInsert
		@SalesOrder = @salesOrder,
		@CreditCard = @creditCard,
		@Shipment = null,
		@CurTransactionValue = @curTransactionValue,
		@ExchangeRate = @exchangeRate,
		@Currency = @currency,
		@Authorisation = '',
		@Status = 'CS',
		@Notes = '',
		@TransactionCode = '',
		@Response1 = '',
		@Response2 = '',
		@ActiveTransaction = 0,
		@Username = @user,
		@Cash = null,
		@SalesInvoice = null,
		@CreditCardTransaction = @creditCardTransaction OUTPUT;

	EXEC dbo.wsp_CashCreateUnallocatedReceipt
		@Customer = @customer,
		@CashDescription = 'Credit Card Transaction',
		@UserName = @user,
		@AccountValue = @curTransactionValue,
		@CreditCard = @creditCard,
		@Site = @site,
		@CreditCardTransaction = @creditCardTransaction,
		@Cash = null;
		
	SELECT @error AS ErrorMessage;

END;
GO

COMMIT TRANSACTION AlterProcedure;
