SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Stored procedure for SELECTing product web attachments for the WinMan REST API in JSON format.
-- =============================================

CREATE PROCEDURE [dbo].[wsp_RestApiDocumentsSelectJSON]
	@sku NVARCHAR(100),
	@seconds BIGINT = 315360000,
	@website NVARCHAR(100),
	@results NVARCHAR(max) OUTPUT
AS
BEGIN

	IF dbo.wfn_BespokeSPExists('bsp_RestApiDocumentsSelectJSON') = 1 
	BEGIN
		EXEC dbo.bsp_RestApiDocumentsSelectJSON
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
										TYPE).value('.','NVARCHAR(4000)'), 1, 1, '')
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
		FOR XML PATH(''), 
				TYPE).value('.','NVARCHAR(max)'), 1, 1, '' 
		)), '')

	OPTION (OPTIMIZE FOR (@sku UNKNOWN, @lastModifiedDate UNKNOWN, @website UNKNOWN, @results UNKNOWN))		

	SELECT @results = REPLACE(REPLACE(REPLACE('{"ProductAttachments":[' + @results + ']}', CHAR(13),''), CHAR(10),''), CHAR(9), '')

	SELECT @results

END
GO
