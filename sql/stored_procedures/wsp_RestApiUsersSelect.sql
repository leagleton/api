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
-- Description:	Stored procedure for SELECTing the requested user(s) for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiUsersSelect'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiUsersSelect AS PRINT ''wsp_RestApiUsersSelect''');
	END;
GO

ALTER PROCEDURE dbo.wsp_RestApiUsersSelect
	@user bigint = null,
	@userId nvarchar(32) = null,
	@website bigint = null
AS
BEGIN
	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	SELECT 
		r.RestApiUser,
		r.RestApiUserId,
		r.[Name],
		r.[Password],
		r.IsActive,
		r.CreatedUser,
		r.CreatedDate,
		r.LastModifiedUser,
		r.LastModifiedDate
	FROM 
		RestApiUsers r
		INNER JOIN RestApiUserEcommerceWebsites e ON r.RestApiUser = e.RestApiUser
	WHERE
		r.RestApiUser = COALESCE(@user, r.RestApiUser)
		AND r.RestApiUserId = COALESCE(@userId, r.RestApiUserId)
		AND r.IsActive = 1
		AND e.EcommerceWebsite = COALESCE(@website, e.EcommerceWebsite)
	GROUP BY
		r.RestApiUser,
		r.RestApiUserId,
		r.[Name],
		r.[Password],
		r.IsActive,
		r.CreatedUser,
		r.CreatedDate,
		r.LastModifiedUser,
		r.LastModifiedDate;

	--OPTION (OPTIMIZE FOR (@user UNKNOWN, @userId UNKNOWN, @website UNKNOWN));

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
