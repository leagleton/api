SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing product web attachments for the WinMan REST API in XML format.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiDocumentsSelectXML]
	@sku NVARCHAR(100),
	@seconds BIGINT = 315360000,
	@website NVARCHAR(100),
	@results NVARCHAR(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiDocumentsSelectXML') = 1 
	BEGIN
		EXEC dbo.bsp_RestApiDocumentsSelectXML
			@sku = @sku,
			@seconds = @seconds,
			@website = @website,
			@results = @results
		RETURN	
	END

	SET NOCOUNT ON;

	DECLARE 
		@lastModifiedDate DATETIME

	SET @lastModifiedDate = (SELECT DATEADD(second,-@seconds,GETDATE()));
	
	SELECT @results = 
		(SELECT
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
			FOR XML PATH('Attachment'), TYPE) AS Attachments
		FROM
			Products p
			INNER JOIN ProductEcommerceWebsites pew ON p.Product = pew.Product
			INNER JOIN EcommerceWebsites ew ON ew.EcommerceWebsite = pew.EcommerceWebsite
		WHERE
			p.ProductId = @sku
			AND ew.EcommerceWebsiteId = @website
			AND EXISTS (SELECT doc.Document FROM Documents doc WHERE doc.Identifier = p.Product)
		FOR XML PATH('ProductAttachment'))

	OPTION (OPTIMIZE FOR (@sku UNKNOWN, @lastModifiedDate UNKNOWN, @website UNKNOWN, @results UNKNOWN))	

	SELECT @results = CONCAT('<ProductAttachments>', @results, '</ProductAttachments>')

	SELECT @results

END
GO
