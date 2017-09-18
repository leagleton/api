SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Table for storing RestApiClients for the WinMan REST API.
-- =============================================

CREATE TABLE [dbo].[RestApiClients](
	[RestApiClient] [bigint] IDENTITY(1,1) NOT NULL,
	[RestApiClientId] [nvarchar](32) NOT NULL,
	[Secret] [nvarchar](32) NOT NULL,
	[RedirectURI] [nvarchar](100) NOT NULL,
 CONSTRAINT [PK_RestApiClients] PRIMARY KEY CLUSTERED 
(
	[RestApiClient] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
