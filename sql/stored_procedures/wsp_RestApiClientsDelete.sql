SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure to DELETE the specified client for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiClientsDelete]
	@client BIGINT
AS
BEGIN
	SET NOCOUNT ON;

	DELETE FROM
		RestApiUserClients
	WHERE
		RestApiClient = @client

	DELETE FROM
		RestApiAuthorisationCodes
	WHERE
		RestApiClient = @client

	DELETE FROM
		RestApiAccessTokens
	WHERE
		RestApiClient = @client

	DELETE FROM
		RestApiClients
	WHERE
		RestApiClient = @client

	OPTION (OPTIMIZE FOR (@client UNKNOWN))

END
GO
