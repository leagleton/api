SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Function to SELECT custom columns for a product as XML for the WinMan REST API.
-- =============================================

CREATE FUNCTION [dbo].[wfn_RestApiGetCustomColumnsXML] 
(
	@product BIGINT
)
RETURNS XML
AS
BEGIN
	DECLARE @result XML
	DECLARE @xml XML
	DECLARE @tempTable TABLE (CustomColumns XML)

	SELECT @xml = COALESCE((SELECT CustomColumns FROM Products WHERE Product = @product), '')
	
	INSERT INTO @tempTable SELECT @xml
	
	SELECT @result = 
		(SELECT CAST(
				'<' + CAST(cols.query('data(Name)') AS NVARCHAR(max)) + '>' 
					+ CAST(cols.query('data(Value)') AS NVARCHAR(max)) + 
				'</' + CAST(cols.query('data(Name)') AS NVARCHAR(max)) + '>' 
			AS XML)
		FROM 
			@tempTable T1 CROSS APPLY CustomColumns.nodes('/CustomColumnsCollection/CustomColumn') AS T2(cols)
		FOR XML PATH('CustomColumn'))

	RETURN @result
END
GO
