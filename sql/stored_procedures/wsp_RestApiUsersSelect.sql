SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing the requested user(s) for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiUsersSelect]
	@user BIGINT = NULL,
	@userId NVARCHAR(32) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	SELECT *
	FROM RestApiUsers
	WHERE
		RestApiUser = COALESCE(@user, RestApiUser)
		AND RestApiUserId = COALESCE(@userId, RestApiUserId)

	OPTION (OPTIMIZE FOR (@user UNKNOWN, @userId UNKNOWN))	

END
GO
