USE [WinManLE]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 21 August 2017
-- Description:	Function to fetch the data type of a custom column.
-- =============================================

CREATE FUNCTION [dbo].[wfn_RestApiGetCustomColumnDataType] 
(
	@DataType int
)
RETURNS NVARCHAR(8)
AS
BEGIN
	DECLARE @result NVARCHAR(8)
	SELECT @result = 
		CASE @DataType
			WHEN 0 THEN 'string'  -- VARCHAR
			WHEN 1 THEN 'date'    -- DATE
			WHEN 2 THEN 'decimal' -- DECIMAL
			WHEN 3 THEN 'integer' -- INTEGER
			WHEN 4 THEN 'integer' -- LONG
			WHEN 5 THEN 'boolean' -- BIT
			WHEN 6 THEN 'string'  -- TEXT
			ELSE ''
		END
	RETURN @result
END
GO
