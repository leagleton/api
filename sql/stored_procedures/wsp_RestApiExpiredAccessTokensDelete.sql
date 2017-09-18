SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure to DELETE expired Access Tokens for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiExpiredAccessTokensDelete]
AS
BEGIN
	SET NOCOUNT ON;

	DELETE FROM 
		RestApiAccessTokens 
	WHERE 
		Expires < GETDATE()

	DELETE FROM 
		RestApiAuthorisationCodes
	WHERE 
		Expires < GETDATE()

END
GO
