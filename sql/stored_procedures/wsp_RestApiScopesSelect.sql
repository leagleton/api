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
-- Description:	Stored procedure for SELECTing the requested scopes(s) for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiScopesSelect'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiScopesSelect AS PRINT ''wsp_RestApiScopesSelect''');
	END;
GO

ALTER PROCEDURE dbo.wsp_RestApiScopesSelect
	@scope bigint = null,
	@scopeId nvarchar(50) = null,
	@website bigint = null
AS
BEGIN
	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	SELECT 
		r.RestApiScope,
		r.RestApiScopeId,
		r.Description
	FROM 
		RestApiScopes r
		INNER JOIN RestApiScopeEcommerceWebsites e ON r.RestApiScope = e.RestApiScope
	WHERE
		r.RestApiScope = COALESCE(@scope, r.RestApiScope)
		AND r.RestApiScopeId = COALESCE(@scopeId, r.RestApiScopeId)
		AND e.EcommerceWebsite = COALESCE(@website, e.EcommerceWebsite)
	GROUP BY
		r.RestApiScope,
		r.RestApiScopeId,
		r.Description;

	--OPTION (OPTIMIZE FOR (@scope UNKNOWN, @scopeId UNKNOWN, @website UNKNOWN));	

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
