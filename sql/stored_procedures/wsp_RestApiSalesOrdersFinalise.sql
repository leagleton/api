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
-- Description:	Stored procedure for finalising sales orders in WinMan for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiSalesOrdersFinalise'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiSalesOrdersFinalise AS PRINT ''wsp_RestApiSalesOrdersFinalise''');
	END;
GO

-- 09Mar18 LAE Do not return sales order comments as an error message so that the sales order is still accepted #0000140025

ALTER PROCEDURE dbo.wsp_RestApiSalesOrdersFinalise
	@salesOrder bigint,
	@totalOrderValue money,
	@error nvarchar(1000) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiSalesOrdersFinalise') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiSalesOrdersFinalise
				@salesOrder = @salesOrder,
				@totalOrderValue = @totalOrderValue,
				@error = @error OUTPUT;
			RETURN;
		END;

	SET NOCOUNT ON;

	DECLARE	@systemOrderValue money;
	-- 09Mar18 LAE
	DECLARE @comments nvarchar(500);
		
	SET @error = '';
	-- 09Mar18 LAE
	SET @comments = '';

	SELECT
		@systemOrderValue = ROUND(SUM(CurItemValue) + SUM(CurTaxValue), 2)
	FROM
		SalesOrderItems
	WHERE
		SalesOrder = @salesOrder;

	IF @totalOrderValue <> @systemOrderValue
		BEGIN;
			-- 09Mar18 LAE
			--SET @error = @error + CHAR(13) + CHAR(10) + 'The sum of the OrderLineValues + ShippingValue comes to ' + CAST(@systemOrderValue AS nvarchar(100)) + ', but the TotalOrderValue was specified as ' + CAST(@totalOrderValue AS nvarchar(100)) + '. These values do not match. Please check your input data.';
			SET @error = 'The sum of the OrderLineValues + ShippingValue comes to ' + CAST(@systemOrderValue AS nvarchar(100)) + ', but the TotalOrderValue was specified as ' + CAST(@totalOrderValue AS nvarchar(100)) + '. These values do not match. Please check your input data.';			
			SELECT @error AS ErrorMessage;
			RETURN;
		END;

	DECLARE @customer bigint;
	DECLARE @underLimit	bit;
	DECLARE @tradingStatus nvarchar(1);

	SET @customer = (SELECT Customer FROM SalesOrders WHERE SalesOrder = @salesOrder);

	EXEC dbo.wsp_CustomerCreditCheck
		@Customer = @customer,
		@UnderLimit = @underLimit OUTPUT,	
		@OptTradingStatus = @tradingStatus OUTPUT;

	IF @underLimit = 0
		BEGIN
			-- 09Mar18 LAE
			--SET @error = @error + CHAR(13) + CHAR(10) + 'Customer has exceeded their credit limit.';
			SET @comments = @comments + 'Customer has exceeded their credit limit.' + CHAR(13) + CHAR(10);
		END;

	IF @tradingStatus = 'S'
		BEGIN
			-- 09Mar18 LAE
			--SET @error = @error + CHAR(13) + CHAR(10) + 'Customer is on stop.';
			SET @comments = @comments + 'Customer is on stop.'+ CHAR(13) + CHAR(10);
		END;

	IF @tradingStatus = 'H'
		BEGIN
			-- 09Mar18 LAE
			--SET @error = @error + CHAR(13) + CHAR(10) + 'Customer is on hold.';
			SET @comments = @comments + 'Customer is on hold.'+ CHAR(13) + CHAR(10);
		END;

	-- 09Mar18 LAE
	--IF @error <> ''
	IF @comments <> ''
		BEGIN
			UPDATE 
				SalesOrders
			SET
				SystemType = 'H',
				LastModifiedDate = GETDATE(),
				LastModifiedUser = 'WinMan REST API',
				-- 09Mar18 LAE
				--Comments = Comments + CHAR(13) + CHAR(10) + @error
				Comments = CASE WHEN Comments <> '' THEN Comments + CHAR(13) + CHAR(10) + @comments ELSE @comments END
			WHERE
				SalesOrder = @salesOrder;
		END;

	-- 09Mar18 LAE
	--SELECT @error = REPLACE(REPLACE(@error, CHAR(13), ''), CHAR(10), '');		

	SELECT @error AS ErrorMessage;

END;
GO

COMMIT TRANSACTION AlterProcedure;
