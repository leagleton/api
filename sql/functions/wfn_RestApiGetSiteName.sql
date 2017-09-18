SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Function to SELECT a site name for the WinMan REST API.
-- =============================================

CREATE FUNCTION [dbo].[wfn_RestApiGetSiteName] 
(
	@site BIGINT = NULL
)
RETURNS NVARCHAR(20)
AS
BEGIN

	IF @site IS NULL
		BEGIN
			IF (SELECT COUNT([Site]) FROM Sites) = 1
			BEGIN
				SET @site = (SELECT TOP 1 [Site] FROM Sites)
			END
		END

	DECLARE @result NVARCHAR(20)

	SELECT @result = (SELECT SiteName FROM Sites WHERE [Site] = @site)

	RETURN @result
END
GO
