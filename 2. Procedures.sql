--Procedures

--Procedure/ the list of customers with extended payment due date
DROP PROCEDURE IF EXISTS WhoHas21daysForPayments
GO
CREATE PROCEDURE dbo.WhoHas21daysForPaymentsNow
		(  
		@DateBegin datetime,  
		@DateEnd   datetime  
		)  
		AS  
		BEGIN  
		SELECT DISTINCT a.CustomerID FROM Task.Customer a INNER JOIN Task.SalesOrderHeader b
		ON a.CustomerID=b.CustomerID WHERE b.OrderDate>= @DateBegin AND b.OrderDate <= @DateEnd  
		AND dbo.Calculate14or21PreviousQuarter(b.CustomerID, b.OrderDate) >14		
		END

GO
--EXEC dbo.WhoHas21daysForPaymentsNow '20140401','20140630' --testing
--GO

--Procedure/ list of customers entitled next quarter to extended payment due date
DROP PROCEDURE IF EXISTS dbo.WhoHas21daysForPaymentsNextQuarter
GO
CREATE PROCEDURE dbo.WhoHas21daysForPaymentsNextQuarter
		(  
		@DateBegin datetime,  
		@CurrentDate   datetime  
		)  
		AS  
		BEGIN  
		select distinct a.CustomerID from Task.SalesOrderHeader a where a.OrderDate >= @DateBegin AND a.OrderDate<= @CurrentDate
		AND a.DueDate14or21 =21
		END
GO

--EXEC dbo.WhoHas21daysForPaymentsNextQuarter '20140401','20140630' 
--GO
--list of customers /21 days for payment
--testing procedure
select * from Task.SalesOrderHeader where Task.SalesOrderHeader.CustomerID= '17218'; 
select distinct a.CustomerID from Task.SalesOrderHeader a where a.OrderDate >= '20140401' and a.DueDate14or21 =21
select distinct a.CustomerID from Task.SalesOrderHeader a where a.OrderDate >= '20140401' and a.DueDate14or21 =14 



--Procedure /list of customers with overdue payments/from... to...
DROP PROCEDURE IF EXISTS dbo.CustomersWithOverDuePayments
GO
CREATE PROCEDURE dbo.CustomersWithOverDuePayments
		(  
		@DateBegin datetime,  
		@DateEnd   datetime  
		)  
		AS  
		BEGIN  
		SELECT DISTINCT a.CustomerID, a.SalesOrderID, DATEDIFF(day,a.DueDateNational, a.DatePaid) AS NumberOfOverdueDays		
		FROM Task.SalesOrderHeader a
		WHERE DATEDIFF(day,a.DueDateNational, a.DatePaid) >0 AND a.OrderDate >=@DateBegin AND a.OrderDate <= @DateEnd
END
GO

--EXEC dbo.CustomersWithOverDuePayments '20140301','20140615' --testing
--GO


