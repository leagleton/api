SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

BEGIN TRANSACTION AlterProcedure;

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 21 October 2017
-- Description:	Stored procedure for SELECTing the requested eCommerceWebsite(s) for the WinMan REST API.
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
		AND p.[name] = 'wsp_RestApiEcommerceWebsitesSelect'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiEcommerceWebsitesSelect AS PRINT ''wsp_RestApiEcommerceWebsitesSelect''');
	END;
GO

ALTER PROCEDURE dbo.wsp_RestApiEcommerceWebsitesSelect
	@website bigint = null,
	@websiteId nvarchar(32) = null,
	@user bigint = null
AS
BEGIN
	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	SELECT 
        w.EcommerceWebsite,
        w.EcommerceWebsiteId
	FROM EcommerceWebsites w
		INNER JOIN RestApiUserEcommerceWebsites u ON w.EcommerceWebsite = u.EcommerceWebsite
	WHERE
		w.EcommerceWebsite = COALESCE(@website, w.EcommerceWebsite)
		AND w.EcommerceWebsiteId = COALESCE(@websiteId, w.EcommerceWebsiteId)
		AND u.RestApiUser = COALESCE(@user, u.RestApiUser)
    GROUP BY
        w.EcommerceWebsite,
        w.EcommerceWebsiteId;

	--OPTION (OPTIMIZE FOR (@website UNKNOWN, @websiteId UNKNOWN, @user UNKNOWN));	

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
