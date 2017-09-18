
CREATE NONCLUSTERED INDEX [IX_RestApiInventory]
ON [dbo].[Inventory] ([Product])
INCLUDE ([Site])
GO

