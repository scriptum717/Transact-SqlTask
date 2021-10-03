USE AdventureWorks2017;
--please download database AdventureWorks2017
--https://docs.microsoft.com/en-us/sql/samples/adventureworks-install-configure?view=sql-server-ver15&tabs=ssms

--SELECT SUSER_SNAME(sid), * from sys.database_principals
--ALTER AUTHORIZATION ON DATABASE::[AdventureWorks2017] TO [sa]
---------------------------------------------------------------
--DDL 
DROP TABLE IF EXISTS Task.DueDate;
GO
DROP TABLE IF EXISTS Task.Payments;
GO
DROP TABLE IF EXISTS Task.SalesOrderDetail;
GO
DROP TABLE IF EXISTS Task.SalesOrderHeader;
GO
DROP TABLE IF EXISTS Task.Product;
GO
DROP TABLE IF EXISTS Task.Customer;
GO
DROP TABLE IF EXISTS Task.SalesTerritory;
GO
DROP TABLE IF EXISTS Task.Holidays;
GO
DROP SCHEMA IF EXISTS Task;
GO
--create schema Task and DDL tables in schema Task
CREATE SCHEMA Task;  
GO

--create table Task.Holidays and feeding with sample data
	DROP TABLE IF EXISTS Task.Holidays
	CREATE TABLE Task.Holidays
	(
		HolidaysID int Identity (1,1),
		HolidayDate date unique
	);

	Insert into Task.Holidays (HolidayDate) Values ('20130503');
	Insert into Task.Holidays (HolidayDate) Values ('20110614');
	Insert into Task.Holidays (HolidayDate) Values ('20110615');
	Insert into Task.Holidays (HolidayDate) Values ('20110624');
	GO
--create table Task.Product and feeding with sample data
	DROP TABLE IF EXISTS Task.Product
	CREATE TABLE Task.Product
	(
		ProductID int not null identity (1,1),
		Name  nvarchar(50) not null,
		ModifiedDate datetime NOT NULL DEFAULT GETDATE() 
	);
	GO
	SET IDENTITY_INSERT Task.Product ON;
	INSERT INTO Task.Product (ProductID, Name, ModifiedDate)
		SELECT a.ProductID, a.Name, a.ModifiedDate
		FROM Production.Product  a
	SET IDENTITY_INSERT Task.Product OFF;
	GO

--create table Task.SalesTerritory and feeding with sample data
	DROP TABLE IF EXISTS Task.SalesTerritory
	GO
	CREATE TABLE Task.SalesTerritory
	(
		TerritoryID int not null identity (1,1),
		Name  nvarchar(50) not null,
		CountryRegionCode nvarchar(3) not null,
		ModifiedDate datetime not null DEFAULT GETDATE() 
	);
	GO
	SET IDENTITY_INSERT Task.SalesTerritory ON;
	INSERT INTO Task.SalesTerritory(TerritoryID, Name, CountryRegionCode, ModifiedDate)
		SELECT a.TerritoryID, a.Name, a.CountryRegionCode, a.ModifiedDate 
		FROM Sales.SalesTerritory  a
	SET IDENTITY_INSERT Task.SalesTerritory OFF;
	GO

--create table Task.Customer and feeding with sample data
	DROP TABLE IF EXISTS Task.Customer
	CREATE TABLE Task.Customer
	(
		CustomerID int not null identity (1,1),
		TerritoryID int,
		ModifiedDate datetime not null DEFAULT GETDATE() 
	);
	GO
	SET IDENTITY_INSERT Task.Customer ON;
	INSERT INTO Task.Customer (CustomerID, TerritoryID, ModifiedDate)
		SELECT a.CustomerID, a.TerritoryID, a.ModifiedDate 
		FROM Sales.Customer  a
	SET IDENTITY_INSERT Task.Customer OFF;
	GO
