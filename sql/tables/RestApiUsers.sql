SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 29 September 2017
-- Description:	Table for storing RestApiUsers for the WinMan REST API.
-- =============================================

CREATE TABLE [dbo].[RestApiUsers](
	[RestApiUser] [bigint] IDENTITY(1,1) NOT NULL,
	[RestApiUserId] [nvarchar](32) NOT NULL,
	[Name] [nvarchar](20) NOT NULL,
	[Password] [nvarchar](60) NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedUser] [nvarchar](20) NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
	[LastModifiedUser] [nvarchar](20) NOT NULL,
	[LastModifiedDate] [datetime] NOT NULL,
	[Comments] [nvarchar](500) NOT NULL,
 CONSTRAINT [PK_RestApiUsers] PRIMARY KEY CLUSTERED 
(
	[RestApiUser] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[RestApiUsers] ADD  CONSTRAINT [DF_RestApiUsers_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
