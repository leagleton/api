SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 29 September 2017
-- Description:	Stored procedure to UPDATE the requested user for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiUsersUpdate]
	@user BIGINT,
	@password NVARCHAR(60) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	UPDATE
		RestApiUsers
	SET
		[Password] = COALESCE(@password, [Password])
	WHERE
		RestApiUser = @user

	OPTION (OPTIMIZE FOR (@user UNKNOWN))	

END
GO
