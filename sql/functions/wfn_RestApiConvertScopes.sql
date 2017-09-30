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
-- Description:	Function to convert scopes from text to numeric for the WinMan REST API.
-- =============================================

IF NOT EXISTS
(
	SELECT 
		[name]
	FROM
		sys.objects
	WHERE
		[object_id] = OBJECT_ID(N'[dbo].[wfn_RestApiConvertScopes]')
		AND [type] IN (N'FN', N'IF', N'TF', N'FS', N'FT')
)
	BEGIN
		EXECUTE('CREATE FUNCTION dbo.wfn_RestApiConvertScopes() RETURNS nvarchar(100) AS BEGIN RETURN ''dbo.wfn_RestApiConvertScopes''; END;');
	END;
GO

ALTER FUNCTION [dbo].[wfn_RestApiConvertScopes] 
(
	@scopes nvarchar(1000)
)
RETURNS nvarchar(max)
AS
BEGIN

	DECLARE @str nvarchar(1000);
	DECLARE @tempTable table (scope bigint, scopeid nvarchar(50));
	DECLARE @direction nvarchar(8);
	DECLARE @convertedScopes nvarchar(1000);
	DECLARE @sql nvarchar(max);
	DECLARE @scopeId nvarchar(50);
	DECLARE @scopeNum bigint;

	SET @str = @scopes;
	
	WHILE LEN(@str) > 0
		BEGIN
			DECLARE @scope nvarchar(50);
			IF CHARINDEX(',', @str) > 0
				BEGIN
					SET @scope = SUBSTRING(@str, 0, CHARINDEX(',', @str));
					IF ISNUMERIC(@str) = 1
						BEGIN
							SET @direction = 'toString';
							SET @scopeId = (SELECT RestApiScopeId FROM RestApiScopes WHERE RestApiScope = @scope);

							INSERT INTO @tempTable (scopeid, scope) VALUES (@scopeId, CAST(@scope AS bigint));
						END;
					ELSE
						BEGIN
							SET @direction = 'toNumber';
							SET @scopeNum = (SELECT RestApiScope FROM RestApiScopes WHERE RestApiScopeId = @scope);

							INSERT INTO @tempTable (scopeid, scope) VALUES (@scope, @scopeNum);
						END;
				END;
			ELSE
				BEGIN
					SET @scope = @str;
					SET @str = '';

					IF ISNUMERIC(@scope) = 1
						BEGIN
							SET @direction = 'toString';
							SET @scopeId = (SELECT RestApiScopeId FROM RestApiScopes WHERE RestApiScope = @scope);

							INSERT INTO @tempTable (scopeid, scope) VALUES (@scopeId, CAST(@scope AS bigint));
						END;
					ELSE
						BEGIN
							SET @direction = 'toNumber';
							SET @scopeNum = (SELECT RestApiScope FROM RestApiScopes WHERE RestApiScopeId = @scope);

							INSERT INTO @tempTable (scopeid, scope) VALUES (@scope, @scopeNum);
						END;
				END
			SET @str = REPLACE(@str, @scope + ',' , '');
		END

	IF @direction = 'toString'
		BEGIN
			SET @convertedScopes = (SELECT STUFF(REPLACE((SELECT '#!' + LTRIM(RTRIM(scopeid)) AS 'data()' FROM @tempTable 
														ORDER BY scope ASC
														FOR XML PATH('')),' #!',','), 1, 2, ''));
		END;
	ELSE
		BEGIN
			SET @convertedScopes = (SELECT STUFF(REPLACE((SELECT '#!' + LTRIM(RTRIM(scope)) AS 'data()' FROM @tempTable 
														ORDER BY scope ASC
														FOR XML PATH('')),' #!',','), 1, 2, ''));
		END;

	RETURN @convertedScopes;

END;
GO

COMMIT TRANSACTION AlterFunction;
