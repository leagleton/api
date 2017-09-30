SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterFunction;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Function to SELECT custom columns for a product as JSON for the WinMan REST API.
-- =============================================

IF NOT EXISTS
(
	SELECT 
		[name]
	FROM
		sys.objects
	WHERE
		[object_id] = OBJECT_ID(N'[dbo].[wfn_RestApiGetCustomColumnsJSON]')
		AND [type] IN (N'FN', N'IF', N'TF', N'FS', N'FT')
)
	BEGIN
		EXECUTE('CREATE FUNCTION dbo.wfn_RestApiGetCustomColumnsJSON() RETURNS nvarchar(100) AS BEGIN RETURN ''dbo.wfn_RestApiGetCustomColumnsJSON''; END;');
	END;
GO

ALTER FUNCTION [dbo].[wfn_RestApiGetCustomColumnsJSON] 
(
	@product bigint
)
RETURNS nvarchar(max)
AS
BEGIN

	DECLARE @result nvarchar(max);
	DECLARE @xml xml;
	DECLARE @tempTable table (CustomColumns xml);

	SELECT @xml = COALESCE((SELECT CustomColumns FROM Products WHERE Product = @product), '');
	
	INSERT INTO @tempTable SELECT @xml;

	SELECT @result =
		(SELECT '[' +
			STUFF((SELECT ',{
				"' + CAST(cols.query('data(Name)') AS nvarchar(max)) + '":
				' + 
					CASE CAST(cols.query('data(DataType)') AS nvarchar(max))
						WHEN '0' THEN '"' + CAST(cols.query('data(Value)') AS nvarchar(max)) + '"'
						WHEN '1' THEN '"' + CONVERT(nvarchar(50), cols.query('data(Value)'), 126) + '"'
						WHEN '2' THEN 
							CASE WHEN CAST(cols.query('data(Value)') AS nvarchar(max)) = '' 
								THEN 'null' ELSE CAST(cols.query('data(Value)') AS nvarchar(max))
							END
						WHEN '3' THEN 
							CASE WHEN CAST(cols.query('data(Value)') AS nvarchar(max)) = '' 
								THEN 'null' ELSE CAST(cols.query('data(Value)') AS nvarchar(max))
							END
						WHEN '4' THEN 
							CASE WHEN CAST(cols.query('data(Value)') AS nvarchar(max)) = '' 
								THEN 'null' ELSE CAST(cols.query('data(Value)') AS nvarchar(max))
							END
						WHEN '5' THEN 
							CASE CAST(cols.query('data(Value)') AS nvarchar(max))
								WHEN '' THEN 'null'
								WHEN '1' THEN 'true'
								WHEN '0' THEN 'false'
								WHEN 'True' THEN 'true'
								WHEN 'False' THEN 'false'
								ELSE CAST(cols.query('data(Value)') AS nvarchar(max))
							END
						WHEN '6' THEN '"' + CAST(cols.query('data(Value)') AS nvarchar(max)) + '"'
						ELSE '"' + CAST(cols.query('data(Value)') AS nvarchar(max)) + '"'
					END
				+ '
			}' FROM 
				@tempTable T1 CROSS APPLY CustomColumns.nodes('/CustomColumnsCollection/CustomColumn') AS T2(cols)
			FOR XML PATH(''), TYPE).value('.','nvarchar(max)'), 1, 1, '') 
		+ ']');

	RETURN @result;

END;
GO

COMMIT TRANSACTION AlterFunction;
