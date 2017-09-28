SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 29 September 2017
-- Description:	Table for storing RestApiScopes linked to EcommerceWebsites for the WinMan REST API.
-- =============================================

CREATE TABLE [dbo].[RestApiScopesEcommerceWebsites](
	[RestApiScopeEcommerceWebsite] [bigint] IDENTITY(1,1) NOT NULL,
	[RestApiScope] [bigint] NOT NULL,
	[EcommerceWebsite] [bigint] NOT NULL,
	[CreatedUser] [nvarchar](20) NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
	[LastModifiedUser] [nvarchar](20) NOT NULL,
	[LastModifiedDate] [datetime] NOT NULL,
 CONSTRAINT [PK_RestApiScopesEcommerceWebsites] PRIMARY KEY CLUSTERED 
(
	[RestApiScopeEcommerceWebsite] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[RestApiScopesEcommerceWebsites]  WITH CHECK ADD  CONSTRAINT [FK_RestApiScopesEcommerceWebsites_EcommerceWebsites] FOREIGN KEY([EcommerceWebsite])
REFERENCES [dbo].[EcommerceWebsites] ([EcommerceWebsite])
GO

ALTER TABLE [dbo].[RestApiScopesEcommerceWebsites] CHECK CONSTRAINT [FK_RestApiScopesEcommerceWebsites_EcommerceWebsites]
GO

ALTER TABLE [dbo].[RestApiScopesEcommerceWebsites]  WITH CHECK ADD  CONSTRAINT [FK_RestApiScopesEcommerceWebsites_RestApiScopes] FOREIGN KEY([RestApiScope])
REFERENCES [dbo].[RestApiScopes] ([RestApiScope])
GO

ALTER TABLE [dbo].[RestApiScopesEcommerceWebsites] CHECK CONSTRAINT [FK_RestApiScopesEcommerceWebsites_RestApiScopes]
GO
