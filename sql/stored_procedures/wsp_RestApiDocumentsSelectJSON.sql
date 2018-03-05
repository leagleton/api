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
-- Description:	Stored procedure for SELECTing product web attachments for the WinMan REST API in JSON format.
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
		AND p.[name] = 'wsp_RestApiDocumentsSelectJSON'
		AND s.[name] = 'dbo'
)
	BEGIN
		EXECUTE('CREATE PROCEDURE dbo.wsp_RestApiDocumentsSelectJSON AS PRINT ''dbo.wsp_RestApiDocumentsSelectJSON''');
	END;
GO

ALTER PROCEDURE [dbo].[wsp_RestApiDocumentsSelectJSON]
	@sku nvarchar(100),
	@seconds bigint = 315360000,
	@website nvarchar(100),
	@scope nvarchar(50),
	@results nvarchar(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiDocumentsSelectJSON') = 1 
		BEGIN
			EXEC dbo.bsp_RestApiDocumentsSelectJSON
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
			SELECT 'The relevant REST API scope is not enabled for the specified website.' AS ErrorMessage;
			ROLLBACK TRANSACTION;
			RETURN;
		END;	

	DECLARE @lastModifiedDate datetime;

	SET @lastModifiedDate = (SELECT DATEADD(second,-@seconds,GETDATE()));
	
	SELECT @results = COALESCE(
		(SELECT
			STUFF(
				(SELECT ',{
					"ProductSku":"' + p.ProductId + '",
					"Attachments":' + 
						COALESCE(
							(SELECT '[' +
								STUFF(
									(SELECT ',{
										"Type":"' + d.TableName + '",
										"FileName":"' + d.DocumentFileName + '",
										"Data":"' + dbo.wfn_RestApiGetImageString(d.DocumentData) + '"
									}' FROM
										Documents d
									WHERE 
										d.Identifier = p.Product
										AND d.LastModifiedDate >= @lastModifiedDate
										AND d.TableName IN ('WebDocuments', 'WebImages')
										AND d.DocumentArchived = 0
									FOR XML PATH(''),
									TYPE).value('.','nvarchar(max)'), 1, 1, '')
							+ ']'),
						'[]')
					+ '
				}' FROM
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
				FOR XML PATH(''), 
						TYPE).value('.','nvarchar(max)'), 1, 1, '' 
			)), '');	

	SELECT @results = REPLACE(REPLACE(REPLACE(REPLACE('{"ProductAttachments":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), ''), '\', '\\');

	SELECT @results AS Results;

	COMMIT TRANSACTION;

END;
GO

COMMIT TRANSACTION AlterProcedure;
