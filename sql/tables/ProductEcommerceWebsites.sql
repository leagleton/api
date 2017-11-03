SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Table for storing Products linked to EcommerceWebsites for the WinMan REST API.
-- =============================================

CREATE TABLE [dbo].[ProductEcommerceWebsites](
	[ProductEcommerceWebsite] [bigint] IDENTITY(1,1) NOT NULL,
	[Product] [bigint] NOT NULL,
	[EcommerceWebsite] [bigint] NOT NULL,
	[CreatedUser] [nvarchar](20) NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
	[LastModifiedUser] [nvarchar](20) NOT NULL,
	[LastModifiedDate] [datetime] NOT NULL,
	[Comments] [nvarchar](500) NOT NULL,
 CONSTRAINT [PK_ProductEcommerceWebsites] PRIMARY KEY CLUSTERED 
(
	[ProductEcommerceWebsite] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[ProductEcommerceWebsites]  WITH CHECK ADD  CONSTRAINT [FK_ProductEcommerceWebsites_EcommerceWebsites] FOREIGN KEY([EcommerceWebsite])
REFERENCES [dbo].[EcommerceWebsites] ([EcommerceWebsite])
GO

ALTER TABLE [dbo].[ProductEcommerceWebsites] CHECK CONSTRAINT [FK_ProductEcommerceWebsites_EcommerceWebsites]
GO

ALTER TABLE [dbo].[ProductEcommerceWebsites]  WITH CHECK ADD  CONSTRAINT [FK_ProductEcommerceWebsites_Products] FOREIGN KEY([Product])
REFERENCES [dbo].[Products] ([Product])
GO

ALTER TABLE [dbo].[ProductEcommerceWebsites] CHECK CONSTRAINT [FK_ProductEcommerceWebsites_Products]
GO
