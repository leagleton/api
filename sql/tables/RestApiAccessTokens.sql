SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Table for storing RestApiAccessTokens for the WinMan REST API.
-- =============================================

CREATE TABLE [dbo].[RestApiAccessTokens](
	[RestApiAccessToken] [bigint] IDENTITY(1,1) NOT NULL,
	[Expires] [datetime] NOT NULL,
	[Scopes] [nvarchar](1000) NOT NULL,
	[RestApiClient] [bigint] NOT NULL,
	[RestApiUser] [bigint] NOT NULL,
	[TokenUUID] [nvarchar](36) NOT NULL,
 CONSTRAINT [PK_RestApiAccessTokens] PRIMARY KEY CLUSTERED 
(
	[RestApiAccessToken] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[RestApiAccessTokens]  WITH CHECK ADD  CONSTRAINT [FK_RestApiAccessTokens_RestApiClients] FOREIGN KEY([RestApiClient])
REFERENCES [dbo].[RestApiClients] ([RestApiClient])
GO

ALTER TABLE [dbo].[RestApiAccessTokens] CHECK CONSTRAINT [FK_RestApiAccessTokens_RestApiClients]
GO

ALTER TABLE [dbo].[RestApiAccessTokens]  WITH CHECK ADD  CONSTRAINT [FK_RestApiAccessTokens_RestApiUsers] FOREIGN KEY([RestApiUser])
REFERENCES [dbo].[RestApiUsers] ([RestApiUser])
GO

ALTER TABLE [dbo].[RestApiAccessTokens] CHECK CONSTRAINT [FK_RestApiAccessTokens_RestApiUsers]
GO
