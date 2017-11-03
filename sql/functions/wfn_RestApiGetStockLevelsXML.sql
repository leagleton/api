SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterFunction;

-- =============================================
-- Author:		Rob Cope / Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Function to SELECT product stock levels for the WinMan REST API in XML format.
-- =============================================

IF NOT EXISTS
(
	SELECT 
		[name]
	FROM
		sys.objects
	WHERE
		[object_id] = OBJECT_ID(N'[dbo].[wfn_RestApiGetStockLevelsXML]')
		AND [type] IN (N'FN', N'IF', N'TF', N'FS', N'FT')
)
	BEGIN
		EXECUTE('CREATE FUNCTION dbo.wfn_RestApiGetStockLevelsXML() RETURNS nvarchar(100) AS BEGIN RETURN ''dbo.wfn_RestApiGetStockLevelsXML''; END;');
	END;
GO

ALTER FUNCTION [dbo].[wfn_RestApiGetStockLevelsXML] 
(
	@Product bigint,
	@Site bigint
)
RETURNS xml
AS
BEGIN

	DECLARE	@QuantityOnHand decimal(17,5);
	DECLARE @QuantityHardAllocated decimal(17,5);
	DECLARE	@QuantitySoftAllocated decimal(17,5);

	SET @QuantityOnHand =
		(SELECT
			SUM(Inventory.QuantityOutstanding)
		FROM Inventory
			INNER JOIN Locations ON Inventory.Location = Locations.Location
		WHERE Inventory.Product = @Product
			AND Inventory.Site = @Site
			AND Inventory.Availability IN ('B','S','K','W')
			AND Inventory.QuantityOutstanding > 0);

	SET @QuantityHardAllocated =
		(SELECT
			SUM(Inventory.QuantityOutstanding)
		FROM Inventory
		WHERE Inventory.Product = @Product
			AND Inventory.Site = @Site
			AND Inventory.Availability IN ('K','W')
			AND Inventory.QuantityOutstanding > 0);

	DECLARE	@SOSystemType nvarchar(4);

	IF dbo.wfn_GetProgramProfile('MRP_IncludeHeldSalesOrders', 'N') = 'N'
		BEGIN
			SET @SOSystemType = 'F';
		END;
	ELSE
		BEGIN
			SET @SOSystemType = '[HF]';
		END;

	SET @QuantitySoftAllocated = 0;

	WITH Requirements AS
	(
		SELECT
			TransactionKey,
			QuantityOutstanding - ISNULL(QuantityHardAllocated,0) AS QuantityRequired
		FROM
			(
				SELECT
					SI.SalesOrderItem AS TransactionKey,
					SI.QuantityOutstanding,
					(SELECT SUM(Inventory.QuantityOutstanding)
						FROM Inventory
						WHERE Inventory.SalesOrderItem = SI.SalesOrderItem
							AND Inventory.Site = SI.Site
							AND Inventory.Availability = 'K'
							AND Inventory.QuantityOutstanding > 0) AS QuantityHardAllocated
				FROM SalesOrderItems SI 
					INNER JOIN SalesOrders S on SI.SalesOrder = S.SalesOrder
					LEFT JOIN Customers C ON C.Customer = S.Customer
				WHERE SI.Product = @Product 
					AND SI.QuantityOutstanding > 0 
					AND SI.DueDate < dbo.wfn_GetMaxDate()
					AND SI.ItemType = 'P'
					AND S.SystemType LIKE @SOSystemType
					AND (SI.Site = @Site OR @Site = 0)
					AND NOT S.Customer IN (SELECT Customer FROM Sites)

				UNION ALL

				SELECT
					WIP.WorkInProgress,
					WIP.QuantityOutstanding,
					(SELECT SUM(Inventory.QuantityOutstanding)
					FROM Inventory
					WHERE Inventory.AllocatedWIP = WIP.WorkInProgress
						AND Inventory.Site = MO.Site
						AND Inventory.Availability = 'W'
						AND Inventory.QuantityOutstanding > 0)
				FROM WorkInProgress WIP
					INNER JOIN ManufacturingOrders MO ON MO.ManufacturingOrder = WIP.ManufacturingOrder
				WHERE WIP.Product = @Product 
					AND WIP.QuantityOutstanding <> 0 
					AND MO.SystemType <> 'C'
					AND (MO.Site = @Site OR @Site = 0)

				UNION ALL

				SELECT
					WIPRQ.WorkInProgressRequirement,
					WIPRQ.Quantity,
					0
				FROM WorkInProgressRequirements WIPRQ
					LEFT JOIN ManufacturingOrders MO ON MO.ManufacturingOrder = WIPRQ.ManufacturingOrder
				WHERE WIPRQ.Component = @Product
					AND	(MO.Site = @Site OR @Site = 0)
			) AS DTbl
		WHERE QuantityOutstanding - ISNULL(QuantityHardAllocated,0) > 0
	)
	SELECT
		@QuantitySoftAllocated = SUM(Requirements.QuantityRequired)
	FROM Requirements;

	DECLARE @stockLevels xml;

	SET @stockLevels = '<QuantityInStock>' + CAST(ISNULL(@QuantityOnHand,0) AS nvarchar(10)) + '</QuantityInStock>'
						+ '<QuantityHardAllocated>' + CAST(ISNULL(@QuantityHardAllocated,0) AS nvarchar(10)) + '</QuantityHardAllocated>'
						+ '<QuantitySoftAllocated>' + CAST(ISNULL(@QuantitySoftAllocated,0) AS nvarchar(10)) + '</QuantitySoftAllocated>';

	RETURN @stockLevels;

END;
GO

COMMIT TRANSACTION AlterFunction;
