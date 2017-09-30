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
-- Description:	Function to SELECT a site name for the WinMan REST API.
-- =============================================

IF NOT EXISTS
(
	SELECT 
		[name]
	FROM
		sys.objects
	WHERE
		[object_id] = OBJECT_ID(N'[dbo].[wfn_RestApiGetSiteName]')
		AND [type] IN (N'FN', N'IF', N'TF', N'FS', N'FT')
)
	BEGIN
		EXECUTE('CREATE FUNCTION dbo.wfn_RestApiGetSiteName() RETURNS nvarchar(100) AS BEGIN RETURN ''dbo.wfn_RestApiGetSiteName''; END;');
	END;
GO

ALTER FUNCTION [dbo].[wfn_RestApiGetSiteName] 
(
	@site bigint = null
)
RETURNS nvarchar(20)
AS
BEGIN

	IF @site IS NULL
		BEGIN
			IF (SELECT COUNT([Site]) FROM Sites) = 1
				BEGIN
					SET @site = (SELECT TOP 1 [Site] FROM Sites);
				END;
		END;

	DECLARE @result nvarchar(20);

	SELECT @result = (SELECT SiteName FROM Sites WHERE [Site] = @site);

	RETURN @result;

END;
GO

COMMIT TRANSACTION AlterFunction;
