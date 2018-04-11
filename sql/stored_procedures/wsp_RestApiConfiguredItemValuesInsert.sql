SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 01 March 2018
-- Description:	Stored procedure for INSERTing new configured item values into WinMan for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiConfiguredItemValuesInsert'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiConfiguredItemValuesInsert AS PRINT ''wsp_RestApiConfiguredItemValuesInsert''');
	END;
GO

ALTER PROCEDURE dbo.wsp_RestApiConfiguredItemValuesInsert
	@configuration uniqueidentifier,
	@productId nvarchar(100),
	@configuredStructureOptionId nvarchar(100),
	@configuredItemId nvarchar(100),
	@price money = 0,
	@error nvarchar(1000) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiConfiguredItemValuesInsert') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiConfiguredItemValuesInsert
				@configuration = @configuration OUTPUT,
				@productId = @productId,
				@configuredStructureOptionId = @configuredStructureOptionId,
				@ConfiguredItemId = @configuredItemId,
				@price = @price,
				@error = @error OUTPUT
			RETURN;
		END;

	SET NOCOUNT ON;

	DECLARE @configuredItem bigint;
	DECLARE @configuredStructureOption bigint;
	DECLARE @configuredProduct bigint;
	DECLARE @useConfigurator bit;

	SET @error = '';

	SELECT
		@configuredProduct = Product,
		@useConfigurator = ConfiguratorOption
	FROM
		Products
	WHERE
		ProductId = @productId
		AND ConfiguratorOption = 1;

	IF @configuredProduct IS NULL
		BEGIN
			SET @error = 'Could not find the specified product: ' + @productId + '. Please check your input data.';
			SELECT @error AS ErrorMessage;	
			RETURN;		
		END;
	
	IF @useConfigurator <> 1
		BEGIN
			SET @error = 'The product ' + @productId + 'is not a configurable product, but you have specified option information. Please check your input data.';
			SELECT @error AS ErrorMessage;	
			RETURN;		
		END;		
		
	SET @configuredStructureOption = (SELECT
											ConfiguredStructureOptions.ConfiguredStructureOption
										FROM
											ConfiguredStructureOptions
											INNER JOIN ConfiguredStructures ON ConfiguredStructures.ConfiguredStructure = ConfiguredStructureOptions.ConfiguredStructure
											INNER JOIN Products ON Products.Product = ConfiguredStructures.Product
										WHERE
											Products.ProductId = @productId
											AND ConfiguredStructureOptions.ConfiguredStructureOptionId = @configuredStructureOptionId);

	IF @configuredStructureOption IS NULL
		BEGIN
			SET @error = 'Could not find the specified option: ' + @configuredStructureOptionId + ', for the specified sku: ' + @productId + '. Please check your input data.';
			SELECT @error AS ErrorMessage;	
			RETURN;		
		END;

	SET @configuredItem = (SELECT
								ConfiguredItems.ConfiguredItem
							FROM
								ConfiguredItems
								INNER JOIN ConfiguredStructureOptions ON ConfiguredStructureOptions.ConfiguredStructureOption = ConfiguredItems.ConfiguredStructureOption
								INNER JOIN ConfiguredStructures ON ConfiguredStructures.ConfiguredStructure = ConfiguredStructureOptions.ConfiguredStructure
								INNER JOIN Products ON Products.Product = ConfiguredStructures.Product
							WHERE
								Products.ProductId = @productId
								AND ConfiguredStructureOptions.ConfiguredStructureOptionId = @configuredStructureOptionId
								AND ConfiguredItems.ConfiguredItemId = @configuredItemId);

	IF @configuredItem IS NULL
		BEGIN
			SET @error = 'Could not find the specified option item: ' + @configuredItemId + ', for the specified sku: ' + @productId + '. Please check your input data.';
			SELECT @error AS ErrorMessage;	
			RETURN;		
		END;

	EXEC wsp_ConfiguredItemValuesInsert
		@Configuration = @configuration,
		@ConfiguredItem = @configuredItem,
		@Value = 1,
		@Price = @price,
		@UserName = 'WinMan REST API';

	SELECT @configuration AS [Configuration], @error AS ErrorMessage;

END;
GO

COMMIT TRANSACTION AlterProcedure;