--create table Task.SalesOrderHeader and feeding with sample data
	DROP TABLE IF EXISTS Task.SalesOrderHeader
	CREATE TABLE Task.SalesOrderHeader
	(
		SalesOrderID int not null identity (1,1),
		CustomerID int not null,
		TerritoryID int null,
		TotalDue money not null,
		OrderDate datetime NOT NULL DEFAULT GETDATE(), 
		DueDate14or21 tinyint null,-- DEFAULT 14,     
		DueDateNational datetime null,	 
		DatePaid datetime null	
		--ModifiedDate datetime not null DEFAULT GETDATE() 
	);
	GO
	SET IDENTITY_INSERT Task.SalesOrderHeader ON;
	INSERT INTO Task.SalesOrderHeader (SalesOrderID, CustomerID, TerritoryID, TotalDue, OrderDate,
	DueDate14or21, DueDateNational,DatePaid)
		SELECT a.SalesOrderID, a.CustomerID, a.TerritoryID, a.TotalDue, a.OrderDate, null, null,
		DATEADD(DAY,ABS(CHECKSUM(NEWID())) % ( 1 + DATEDIFF(DAY,a.DueDate-9,a.DueDate+9)),a.DueDate-9)
		FROM Sales.SalesOrderHeader  a
	SET IDENTITY_INSERT Task.SalesOrderHeader OFF;
	GO

--create table Task.SalesOrderDetail and feeding with sample data
	DROP TABLE IF EXISTS Task.SalesOrderDetail
	CREATE TABLE Task.SalesOrderDetail
	(
		SalesOrderDetailID int not null identity (1,1),
		SalesOrderID int not null,
		ProductID int not null,
		OrderQty smallint not null,
		UnitPrice money,
		LineTotal money		
		--UnitPrice money not null
	);
	GO
	SET IDENTITY_INSERT Task.SalesOrderDetail ON;
	INSERT INTO Task.SalesOrderDetail (SalesOrderDetailID, SalesOrderID, ProductID , OrderQty,UnitPrice,LineTotal)
		SELECT a.SalesOrderDetailID, a.SalesOrderID, a.ProductID, a.OrderQty, a.UnitPrice, a.LineTotal
		FROM Sales.SalesOrderDetail  a
	SET IDENTITY_INSERT Task.SalesOrderDetail OFF;
	GO

	--select * from Task.SalesOrderDetail
-----------------------------------------------------	
-- create function to correct payment due date if payment due date is on Saturday, Sunday or national holiday
	DROP FUNCTION IF EXISTS ShowRealDueDate 
	GO
	Create FUNCTION ShowRealDueDate  
	(@DueDate14or21 int, 
	 @OrderDate  datetime)
	RETURNS datetime  
	AS  
	BEGIN         
		DECLARE @RoznicaDni int
		SET @RoznicaDni = DATEDIFF(day,@OrderDate,
						CASE Datepart(weekday, @OrderDate + @DueDate14or21)
						WHEN 7 THEN DATEADD(day, @DueDate14or21 +2, @OrderDate)
						WHEN 1 THEN DATEADD(day, @DueDate14or21 +1, @OrderDate)
						ELSE DATEADD(day, @DueDate14or21, @OrderDate)
						END);
   		DECLARE @Result datetime
		SET @Result = DATEADD (day, @RoznicaDni, @OrderDate);
	    IF @Result = (SELECT Task.Holidays.HolidayDate FROM Task.Holidays where Task.Holidays.HolidayDate=@Result)  
			BEGIN
			SET @Result= DATEADD (day, 1, @Result);
			SET @Result= dbo.ShowRealDueDate (0,@Result);
			END		
		RETURN @Result;	
	END;
