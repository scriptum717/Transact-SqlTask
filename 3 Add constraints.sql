--add pk
ALTER TABLE Task.Customer
ADD CONSTRAINT  PK_CustomerID PRIMARY KEY (CustomerID)
GO
ALTER TABLE Task.SalesTerritory
ADD CONSTRAINT  PK_TerritoryID PRIMARY KEY (TerritoryID)
GO
ALTER TABLE Task.Product
ADD CONSTRAINT  PK_ProductID PRIMARY KEY (ProductID)
GO
ALTER TABLE Task.SalesOrderHeader
ADD CONSTRAINT  PK_SalesOrderID PRIMARY KEY (SalesOrderID)
GO
ALTER TABLE Task.SalesOrderDetail
ADD CONSTRAINT  PK_SalesOrderDetailID PRIMARY KEY (SalesOrderDetailID)
GO
--add fk
ALTER TABLE Task.Customer
ADD CONSTRAINT FK_TerritoryID FOREIGN KEY (TerritoryID) REFERENCES Task.SalesTerritory(TerritoryID)
GO
ALTER TABLE Task.SalesOrderHeader
ADD CONSTRAINT FK_CustomerID FOREIGN KEY (CustomerID) REFERENCES Task.Customer(CustomerID)
GO
ALTER TABLE Task.SalesOrderDetail
ADD CONSTRAINT FK_ProductID FOREIGN KEY (ProductID) REFERENCES Task.Product(ProductID)
GO
ALTER TABLE Task.SalesOrderDetail
ADD CONSTRAINT FK_SalesOrderID FOREIGN KEY (SalesOrderID) REFERENCES Task.SalesOrderHeader(SalesOrderID)
GO
/*
--drop fk
ALTER TABLE Task.SalesOrderDetail
DROP CONSTRAINT  FK_SalesOrderID 
GO
ALTER TABLE Task.SalesOrderDetail
DROP CONSTRAINT  FK_ProductID
GO
ALTER TABLE Task.SalesOrderHeader
DROP CONSTRAINT  FK_CustomerID 
GO
ALTER TABLE Task.Customer
DROP CONSTRAINT  FK_TerritoryID 
GO

--drop pk
ALTER TABLE Task.Customer
DROP CONSTRAINT  PK_CustomerID 
GO
ALTER TABLE Task.SalesTerritory
DROP CONSTRAINT  PK_TerritoryID 
GO
ALTER TABLE Task.Product
DROP CONSTRAINT  PK_ProductID
GO
ALTER TABLE Task.SalesOrderHeader
DROP CONSTRAINT  PK_SalesOrderID
GO
ALTER TABLE Task.SalesOrderDetail
DROP CONSTRAINT  PK_SalesOrderDetailID
GO
*/