SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 29 September 2017
-- Description:	Table for storing RestApiUsers linked to RestApiScopes for the WinMan REST API.
-- =============================================

CREATE TABLE [dbo].[RestApiUsersScopes](
	[RestApiUserScope] [bigint] IDENTITY(1,1) NOT NULL,
	[RestApiUser] [bigint] NOT NULL,
	[RestApiScope] [bigint] NOT NULL,
	[CreatedUser] [nvarchar](20) NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
	[LastModifiedUser] [nvarchar](20) NOT NULL,
	[LastModifiedDate] [datetime] NOT NULL,
 CONSTRAINT [PK_RestApiUsersScopes] PRIMARY KEY CLUSTERED 
(
	[RestApiUserScope] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[RestApiUsersScopes]  WITH CHECK ADD  CONSTRAINT [FK_RestApiUsersScopes_RestApiScopes] FOREIGN KEY([RestApiScope])
REFERENCES [dbo].[RestApiScopes] ([RestApiScope])
GO

ALTER TABLE [dbo].[RestApiUsersScopes] CHECK CONSTRAINT [FK_RestApiUsersScopes_RestApiScopes]
GO

ALTER TABLE [dbo].[RestApiUsersScopes]  WITH CHECK ADD  CONSTRAINT [FK_RestApiUsersScopes_RestApiUsers] FOREIGN KEY([RestApiUser])
REFERENCES [dbo].[RestApiUsers] ([RestApiUser])
GO

ALTER TABLE [dbo].[RestApiUsersScopes] CHECK CONSTRAINT [FK_RestApiUsersScopes_RestApiUsers]
GO
