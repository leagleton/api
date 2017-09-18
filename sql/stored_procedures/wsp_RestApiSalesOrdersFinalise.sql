SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 29 September 2017
-- Description:	Stored procedure for finalising sales orders in WinMan for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiSalesOrdersFinalise]
	@salesOrder BIGINT,
	@totalOrderValue MONEY,
	@error NVARCHAR(1000) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiSalesOrdersFinalise') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiSalesOrdersFinalise
				@salesOrder = @salesOrder,
				@totalOrderValue = @totalOrderValue,
				@error = @error OUTPUT
			RETURN
		END

	SET NOCOUNT ON;

	DECLARE
		@systemOrderValue MONEY
		
	SET @error = ''

	SELECT
		@systemOrderValue = ROUND(SUM(CurItemValue) + SUM(CurTaxValue), 2)
	FROM
		SalesOrderItems
	WHERE
		SalesOrder = @salesOrder

	IF @totalOrderValue <> @systemOrderValue
		BEGIN
			SET @error = @error + CHAR(13) + CHAR(10) + 'Website order total does not match system order total of ' + CAST(@systemOrderValue AS NVARCHAR(max)) + '.'			
		END

	DECLARE 
		@customer BIGINT,
		@underLimit	BIT,
		@tradingStatus NVARCHAR(1)

	SET @customer = (SELECT Customer FROM SalesOrders WHERE SalesOrder = @salesOrder)

	EXEC dbo.wsp_CustomerCreditCheck
		@Customer = @customer,
		@UnderLimit = @underLimit OUTPUT,	
		@OptTradingStatus = @tradingStatus OUTPUT	

	IF @underLimit = 0
		BEGIN
			SET @error = @error + CHAR(13) + CHAR(10) + 'Customer has exceeded their credit limit.'
		END

	IF @tradingStatus = 'S'
		BEGIN
			SET @error = @error + CHAR(13) + CHAR(10) + 'Customer is on stop.'
		END

	IF @tradingStatus = 'H'
		BEGIN
			SET @error = @error + CHAR(13) + CHAR(10) + 'Customer is on hold.'
		END

	IF @error <> ''
		BEGIN
			UPDATE 
				SalesOrders
			SET
				SystemType = 'H',
				LastModifiedDate = GETDATE(),
				LastModifiedUser = 'WinMan REST API',
				Comments = Comments + CHAR(13) + CHAR(10) + @error
			WHERE
				SalesOrder = @salesOrder
		END

	SELECT @error AS ErrorMessage

END
GO
