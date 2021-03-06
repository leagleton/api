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
-- Description:	Stored procedure for SELECTing the requested access token for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiAccessTokensSelect'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiAccessTokensSelect AS PRINT ''dbo.wsp_RestApiAccessTokensSelect''');
	END;
GO

-- 03Apr18 LAE OAUTH2 tiemzone bug fix.

ALTER PROCEDURE [dbo].[wsp_RestApiAccessTokensSelect]
	@uuid nvarchar(36),
	@website nvarchar(100)
AS
BEGIN
	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	SELECT 
		t.Expires,
		t.Scopes,
		t.RestApiClient,
		t.RestApiUser,
		t.EcommerceWebsite
	FROM 
		RestApiAccessTokens t
		INNER JOIN EcommerceWebsites w ON t.EcommerceWebsite = w.EcommerceWebsite
	WHERE
		t.TokenUUID = @uuid
		-- 03Apr18 LAE
		--AND t.Expires > GETDATE()
		AND t.Expires > GETUTCDATE()
		AND w.EcommerceWebsiteId = @website
	GROUP BY
		t.Expires,
		t.Scopes,
		t.RestApiClient,
		t.RestApiUser,
		t.EcommerceWebsite;		

	--OPTION (OPTIMIZE FOR (@uuid UNKNOWN, @website UNKNOWN));

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
