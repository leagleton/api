SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Table for storing EcommerceWebsites for the WinMan REST API.
-- =============================================

CREATE TABLE [dbo].[EcommerceWebsites](
	[EcommerceWebsite] [bigint] IDENTITY(1,1) NOT NULL,
	[EcommerceWebsiteId] [nvarchar](100) NOT NULL,
	[RestApiUser] [bigint] NULL,
	[SalesOrderPrefix] [bigint] NOT NULL,
	[CreatedUser] [nvarchar](20) NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
	[LastModifiedUser] [nvarchar](20) NOT NULL,
	[LastModifiedDate] [datetime] NOT NULL,
 CONSTRAINT [PK_EcommerceWebsites] PRIMARY KEY CLUSTERED 
(
	[EcommerceWebsite] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[EcommerceWebsites]  WITH CHECK ADD  CONSTRAINT [FK_EcommerceWebsites_RestApiUsers] FOREIGN KEY([RestApiUser])
REFERENCES [dbo].[RestApiUsers] ([RestApiUser])
GO

ALTER TABLE [dbo].[EcommerceWebsites] CHECK CONSTRAINT [FK_EcommerceWebsites_RestApiUsers]
GO

ALTER TABLE [dbo].[EcommerceWebsites]  WITH CHECK ADD  CONSTRAINT [FK_EcommerceWebsites_SalesOrderPrefixes] FOREIGN KEY([SalesOrderPrefix])
REFERENCES [dbo].[SalesOrderPrefixes] ([SalesOrderPrefix])
GO

ALTER TABLE [dbo].[EcommerceWebsites] CHECK CONSTRAINT [FK_EcommerceWebsites_SalesOrderPrefixes]
GO
