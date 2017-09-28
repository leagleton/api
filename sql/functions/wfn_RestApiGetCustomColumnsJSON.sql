SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Function to SELECT custom columns for a product as JSON for the WinMan REST API.
-- =============================================

CREATE FUNCTION [dbo].[wfn_RestApiGetCustomColumnsJSON] 
(
	@product BIGINT
)
RETURNS NVARCHAR(max)
AS
BEGIN
	DECLARE @result NVARCHAR(max)
	DECLARE @xml XML
	DECLARE @tempTable TABLE (CustomColumns XML)

	SELECT @xml = COALESCE((SELECT CustomColumns FROM Products WHERE Product = @product), '')
	
	INSERT INTO @tempTable SELECT @xml

	SELECT @result =
		(SELECT '[' +
			STUFF((SELECT ',{
				"' + CAST(cols.query('data(Name)') AS NVARCHAR(max)) + '":"' + CAST(cols.query('data(Value)') AS NVARCHAR(max)) + '"
			}' FROM 
				@tempTable T1 CROSS APPLY CustomColumns.nodes('/CustomColumnsCollection/CustomColumn') AS T2(cols)
			FOR XML PATH(''), TYPE).value('.','NVARCHAR(max)'), 1, 1, '') 
		+ ']')

	RETURN @result
END
GO
