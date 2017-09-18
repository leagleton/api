
CREATE NONCLUSTERED INDEX [IX_REST_Inventory]
ON [dbo].[Inventory] ([Product])
INCLUDE ([Site])
GO

