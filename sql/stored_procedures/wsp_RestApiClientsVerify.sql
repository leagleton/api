SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for verifying the supplied client for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiClientsVerify]
	@length TINYINT,
	@scopes NVARCHAR(1000),
	@clientId NVARCHAR(32)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @str NVARCHAR(1000) = @scopes;

	CREATE TABLE #TempTable (scope NVARCHAR(20));
	
	WHILE LEN(@str) > 0
		BEGIN
			DECLARE @scope NVARCHAR(20);
			IF CHARINDEX(',', @str) > 0
				SET @scope = SUBSTRING(@str, 0, CHARINDEX(',', @str))
			ELSE
				BEGIN
					SET @scope = @str;
					SET @str = '';
				END
			
			INSERT INTO #TempTable VALUES (@scope);
			SET @str = REPLACE(@str, @scope + ',' , '');
		END
	
	IF @length = (SELECT COUNT(DISTINCT RestApiScopeId) 
					FROM RestApiScopes 
					WHERE RestApiScopeId IN (SELECT scope FROM #TempTable)) 
		BEGIN 
			(
			SELECT 
				RestApiClients.RestApiClient AS RestApiClient, 
				RestApiClients.RestApiClientId AS RestApiClientId,
				RestApiClients.[Secret] AS [Secret], 
				RestApiClients.RedirectURI AS RedirectURI, 
				RestApiUserClients.Scopes as Scopes 
			FROM 
				RestApiClients INNER JOIN RestApiUserClients 
					ON RestApiClients.RestApiClient = RestApiUserClients.RestApiClient 
			WHERE 
				RestApiClients.RestApiClientId = @clientId
				AND RestApiUserClients.Scopes = (SELECT STUFF(REPLACE((SELECT '#!' + LTRIM(RTRIM(r.RestApiScope)) AS 'data()' FROM RestApiScopes r 
													WHERE r.RestApiScopeId IN (SELECT scope FROM #TempTable) 
													FOR XML PATH('')),' #!',','), 1, 2, ''))
			)

			OPTION (OPTIMIZE FOR (@clientId UNKNOWN))

		END
	ELSE
		BEGIN
			(SELECT 'Scope not valid.' AS ErrorMessage)     
		END

END
GO
