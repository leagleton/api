SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 26 February 2018
-- Description:	Stored procedure to convert quotes to orders for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiQuotesConvert'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiQuotesConvert AS PRINT ''wsp_RestApiQuotesConvert''');
	END;
GO

ALTER PROCEDURE dbo.wsp_RestApiQuotesConvert
    @website nvarchar(100),
	@customerGuid nvarchar(36) = null,
    @customerId nvarchar(10) = null,
    @customerBranch nvarchar(4) = null,
    @quoteId nvarchar(15) = null,
    @customerOrderNumber nvarchar(50) = null,    
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiQuotesConvert') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiPdfUrlSelect
                @website = @website,
				@customerGuid = @customerGuid,
                @customerId = @customerId,
                @customerBranch = @customerBranch,
                @quoteId = @quoteId,
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
				SELECT 'A required parameter is missing. If CustomerGuid is not supplied, both CustomerId and CustomerBranch must be supplied.' AS ErrorMessage;
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

    IF @customerOrderNumber IS NULL OR @customerOrderNumber = ''
		BEGIN
			SELECT 'A required parameter is missing: CustomerOrderNumber.' AS ErrorMessage;
            ROLLBACK TRANSACTION;
			RETURN;		
		END;        

    DECLARE @salesOrder bigint;
	DECLARE @date datetime;
	DECLARE @user nvarchar(20);

	SET @date = GETDATE();
	SET @user = 'WinMan REST API'; 

    IF @quoteId IS NULL OR @quoteId = ''
		BEGIN
			SELECT 'A required parameter is missing: QuoteId.' AS ErrorMessage;
            ROLLBACK TRANSACTION;
			RETURN;		
		END;
    ELSE
        BEGIN
            SET @salesOrder = (SELECT SalesOrder FROM SalesOrders WHERE SalesOrderId = @quoteId AND Customer = @customer);
        END;

	IF @salesOrder IS NULL
		BEGIN
			SELECT 'Could not find specified quote. Please check your input data.' AS ErrorMessage;
            ROLLBACK TRANSACTION;
			RETURN;		
		END;

	UPDATE
        SalesOrders
    SET
        SystemType = 'N',
        CustomerOrderNumber = @customerOrderNumber,
        LastModifiedDate = @date,
        LastModifiedUser = @user
    WHERE
        SalesOrder = @salesOrder;

	DECLARE	@cursor	cursor;
	DECLARE	@returnedItem bigint;
	DECLARE	@actualProduct bigint;
	DECLARE	@quantityReturned decimal(17,5);
	DECLARE	@location bigint;

	SET @cursor = CURSOR FAST_FORWARD
					FOR
						SELECT
							ReturnedItem, 
							ActualProduct, 
							QuantityReturned, 
							[Location]
						FROM
							ReturnedItems
							INNER JOIN ReturnNotes ON ReturnNotes.ReturnNote = ReturnedItems.ReturnNote
						WHERE
							Quote = @salesOrder
							AND RepairReturnToCustomer = 1
							AND RepairOrder IS NULL;

	OPEN @cursor
		FETCH NEXT FROM
			@cursor
		INTO
			@returnedItem,
			@actualProduct,
			@quantityReturned,
			@location;

		WHILE @@FETCH_STATUS = 0
			BEGIN
				EXEC dbo.wsp_ReturnNotesCreateRepairOrder 
					@returnedItem, 
					@actualProduct, 
					@quantityReturned, 
					@location, 
					@user;

                FETCH NEXT FROM
                    @cursor
                INTO
                    @returnedItem,
                    @actualProduct,
                    @quantityReturned,
                    @location;
			END;
	CLOSE @cursor;

	DEALLOCATE @cursor;

	DECLARE @crmContact bigint;
	DECLARE @crmProject bigint;
	DECLARE @crmCompany bigint;
	DECLARE @supportCase bigint;    
	DECLARE @actionDescription nvarchar(100);
	DECLARE @owner bigint;

	SELECT
		@crmContact = SalesOrders.CRMContact,
		@crmProject = SalesOrders.CRMProject,
		@crmCompany = CRMCompanies.CRMCompany,
		@supportCase = SalesOrders.SupportCase,
		@actionDescription = 'Quotation ' + SalesOrders.SalesOrderId + ' converted to order via the WinMan REST API.'
	FROM
        SalesOrders
		LEFT JOIN Customers ON SalesOrders.Customer = Customers.Customer
		LEFT JOIN CRMCompanies ON Customers.Customer = CRMCompanies.Customer
	WHERE
        SalesOrders.SalesOrder = @salesOrder;

	SET @owner = (SELECT UserId FROM Users WHERE UserName = 'WINMAN');

	EXEC dbo.wsp_CRMActionsInsert 
		@CRMActionDescription = @actionDescription, 
		@CRMTask = NULL,
		@CRMContact = @crmContact,
		@CRMProject = @crmProject,
		@Owner = @owner,
		@LastModifiedDate = @date,
		@LastModifiedUser = @user,
		@CreatedDate = @date,
		@CreatedUser = @user,
		@Comments = '',
		@CRMCompany = @crmCompany,
		@Program = 'SalesOrders',
		@Identifier = @salesOrder,
		@ReselectRecord = 0,
		@ActionType = 'S',
		@SupportCase = @supportCase;

	EXEC wsp_AuditInsert 
		'SalesOrders',
		@salesOrder,
		'Audit_QuoteConverted',
		'',
		@user;

    SELECT @results = 'Quote successfully converted to order.';

    SELECT @results AS Results;        

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
