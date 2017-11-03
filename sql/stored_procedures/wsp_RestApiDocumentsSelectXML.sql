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
-- Description:	Stored procedure for SELECTing product web attachments for the WinMan REST API in XML format.
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
		AND p.[name] = 'wsp_RestApiDocumentsSelectXML'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiDocumentsSelectXML AS PRINT ''wsp_RestApiDocumentsSelectXML''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiDocumentsSelectXML]
	@sku nvarchar(100),
	@seconds bigint = 315360000,
	@website nvarchar(100),
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiDocumentsSelectXML') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiDocumentsSelectXML
				@sku = @sku,
				@seconds = @seconds,
				@website = @website,
				@scope = @scope,
				@results = @results;
			RETURN;	
		END;

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	BEGIN TRANSACTION;	

	IF NOT EXISTS (
		SELECT 
			s.RestApiScope 
		FROM 
			RestApiScopeEcommerceWebsites sw
			INNER JOIN RestApiScopes s ON sw.RestApiScope = s.RestApiScope
			INNER JOIN EcommerceWebsites w ON sw.EcommerceWebsite = w.EcommerceWebsite
		WHERE
			s.RestApiScopeId = @scope
			AND w.EcommerceWebsiteId = @website
	)
		BEGIN
			SELECT 'ERROR: Scope not enabled for specified website.' AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;	

	DECLARE @lastModifiedDate datetime;

	SET @lastModifiedDate = (SELECT DATEADD(second,-@seconds,GETDATE()));
	
	SELECT @results = 
		CONVERT(nvarchar(max), (SELECT
			p.ProductId AS ProductSku,
			(SELECT 
				d.TableName AS [Type], 
				d.DocumentFileName AS [FileName],
				d.DocumentData AS [Data]
			FROM 
				Documents d 
			WHERE 
				d.Identifier = p.Product
				AND d.LastModifiedDate >= @lastModifiedDate
				AND d.TableName IN ('WebDocuments', 'WebImages')
				AND d.DocumentArchived = 0
			FOR XML PATH('Attachment'), TYPE) AS Attachments,
			'' AS Attachments
		FROM
			Products p
			INNER JOIN ProductEcommerceWebsites pew ON p.Product = pew.Product
			INNER JOIN EcommerceWebsites ew ON ew.EcommerceWebsite = pew.EcommerceWebsite
		WHERE
			p.ProductId = @sku
			AND ew.EcommerceWebsiteId = @website
			AND EXISTS (SELECT doc.Document FROM Documents doc WHERE doc.Identifier = p.Product)
		GROUP BY
			p.Product,
			p.ProductId
		FOR XML PATH('ProductAttachment'), TYPE));

	--OPTION (OPTIMIZE FOR (@sku UNKNOWN, @lastModifiedDate UNKNOWN, @website UNKNOWN));

	IF @results IS NOT NULL AND @results <> ''
		BEGIN
			SELECT @results = '<ProductAttachments>' + @results + '</ProductAttachments>';
		END;
	ELSE
		BEGIN
			SELECT @results = '<ProductAttachments/>';
		END;

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
