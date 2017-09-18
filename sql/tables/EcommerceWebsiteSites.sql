SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Table for storing Sites linked to EcommerceWebsites for the WinMan REST API.
-- =============================================

CREATE TABLE [dbo].[EcommerceWebsiteSites](
	[EcommerceWebsiteSite] [bigint] IDENTITY(1,1) NOT NULL,
	[EcommerceWebsite] [bigint] NOT NULL,
	[Site] [bigint] NOT NULL,
	[Default] [bit] NOT NULL,
	[CreatedUser] [nvarchar](20) NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
	[LastModifiedUser] [nvarchar](20) NOT NULL,
	[LastModifiedDate] [datetime] NOT NULL,
 CONSTRAINT [PK_EcommerceWebsiteSites] PRIMARY KEY CLUSTERED 
(
	[EcommerceWebsiteSite] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[EcommerceWebsiteSites] ADD  CONSTRAINT [DF_EcommerceWebsiteSites_Default]  DEFAULT ((0)) FOR [Default]
GO

ALTER TABLE [dbo].[EcommerceWebsiteSites]  WITH CHECK ADD  CONSTRAINT [FK_EcommerceWebsiteSites_EcommerceWebsites] FOREIGN KEY([EcommerceWebsite])
REFERENCES [dbo].[EcommerceWebsites] ([EcommerceWebsite])
GO

ALTER TABLE [dbo].[EcommerceWebsiteSites] CHECK CONSTRAINT [FK_EcommerceWebsiteSites_EcommerceWebsites]
GO

ALTER TABLE [dbo].[EcommerceWebsiteSites]  WITH CHECK ADD  CONSTRAINT [FK_EcommerceWebsiteSites_Sites] FOREIGN KEY([Site])
REFERENCES [dbo].[Sites] ([Site])
GO

ALTER TABLE [dbo].[EcommerceWebsiteSites] CHECK CONSTRAINT [FK_EcommerceWebsiteSites_Sites]
GO
