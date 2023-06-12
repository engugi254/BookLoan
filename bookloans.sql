CREATE TABLE Books (
  BookID INT PRIMARY KEY,
  Title VARCHAR(255),
  Author VARCHAR(255),
  PublicationYear INT,
  Status VARCHAR(255)
);

CREATE TABLE Members (
  MemberID INT PRIMARY KEY,
  Name VARCHAR(255),
  Address VARCHAR(255),
  ContactNumber VARCHAR(255)
);

CREATE TABLE Loans (
  LoanID INT PRIMARY KEY,
  BookID INT,
  MemberID INT,
  LoanDate DATE,
  ReturnDate DATE
);
INSERT INTO Books (BookID, Title, Author, PublicationYear, Status)
VALUES (1, 'The Great Gatsby', 'F. Scott Fitzgerald', 1925, 'Available'),
       (2, 'To Kill a Mockingbird', 'Harper Lee', 1960, 'Checked Out'),
       (3, 'Pride and Prejudice', 'Jane Austen', 1813, 'Available');

INSERT INTO Members (MemberID, Name, Address, ContactNumber)
VALUES (1, 'John Smith', '123 Main St.', '555-1234'),
       (2, 'Jane Doe', '456 Elm St.', '555-5678'),
       (3, 'Bob Johnson', '789 Oak St.', '555-9012');

CREATE TRIGGER update_book_status
ON Loans
AFTER INSERT
AS
BEGIN
  IF (SELECT ReturnDate FROM inserted) IS NULL
    UPDATE Books SET Status = 'Loaned' WHERE BookID = (SELECT BookID FROM inserted);
  ELSE
    UPDATE Books SET Status = 'Available' WHERE BookID = (SELECT BookID FROM inserted);
END;

WITH BorrowedBooks AS (
  SELECT MemberID, COUNT(*) AS NumBorrowed
  FROM Loans
  GROUP BY MemberID
  HAVING COUNT(*) >= 3
)
SELECT Members.Name
FROM Members
JOIN BorrowedBooks ON Members.MemberID = BorrowedBooks.MemberID;

CREATE FUNCTION CalculateOverdueDays (@LoanID INT)
RETURNS INT
AS
BEGIN
  DECLARE @DueDate DATE;
  DECLARE @ReturnDate DATE;
  DECLARE @OverdueDays INT;

  SELECT @DueDate = DueDate, @ReturnDate = ReturnDate
  FROM Loans
  WHERE LoanID = @LoanID;

  IF @ReturnDate IS NULL
    SET @OverdueDays = DATEDIFF(DAY, @DueDate, GETDATE());
  ELSE IF @ReturnDate > @DueDate
    SET @OverdueDays = DATEDIFF(DAY, @DueDate, @ReturnDate);
  ELSE
    SET @OverdueDays = 0;

  RETURN @OverdueDays;
END;

CREATE VIEW OverdueLoans AS
SELECT Books.Title AS BookTitle, Members.Name AS MemberName,
  DATEDIFF(DAY, Loans.DueDate, GETDATE()) AS OverdueDays
FROM Loans
JOIN Members ON Loans.MemberID = Members.MemberID
JOIN Books ON Loans.BookID = Books.BookID
WHERE Loans.ReturnDate IS NULL AND Loans.DueDate < GETDATE();

CREATE TRIGGER PreventBorrowingMoreThanThreeBooks
ON Loans
FOR INSERT, UPDATE
AS
BEGIN
  DECLARE @MemberID INT;
  SELECT @MemberID = MemberID FROM inserted;
  IF (SELECT COUNT(*) FROM Loans WHERE MemberID = @MemberID AND ReturnDate IS NULL) > 3
  BEGIN
    RAISERROR ('Cannot borrow more than three books at a time.', 16, 1);
    ROLLBACK TRANSACTION;
  END;
END;
