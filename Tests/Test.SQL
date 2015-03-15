CREATE TABLE OrdersToNames (OrderID INT PRIMARY KEY, fullname TEXT);
INSERT INTO OrdersToNames (OrderID, fullname) VALUES (1,'Cookie Monster');
INSERT INTO OrdersToNames (OrderID, fullname) VALUES (500,'Cookie Monster');
SELECT * FROM NAMES INNER JOIN OrdersToNames ON NAMES.fullname = OrdersToNames.fullname;