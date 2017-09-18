SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Function to convert scopes from text to numeric for the WinMan REST API.
-- =============================================

CREATE FUNCTION [dbo].[wfn_RestApiConvertScopes] 
(
	@scopes NVARCHAR(20)
)
RETURNS NVARCHAR(max)
AS
BEGIN
	DECLARE @str NVARCHAR(20) = @scopes;
	DECLARE @tempTable TABLE (scope BIGINT, scopeid NVARCHAR(10));
	DECLARE @direction NVARCHAR(8);
	DECLARE @convertedScopes NVARCHAR(20);
	DECLARE @sql NVARCHAR(max);
	
	WHILE LEN(@str) > 0
		BEGIN
			DECLARE @scope NVARCHAR(10);
			IF CHARINDEX(',', @str) > 0
				BEGIN
					SET @scope = SUBSTRING(@str, 0, CHARINDEX(',', @str))
					IF ISNUMERIC(@str) = 1
						BEGIN
							SET @direction = 'toString';
							INSERT INTO @tempTable (scope) VALUES (CAST(@scope AS BIGINT));
						END
					ELSE
						BEGIN
							SET @direction = 'toNumber';
							INSERT INTO @tempTable (scopeid) VALUES (@scope);
						END
				END
			ELSE
				BEGIN
					SET @scope = @str;
					SET @str = '';

					IF ISNUMERIC(@scope) = 1
						BEGIN
							SET @direction = 'toString';
							INSERT INTO @tempTable (scope) VALUES (CAST(@scope AS BIGINT));
						END
					ELSE
						BEGIN
							SET @direction = 'toNumber';
							INSERT INTO @tempTable (scopeid) VALUES (@scope);
						END
				END
			SET @str = REPLACE(@str, @scope + ',' , '');
		END

	IF @direction = 'toString'
		BEGIN
			SET @convertedScopes = (SELECT STUFF(REPLACE((SELECT '#!' + LTRIM(RTRIM(RestApiScopeId)) AS 'data()' FROM RestApiScopes 
														WHERE RestApiScope IN (SELECT scope FROM @tempTable) 
														FOR XML PATH('')),' #!',','), 1, 2, ''));
		END
	ELSE
		BEGIN
			SET @convertedScopes = (SELECT STUFF(REPLACE((SELECT '#!' + LTRIM(RTRIM(RestApiScope)) AS 'data()' FROM RestApiScopes 
														WHERE RestApiScopeId IN (SELECT scopeid FROM @tempTable) 
														FOR XML PATH('')),' #!',','), 1, 2, ''))
		END

	RETURN @convertedScopes;
END
GO
