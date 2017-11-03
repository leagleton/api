SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Table for storing RestApiAuthorisationCodes for the WinMan REST API.
-- =============================================

CREATE TABLE [dbo].[RestApiAuthorisationCodes](
	[RestApiAuthorisationCode] [bigint] IDENTITY(1,1) NOT NULL,
	[Expires] [datetime] NOT NULL,
	[Scopes] [nvarchar](1000) NOT NULL,
	[RestApiClient] [bigint] NOT NULL,
	[RestApiUser] [bigint] NOT NULL,
	[CodeUUID] [nvarchar](36) NOT NULL,
	[RedirectURI] [nvarchar](100) NOT NULL,
	[EcommerceWebsite] [bigint] NOT NULL,
 CONSTRAINT [PK_RestApiAuthorisationCodes] PRIMARY KEY CLUSTERED 
(
	[RestApiAuthorisationCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[RestApiAuthorisationCodes]  WITH CHECK ADD  CONSTRAINT [FK_RestApiAuthorisationCodes_EcommerceWebsites] FOREIGN KEY([EcommerceWebsite])
REFERENCES [dbo].[EcommerceWebsites] ([EcommerceWebsite])
GO

ALTER TABLE [dbo].[RestApiAuthorisationCodes] CHECK CONSTRAINT [FK_RestApiAuthorisationCodes_EcommerceWebsites]
GO

ALTER TABLE [dbo].[RestApiAuthorisationCodes]  WITH CHECK ADD  CONSTRAINT [FK_RestApiAuthorisationCodes_RestApiClients] FOREIGN KEY([RestApiClient])
REFERENCES [dbo].[RestApiClients] ([RestApiClient])
GO

ALTER TABLE [dbo].[RestApiAuthorisationCodes] CHECK CONSTRAINT [FK_RestApiAuthorisationCodes_RestApiClients]
GO

ALTER TABLE [dbo].[RestApiAuthorisationCodes]  WITH CHECK ADD  CONSTRAINT [FK_RestApiAuthorisationCodes_RestApiUsers] FOREIGN KEY([RestApiUser])
REFERENCES [dbo].[RestApiUsers] ([RestApiUser])
GO

ALTER TABLE [dbo].[RestApiAuthorisationCodes] CHECK CONSTRAINT [FK_RestApiAuthorisationCodes_RestApiUsers]
GO
