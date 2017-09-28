SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 29 September 2017
-- Description:	Table for storing RestApiUsers linked to EcommerceWebsites for the WinMan REST API.
-- =============================================

CREATE TABLE [dbo].[RestApiUsersEcommerceWebsites](
	[RestApiUserEcommerceWebsite] [bigint] IDENTITY(1,1) NOT NULL,
	[RestApiUser] [bigint] NOT NULL,
	[EcommerceWebsite] [bigint] NOT NULL,
	[CreatedUser] [nvarchar](20) NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
	[LastModifiedUser] [nvarchar](20) NOT NULL,
	[LastModifiedDate] [datetime] NOT NULL,
 CONSTRAINT [PK_RestApiUsersEcommerceWebsites] PRIMARY KEY CLUSTERED 
(
	[RestApiUserEcommerceWebsite] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[RestApiUsersEcommerceWebsites]  WITH CHECK ADD  CONSTRAINT [FK_RestApiUsersEcommerceWebsites_EcommerceWebsites] FOREIGN KEY([EcommerceWebsite])
REFERENCES [dbo].[EcommerceWebsites] ([EcommerceWebsite])
GO

ALTER TABLE [dbo].[RestApiUsersEcommerceWebsites] CHECK CONSTRAINT [FK_RestApiUsersEcommerceWebsites_EcommerceWebsites]
GO

ALTER TABLE [dbo].[RestApiUsersEcommerceWebsites]  WITH CHECK ADD  CONSTRAINT [FK_RestApiUsersEcommerceWebsites_RestApiUsers] FOREIGN KEY([RestApiUser])
REFERENCES [dbo].[RestApiUsers] ([RestApiUser])
GO

ALTER TABLE [dbo].[RestApiUsersEcommerceWebsites] CHECK CONSTRAINT [FK_RestApiUsersEcommerceWebsites_RestApiUsers]
GO
