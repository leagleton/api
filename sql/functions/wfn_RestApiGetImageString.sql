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
-- Description:	Function to SELECT image data as a base 64 string for the WinMan REST API.
-- =============================================

IF NOT EXISTS
(
	SELECT 
		[name]
	FROM
		sys.objects
	WHERE
		[object_id] = OBJECT_ID(N'[dbo].[wfn_RestApiGetImageString]')
		AND [type] IN (N'FN', N'IF', N'TF', N'FS', N'FT')
)
	BEGIN
		EXECUTE('CREATE FUNCTION dbo.wfn_RestApiGetImageString() RETURNS nvarchar(100) AS BEGIN RETURN ''dbo.wfn_RestApiGetImageString''; END;');
	END;
GO

ALTER FUNCTION [dbo].[wfn_RestApiGetImageString] 
(
	@image varbinary(max)
)
RETURNS nvarchar(max)
AS
BEGIN

	DECLARE @result nvarchar(max);
	SELECT @result = COALESCE((SELECT CAST('' AS xml).value('xs:base64Binary(sql:variable("@image"))', 'nvarchar(max)')), '');
	RETURN @result;

END;
GO

COMMIT TRANSACTION AlterFunction;
