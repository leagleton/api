SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 29 September 2017
-- Description:	Table for storing RestApiScopes linked to EcommerceWebsites for the WinMan REST API.
-- =============================================

CREATE TABLE [dbo].[RestApiScopeEcommerceWebsites](
	[RestApiScopeEcommerceWebsite] [bigint] IDENTITY(1,1) NOT NULL,
	[RestApiScope] [bigint] NOT NULL,
	[EcommerceWebsite] [bigint] NOT NULL,
	[CreatedUser] [nvarchar](20) NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
	[LastModifiedUser] [nvarchar](20) NOT NULL,
	[LastModifiedDate] [datetime] NOT NULL,
	[Comments] [nvarchar](500) NOT NULL,
 CONSTRAINT [PK_RestApiScopeEcommerceWebsites] PRIMARY KEY CLUSTERED 
(
	[RestApiScopeEcommerceWebsite] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[RestApiScopeEcommerceWebsites]  WITH CHECK ADD  CONSTRAINT [FK_RestApiScopeEcommerceWebsites_EcommerceWebsites] FOREIGN KEY([EcommerceWebsite])
REFERENCES [dbo].[EcommerceWebsites] ([EcommerceWebsite])
GO

ALTER TABLE [dbo].[RestApiScopeEcommerceWebsites] CHECK CONSTRAINT [FK_RestApiScopeEcommerceWebsites_EcommerceWebsites]
GO

ALTER TABLE [dbo].[RestApiScopeEcommerceWebsites]  WITH CHECK ADD  CONSTRAINT [FK_RestApiScopeEcommerceWebsites_RestApiScopes] FOREIGN KEY([RestApiScope])
REFERENCES [dbo].[RestApiScopes] ([RestApiScope])
GO

ALTER TABLE [dbo].[RestApiScopeEcommerceWebsites] CHECK CONSTRAINT [FK_RestApiScopeEcommerceWebsites_RestApiScopes]
GO
