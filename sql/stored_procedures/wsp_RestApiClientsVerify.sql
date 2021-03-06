SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for verifying the supplied client for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiClientsVerify'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiClientsVerify AS PRINT ''dbo.wsp_RestApiClientsVerify''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiClientsVerify]
	@length tinyint,
	@scopes nvarchar(1000),
	@clientId nvarchar(32)
AS
BEGIN
	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	DECLARE @str nvarchar(1000);
	SET @str = @scopes;

	CREATE TABLE #TempTable (scope bigint, scopeId nvarchar(50));
	
	WHILE LEN(@str) > 0
		BEGIN
			DECLARE @scopeId nvarchar(50);
			IF CHARINDEX(',', @str) > 0
				SET @scopeId = SUBSTRING(@str, 0, CHARINDEX(',', @str));
			ELSE
				BEGIN
					SET @scopeId = @str;
					SET @str = '';
				END;

			DECLARE @scope bigint;
			SET @scope = (SELECT RestApiScope FROM RestApiScopes WHERE RestApiScopeId = @scopeId);
			
			INSERT INTO #TempTable (scope, scopeId) VALUES (@scope, @scopeId);
			SET @str = REPLACE(@str, @scopeId + ',' , '');
		END;
	
	IF @length = (SELECT COUNT(DISTINCT RestApiScopeId) 
					FROM RestApiScopes 
					WHERE RestApiScopeId IN (SELECT scopeId FROM #TempTable)) 
		BEGIN 
			SELECT 
				RestApiClients.RestApiClient AS RestApiClient, 
				RestApiClients.RestApiClientId AS RestApiClientId,
				RestApiClients.[Secret] AS [Secret], 
				RestApiClients.RedirectURI AS RedirectURI, 
				RestApiUserClients.Scopes AS Scopes 
			FROM 
				RestApiClients INNER JOIN RestApiUserClients 
					ON RestApiClients.RestApiClient = RestApiUserClients.RestApiClient 
			WHERE 
				RestApiClients.RestApiClientId = @clientId
				AND RestApiUserClients.Scopes = (SELECT STUFF(REPLACE((SELECT '#!' + LTRIM(RTRIM(scope)) AS 'data()' FROM #TempTable 
													ORDER BY scope
													FOR XML PATH('')),' #!',','), 1, 2, ''))
			GROUP BY
				RestApiClients.RestApiClient, 
				RestApiClients.RestApiClientId,
				RestApiClients.[Secret], 
				RestApiClients.RedirectURI, 
				RestApiUserClients.Scopes;

			--OPTION (OPTIMIZE FOR (@clientId UNKNOWN));

		END;
	ELSE
		BEGIN
			SELECT 'ERROR: Scope not valid.' AS ErrorMessage;
		END;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
