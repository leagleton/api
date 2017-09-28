SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lynn Eagleton
-- Create date: 15 September 2017
-- Description:	Table for storing RestApiClients linked to RestApiUsers for the WinMan REST API.
-- =============================================

CREATE TABLE [dbo].[RestApiUserClients](
	[RestApiUserClient] [bigint] IDENTITY(1,1) NOT NULL,
	[RestApiUser] [bigint] NOT NULL,
	[RestApiClient] [bigint] NOT NULL,
	[Scopes] [nvarchar](1000) NOT NULL,
 CONSTRAINT [PK_RestApiUserClients] PRIMARY KEY CLUSTERED 
(
	[RestApiUserClient] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[RestApiUserClients]  WITH CHECK ADD  CONSTRAINT [FK_RestApiUserClients_RestApiClients] FOREIGN KEY([RestApiClient])
REFERENCES [dbo].[RestApiClients] ([RestApiClient])
GO

ALTER TABLE [dbo].[RestApiUserClients] CHECK CONSTRAINT [FK_RestApiUserClients_RestApiClients]
GO

ALTER TABLE [dbo].[RestApiUserClients]  WITH CHECK ADD  CONSTRAINT [FK_RestApiUserClients_RestApiUsers] FOREIGN KEY([RestApiUser])
REFERENCES [dbo].[RestApiUsers] ([RestApiUser])
GO

ALTER TABLE [dbo].[RestApiUserClients] CHECK CONSTRAINT [FK_RestApiUserClients_RestApiUsers]
GO