--Procedure/ list of customers, occurrence of overdue payments, total orders value, the most bought products per customer 
--Receivables index calculated for the period of time
--((Customer's orders value* number of days between payment due date and payment date)/Customer's orders value)
DROP PROCEDURE IF EXISTS dbo.StatisticsOfCustomers
GO
CREATE PROCEDURE dbo.StatisticsOfCustomers
		(  
		@DateBegin datetime,  
		@DateEnd   datetime  
		)  
		AS  
		BEGIN  
		DROP TABLE IF EXISTS dbo.#temp1
		CREATE TABLE #temp1
		(id int IDENTITY(1,1),
		customerID int,
		SalesOrderID int,
		ReceivableIndex money);
		
		INSERT INTO #temp1(customerID,SalesOrderID,ReceivableIndex )
		SELECT a.CustomerID, a.SalesOrderID,DATEDIFF(DAY,a.DatePaid,a.DueDateNational)*a.TotalDue
				FROM Task.SalesOrderHeader a  			
				WHERE a.OrderDate >= @DateBegin AND a.OrderDate <= @DateEnd AND a.DueDateNational <=@DateEnd

		
		(SELECT a.CustomerID AS CustomerID, 
				SUM(a.TotalDue) AS OrdersValue, 
				COUNT(a.SalesOrderID) AS NumberOfOrders,
				(SUM(#temp1.ReceivableIndex )/SUM(a.TotalDue)) AS ReceivableIndex ,
				null AS ProductID, 
				null AS ProductName,
				null AS OrderQty
				FROM Task.SalesOrderHeader a  
				INNER JOIN #temp1
				ON a.CustomerID=#temp1.customerID
				WHERE a.OrderDate >= @DateBegin AND a.OrderDate <= @DateEnd AND a.DueDateNational <=@DateEnd
				GROUP BY a.CustomerID)
		UNION 
		(SELECT h.CustomerID AS CustomerID, 
				null,
				null,
				null,
				p.ProductID AS ProductID,
				p.Name AS ProductName, 
				SUM(d.OrderQty) OVER(PARTITION BY  d.ProductID, CustomerID) AS OrderQty
				FROM 
				Task.SalesOrderHeader h INNER JOIN Task.SalesOrderDetail d ON h.SalesOrderID=d.SalesOrderID
				INNER JOIN Task.Product p ON d.ProductID = p.ProductID
				WHERE h.OrderDate >= @DateBegin AND h.OrderDate <= @DateEnd AND h.DueDateNational <=@DateEnd
				--AND CustomerID=29543
				)				
				ORDER BY CustomerID,NumberOfOrders DESC,  OrderQty DESC ;

		DROP TABLE #temp1
END
GO

--EXEC dbo.StatisticsOfCustomers '20110301','20140615' --testing procedure


--Procedure / list of products, average quantity and value of product ordered, which customer ordered the most (value, number of orders) 

DROP PROCEDURE IF EXISTS dbo.StatisticsOfProducts
GO
CREATE PROCEDURE dbo.StatisticsOfProducts
		(  
		@DateBegin datetime,  
		@DateEnd   datetime  
		)  
		AS  
		BEGIN  
		DROP TABLE IF EXISTS dbo.#temp2
		CREATE TABLE #temp2
		(id int IDENTITY(1,1),
		NumberOfProductOrders int,
		NumberOfProductsOrdered int,
		ValueOfOrderedProducts money,
		ProductID int
		)

		DROP TABLE IF EXISTS dbo.#t2
	
		INSERT INTO #temp2(NumberOfProductOrders,NumberOfProductsOrdered,ValueOfOrderedProducts,ProductID)
		SELECT	COUNT(a.SalesOrderDetailID) AS NumberOfProductOrders,
				SUM(a.OrderQty) AS NumberOfProductsOrdered,
				SUM(a.LineTotal) ValueOfOrderedProducts,
				a.ProductID
				FROM Task.SalesOrderDetail a
				INNER JOIN Task.SalesOrderHeader b
				ON a.SalesOrderID=b.SalesOrderID
				WHERE b.OrderDate >= @DateBegin AND b.OrderDate <= @DateEnd 
				GROUP BY a.ProductID ORDER BY a.ProductID

		SELECT 
				p.ProductID,
				p.Name AS ProductName,
				t.NumberOfProductsOrdered/t.NumberOfProductOrders AS [AverageNumberOfOrders for Product],
				t.ValueOfOrderedProducts/t.NumberOfProductOrders AS [AverageOrderValue for Product],
				null AS CustomerID,
				null AS [OrderQty(per order)],
				null AS [OrderQty(number of OrderQty)]
				 				
				FROM Task.Product p INNER JOIN Task.SalesOrderDetail d
				ON p.ProductID=d.ProductID
				INNER JOIN Task.SalesOrderHeader h
				ON d.SalesOrderID=h.SalesOrderID
				INNER JOIN #temp2 t
				ON d.ProductID=t.ProductID				
				WHERE h.OrderDate >= @DateBegin AND h.OrderDate <= @DateEnd 
		UNION
		 	
			(SELECT d.ProductID, 
				null,
				null,
				null,
				h.CustomerID,
				SUM(d.OrderQty) OVER(PARTITION BY  d.ProductID, CustomerID) AS [OrderQty(per order)],
				Count(d.SalesOrderDetailID) OVER(PARTITION BY  d.ProductID, CustomerID) AS [OrderQty(number of OrderQty)]

				FROM 
				Task.SalesOrderHeader h INNER JOIN Task.SalesOrderDetail d ON h.SalesOrderID=d.SalesOrderID
				INNER JOIN Task.Product p ON d.ProductID = p.ProductID
				WHERE h.OrderDate >= @DateBegin AND h.OrderDate <= @DateEnd 
				--AND CustomerID=29543
				)	
				ORDER BY ProductID, ProductName DESC, [OrderQty(per order)] DESC, CustomerID 

		
END
GO

--EXEC dbo.StatisticsOfProducts '20140301','20140630' --procedure test

