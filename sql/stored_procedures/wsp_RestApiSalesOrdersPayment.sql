SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 29 September 2017
-- Description:	Stored procedure for adding payment information to a sales order in WinMan for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiSalesOrdersPayment]
	@salesOrder BIGINT = NULL,
	@creditCardTypeId NVARCHAR(20) = NULL,
	@cardName NVARCHAR(50) = NULL,
	@cardNumber NVARCHAR(100) = NULL,
	@startMonth INT = NULL,
	@startYear INT = NULL,
	@expiryMonth INT = NULL,
	@expiryYear INT = NULL,
	@issue NVARCHAR(10) = NULL,
	@address NVARCHAR(100) = NULL,
	@city NVARCHAR(50) = NULL,
	@region NVARCHAR(50) = NULL,
	@postalCode NVARCHAR(20) = NULL,
	@countryCode NVARCHAR(3) = NULL,
	@lastDigits NVARCHAR(4) = NULL,
	@authorisation NVARCHAR(50) = NULL,
	@curTransactionValue MONEY,
	@error NVARCHAR(1000) OUTPUT
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
			RETURN
		END

	SET NOCOUNT ON;

	DECLARE
		@customer BIGINT,
		@creditCard BIGINT,
		@creditCardType BIGINT,
		@country BIGINT,
		@site BIGINT,
		@exchangeRate DECIMAL(18,6),
		@currency BIGINT,
		@originalLastModifiedDate DATETIME,
		@creditCardTransaction BIGINT,
		@user NVARCHAR(20) = 'WinMan REST API'
		
	SET @error = ''

	IF @salesOrder IS NULL OR @salesOrder = 0
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Sales Order Number.'
			SELECT @error AS ErrorMessage
			RETURN
		END
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
				SalesOrder = @salesOrder
		END

	IF @curTransactionValue IS NULL
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Transaction Value.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @creditCardTypeId IS NULL OR @creditCardTypeId = ''
		BEGIN
			SET @error = 'ERROR: Required parameter missing: Payment Type.'
			SELECT @error AS ErrorMessage
			RETURN
		END
	ELSE
		BEGIN
			SET @creditCardType = (SELECT CreditCardType FROM CreditCardTypes WHERE CreditCardTypeId = @creditCardTypeId)
		END

	IF @creditCardType IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find credit card type with the specified credit card type ID. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @cardName IS NULL
		BEGIN
			SET @cardName = ''
		END

	IF @cardNumber IS NULL
		BEGIN
			SET @cardNumber = ''
		END

	IF @expiryMonth IS NULL
		BEGIN
			SET @expiryMonth = 0
		END

	IF @expiryYear IS NULL
		BEGIN
			SET @expiryYear = 0
		END

	IF @issue IS NULL
		BEGIN
			SET @issue = ''
		END

	IF @address IS NULL
		BEGIN
			SET @address = ''
		END

	IF @city IS NULL
		BEGIN
			SET @city = ''
		END

	IF @region IS NULL
		BEGIN
			SET @region = ''
		END

	IF @postalCode IS NULL
		BEGIN
			SET @postalCode = ''
		END

	IF @countryCode IS NULL OR @countryCode = ''
		BEGIN
			SET @country = (SELECT Country FROM ApplicationSettings)
		END
	ELSE
		BEGIN
			SET @country = (SELECT Country FROM Countries WHERE ISO3Chars = @countryCode)
		END

	IF @country IS NULL
		BEGIN
			SET @error = 'ERROR: Could not find country with the specified country code. Please check your input data.'
			SELECT @error AS ErrorMessage
			RETURN
		END

	IF @lastDigits IS NULL
		BEGIN
			SET @lastDigits = ''
		END

	IF @authorisation IS NULL
		BEGIN
			SET @authorisation = ''
		END

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
		@Original_LastModifiedDate = @originalLastModifiedDate

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
		@CreditCardTransaction = @creditCardTransaction OUTPUT

	EXEC dbo.wsp_CashCreateUnallocatedReceipt
		@Customer = @customer,
		@CashDescription = 'Credit Card Transaction',
		@UserName = @user,
		@AccountValue = @curTransactionValue,
		@CreditCard = @creditCard,
		@Site = @site,
		@CreditCardTransaction = @creditCardTransaction,
		@Cash = null
		
	SELECT @error AS ErrorMessage

END
GO
