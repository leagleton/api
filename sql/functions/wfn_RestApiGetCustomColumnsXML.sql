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
-- Description:	Function to SELECT custom columns for a product as XML for the WinMan REST API.
-- =============================================

IF NOT EXISTS
(
	SELECT 
		[name]
	FROM
		sys.objects
	WHERE
		[object_id] = OBJECT_ID(N'[dbo].[wfn_RestApiGetCustomColumnsXML]')
		AND [type] IN (N'FN', N'IF', N'TF', N'FS', N'FT')
)
	BEGIN
		EXECUTE('CREATE FUNCTION dbo.wfn_RestApiGetCustomColumnsXML() RETURNS nvarchar(100) AS BEGIN RETURN ''dbo.wfn_RestApiGetCustomColumnsXML''; END;');
	END;
GO

ALTER FUNCTION [dbo].[wfn_RestApiGetCustomColumnsXML] 
(
	@product bigint
)
RETURNS xml
AS
BEGIN
	DECLARE @result xml;
	DECLARE @xml xml;
	DECLARE @tempTable table (CustomColumns xml);

	SELECT @xml = COALESCE((SELECT CustomColumns FROM Products WHERE Product = @product), '');
	
	INSERT INTO @tempTable SELECT @xml;
	
	SELECT @result = 
		(SELECT CAST(
				'<' + CAST(cols.query('data(Name)') AS nvarchar(max)) + '>' 
					+ CAST(cols.query('data(Value)') AS nvarchar(max)) + 
				'</' + CAST(cols.query('data(Name)') AS nvarchar(max)) + '>' 
			AS xml)
		FROM 
			@tempTable T1 CROSS APPLY CustomColumns.nodes('/CustomColumnsCollection/CustomColumn') AS T2(cols)
		FOR XML PATH('CustomColumn'));

	RETURN @result;

END;
GO

COMMIT TRANSACTION AlterFunction;
