SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Function to SELECT image data as a base 64 string for the WinMan REST API.
-- =============================================

CREATE FUNCTION [dbo].[wfn_RestApiGetImageString] 
(
	@image VARBINARY(max)
)
RETURNS NVARCHAR(max)
AS
BEGIN
	DECLARE @result NVARCHAR(max)
	SELECT @result = COALESCE((SELECT CAST('' AS XML).value('xs:base64Binary(sql:variable("@image"))', 'NVARCHAR(MAX)')), '')
	RETURN @result
END
GO
