SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing the requested scopes(s) for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiScopesSelect]
	@scope BIGINT = NULL,
	@scopeId NVARCHAR(20) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	SELECT *
	FROM RestApiScopes
	WHERE
		RestApiScope = COALESCE(@scope, RestApiScope)
		AND RestApiScopeId = COALESCE(@scopeId, RestApiScopeId)

	OPTION (OPTIMIZE FOR (@scope UNKNOWN, @scopeId UNKNOWN))	

END
GO