GO
-- create function to determine payment due date 14 or 21
	DROP FUNCTION IF EXISTS Calculate14or21PreviousQuarter 
	GO
	Create FUNCTION Calculate14or21PreviousQuarter   
	(@CustomerID int, 
	 @OrderDate  datetime)
	RETURNS int  
	AS  
	BEGIN         
		DECLARE @PreviousQuarterBegin datetime;		
		DECLARE @PreviousQuarterEnd datetime;
		SET @PreviousQuarterEnd = 
					EOMONTH(										
					CASE Datepart(month, @OrderDate)
					WHEN 12 THEN DATEADD(MONTH, -3, @OrderDate)
					WHEN 11 THEN DATEADD(MONTH, -2, @OrderDate)
					WHEN 10 THEN DATEADD(MONTH, -1, @OrderDate)
					WHEN 9  THEN DATEADD(MONTH, -3, @OrderDate)
					WHEN 8  THEN DATEADD(MONTH, -2, @OrderDate)
					WHEN 7  THEN DATEADD(MONTH, -1, @OrderDate)
					WHEN 6  THEN DATEADD(MONTH, -3, @OrderDate)
					WHEN 5  THEN DATEADD(MONTH, -2, @OrderDate)
					WHEN 4  THEN DATEADD(MONTH, -1, @OrderDate)
					WHEN 3  THEN DATEADD(MONTH, -3, @OrderDate)
					WHEN 2  THEN DATEADD(MONTH, -2, @OrderDate)
					WHEN 1  THEN DATEADD(MONTH, -1, @OrderDate)
					ELSE @OrderDate					
					END	
					);
	
		SET @PreviousQuarterBegin = 
					DATEADD(day,1,
					EOMONTH(
					CASE Datepart(month, @OrderDate)
					WHEN 12 THEN DATEADD(MONTH, -6, @OrderDate)
					WHEN 11 THEN DATEADD(MONTH, -5, @OrderDate)
					WHEN 10 THEN DATEADD(MONTH, -4, @OrderDate)
					WHEN 9  THEN DATEADD(MONTH, -6, @OrderDate)
					WHEN 8  THEN DATEADD(MONTH, -5, @OrderDate)
					WHEN 7  THEN DATEADD(MONTH, -4, @OrderDate)
					WHEN 6  THEN DATEADD(MONTH, -6, @OrderDate)
					WHEN 5  THEN DATEADD(MONTH, -5, @OrderDate)
					WHEN 4  THEN DATEADD(MONTH, -4, @OrderDate)
					WHEN 3  THEN DATEADD(MONTH, -6, @OrderDate)
					WHEN 2  THEN DATEADD(MONTH, -5, @OrderDate)
					WHEN 1  THEN DATEADD(MONTH, -4, @OrderDate)
					ELSE  @OrderDate
					END							
					)
					);

		DECLARE @InterimResult int;
		SET @InterimResult = (						
				SELECT count(*) FROM Task.SalesOrderHeader a  
				WHERE (a.OrderDate >= @PreviousQuarterBegin AND a.OrderDate <= @PreviousQuarterEnd AND 
				a.CustomerID = @CustomerID AND DATEDIFF(day,a.DueDateNational,@PreviousQuarterEnd)>=0) AND
				((DATEDIFF(DAY, a.DatePaid, a.DueDateNational))>0 OR  a.DatePaid IS NULL )

				);

		DECLARE @Result int;		
		SET	@Result = CASE (@InterimResult)
							WHEN 0 THEN 14
							ELSE 21
							END
	RETURN @Result;	
	END;
GO

	
--data update - moving payment due date if it is on Saturday/Sunday/national holiday
--data update for 1 quarter /database AdventureWorks/ 
UPDATE Task.SalesOrderHeader 
	SET Task.SalesOrderHeader.DueDate14or21 = 14 WHERE Task.SalesOrderHeader.OrderDate <='20110630';
GO
UPDATE Task.SalesOrderHeader
	SET Task.SalesOrderHeader.DueDateNational =dbo.ShowRealDueDate (Task.SalesOrderHeader.DueDate14or21, 
	Task.SalesOrderHeader.OrderDate) 
	WHERE Task.SalesOrderHeader.OrderDate >='20110401' AND Task.SalesOrderHeader.OrderDate <= '20110630'
GO
UPDATE Task.SalesOrderHeader
	SET Task.SalesOrderHeader.DueDate14or21 =dbo.Calculate14or21PreviousQuarter (Task.SalesOrderHeader.CustomerID, 
	Task.SalesOrderHeader.OrderDate)
	WHERE Task.SalesOrderHeader.OrderDate >='20110701' AND Task.SalesOrderHeader.OrderDate <= '20110930'
GO
UPDATE Task.SalesOrderHeader
	SET Task.SalesOrderHeader.DueDateNational =dbo.ShowRealDueDate (Task.SalesOrderHeader.DueDate14or21, 
	Task.SalesOrderHeader.OrderDate) 
	WHERE Task.SalesOrderHeader.OrderDate >='20110701' AND Task.SalesOrderHeader.OrderDate <= '20110930'
GO
UPDATE Task.SalesOrderHeader
	SET Task.SalesOrderHeader.DueDate14or21 =dbo.Calculate14or21PreviousQuarter (Task.SalesOrderHeader.CustomerID, 
	Task.SalesOrderHeader.OrderDate)
	WHERE Task.SalesOrderHeader.OrderDate >='20111001' AND Task.SalesOrderHeader.OrderDate <= '20111231'
