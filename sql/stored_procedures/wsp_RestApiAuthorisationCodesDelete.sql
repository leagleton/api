SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure to DELETE used authorisation codes for the WinMan REST API.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiAuthorisationCodesDelete]
	@uuid NVARCHAR(36)
AS
BEGIN
	SET NOCOUNT ON;

	DELETE FROM
		RestApiAuthorisationCodes
	WHERE
		CodeUUID = @uuid

	OPTION (OPTIMIZE FOR (@uuid UNKNOWN))
			
END
GO
