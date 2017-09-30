SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Table for storing RestApiScopes for the WinMan REST API.
-- =============================================

CREATE TABLE [dbo].[RestApiScopes](
	[RestApiScope] [bigint] IDENTITY(1,1) NOT NULL,
	[RestApiScopeId] [nvarchar](50) NOT NULL,
	[Description] [nvarchar](100) NOT NULL,
 CONSTRAINT [PK_RestApiScopes] PRIMARY KEY CLUSTERED 
(
	[RestApiScope] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