GO
UPDATE Task.SalesOrderHeader
	SET Task.SalesOrderHeader.DueDateNational =dbo.ShowRealDueDate (Task.SalesOrderHeader.DueDate14or21, 
	Task.SalesOrderHeader.OrderDate) 
	WHERE Task.SalesOrderHeader.OrderDate >='20111001' AND Task.SalesOrderHeader.OrderDate <= '20111231'
GO
UPDATE Task.SalesOrderHeader
	SET Task.SalesOrderHeader.DueDate14or21 =dbo.Calculate14or21PreviousQuarter (Task.SalesOrderHeader.CustomerID, 
	Task.SalesOrderHeader.OrderDate)
	WHERE Task.SalesOrderHeader.OrderDate >='20120101' AND Task.SalesOrderHeader.OrderDate <= '20120331'
GO
UPDATE Task.SalesOrderHeader
	SET Task.SalesOrderHeader.DueDateNational =dbo.ShowRealDueDate (Task.SalesOrderHeader.DueDate14or21, 
	Task.SalesOrderHeader.OrderDate) 
	WHERE Task.SalesOrderHeader.OrderDate >='20120101' AND Task.SalesOrderHeader.OrderDate <= '20120331'
GO
	
--testing / searching customers for unit tests to test functions created
	/*
	select  count(a.SalesOrderID), a.CustomerID from Task.SalesOrderHeader a where a.OrderDate < '20111231' 
	group by  a.CustomerID
	order by count(a.customerID) desc;
	*/
--update of payment date for random customer to test functions created
	UPDATE Task.SalesOrderHeader
	SET Task.SalesOrderHeader.DatePaid = CONVERT(datetime, '20111228') WHERE Task.SalesOrderHeader.SalesOrderID =45059
	GO
--testing functions 
	--select * from Task.SalesOrderHeader where Task.SalesOrderHeader.CustomerID= '29489';



--database procedure to automate calculation of payment due date 14/21 for indicated period of time
--and calculation of final payment date by correcting payment date if it is on Saturday/Sunday/holiday.

DROP PROCEDURE IF EXISTS dbo.Automation
GO
CREATE PROCEDURE [dbo].Automation  
(  
	@DateBegin datetime,  
	@DateEnd   datetime  
)  
AS  
BEGIN  
	DECLARE @i int 
	SET @i = 0
	DECLARE @DateCurrentBegin datetime
	SET @DateCurrentBegin= @DateBegin
	
	WHILE (DATEADD(MONTH,@i, @DateCurrentBegin) < @DateEnd AND DATEADD(MONTH,@i, @DateCurrentBegin) < Getdate() AND @DateEnd<=GETDATE() )
	BEGIN
		UPDATE Task.SalesOrderHeader
		SET Task.SalesOrderHeader.DueDate14or21 =dbo.Calculate14or21PreviousQuarter (Task.SalesOrderHeader.CustomerID, 
		Task.SalesOrderHeader.OrderDate)
		WHERE Task.SalesOrderHeader.OrderDate >= DATEADD(MONTH,@i, @DateCurrentBegin) AND Task.SalesOrderHeader.OrderDate <= EOMONTH(DATEADD(MONTH,2,DATEADD(MONTH,@i, @DateCurrentBegin)))
		

		UPDATE Task.SalesOrderHeader
		SET Task.SalesOrderHeader.DueDateNational =dbo.ShowRealDueDate (Task.SalesOrderHeader.DueDate14or21, 
		Task.SalesOrderHeader.OrderDate) 
		WHERE Task.SalesOrderHeader.OrderDate >= DATEADD(MONTH,@i, @DateCurrentBegin) AND Task.SalesOrderHeader.OrderDate <= EOMONTH(DATEADD(MONTH,2,DATEADD(MONTH,@i, @DateCurrentBegin)))
		
		SET @i = @i+3
	END 
END  
GO
  
EXEC   dbo.Automation '20120101','20140630'
GO


--test
/*
select * from Task.Customer
select * from Task.Holidays 
select * from Task.Product
select * from Task.SalesOrderDetail
select * from Task.SalesOrderHeader
select * from Task.SalesTerritory
*/

