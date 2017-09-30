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
	@salesOrder bigint = null,
	@creditCardTypeId nvarchar(20) = null,
	@cardName nvarchar(50) = null,
	@cardNumber nvarchar(100) = null,
	@startMonth int = null,
	@startYear int = null,
	@expiryMonth int = null,
	@expiryYear int = null,
	@issue nvarchar(10) = null,
	@address nvarchar(100) = null,
	@city nvarchar(50) = null,
	@region nvarchar(50) = null,
	@postalCode nvarchar(20) = null,
	@countryCode nvarchar(3) = null,
	@lastDigits nvarchar(4) = null,
	@authorisation nvarchar(50) = null,
	@curTransactionValue money,
	@error nvarchar(1000) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiSalesOrdersPayment') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiSalesOrdersPayment
				@salesOrder = @salesOrder,
				@creditCardTypeId = @creditCardTypeId,
				@cardName = @cardName,
				@cardNumber = @cardNumber,
				@startMonth = @startMonth,
				@startYear = @startYear,
				@expiryMonth = @expiryMonth,
				@expiryYear = @expiryYear,
				@issue = @issue,
				@address = @address,
				@city = @city,
				@region = @region,
				@postalCode = @postalCode,
				@countryCode = @countryCode,
				@lastDigits = @lastDigits,
				@authorisation = @authorisation,
				@curTransactionValue = @curTransactionValue,
				@error = @error OUTPUT
			RETURN;
		END;

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

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
			SET @error = 'ERROR: Required parameter missing: Sales Order Number.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
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

	IF @curTransactionValue IS NULL
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Transaction Value.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	IF @creditCardTypeId IS NULL OR @creditCardTypeId = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Payment Type.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;
	ELSE
		BEGIN
			SET @creditCardType = (SELECT CreditCardType FROM CreditCardTypes WHERE CreditCardTypeId = @creditCardTypeId);
		END;

	IF @creditCardType IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find credit card type with the specified credit card type ID. Please check your input data.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	IF @cardName IS NULL
		BEGIN
			SET @cardName = '';
		END;

	IF @cardNumber IS NULL
		BEGIN
			SET @cardNumber = '';
		END;

	IF @expiryMonth IS NULL
		BEGIN
			SET @expiryMonth = 0;
		END;

	IF @expiryYear IS NULL
		BEGIN
			SET @expiryYear = 0;
		END;

	IF @issue IS NULL
		BEGIN
			SET @issue = '';
		END;

	IF @address IS NULL
		BEGIN
			SET @address = '';
		END;

	IF @city IS NULL
		BEGIN
			SET @city = '';
		END;

	IF @region IS NULL
		BEGIN
			SET @region = '';
		END;

	IF @postalCode IS NULL
		BEGIN
			SET @postalCode = '';
		END;

	IF @countryCode IS NULL OR @countryCode = ''
		BEGIN
			SET @country = (SELECT Country FROM ApplicationSettings);
		END;
	ELSE
		BEGIN
			SET @country = (SELECT Country FROM Countries WHERE ISO3Chars = @countryCode);
		END;

	IF @country IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find country with the specified country code. Please check your input data.';
			SELECT @error AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;

	IF @lastDigits IS NULL
		BEGIN
			SET @lastDigits = '';
		END;

	IF @authorisation IS NULL
		BEGIN
			SET @authorisation = '';
		END;

	EXEC dbo.wsp_SalesOrdersAddCreditCard
		@SalesOrder = @salesOrder,
		@Customer = @customer,
		@CreditCard = @creditCard OUTPUT,
		@CreditCardType = @creditCardType,
		@CardName = @cardName,
		@CardNumber = @cardNumber,
		@LastDigits = @lastDigits,
		@StartMonth = @startMonth,
		@StartYear = @startYear,
		@ExpiryMonth = @expiryMonth,
		@ExpiryYear = @expiryYear,
		@Issue = @issue,
		@Address = @address,
		@City = @city,
		@Region = @region,
		@PostalCode = @postalCode,
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
		@Authorisation = @authorisation,
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

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
