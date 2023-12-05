-- 3.1 �������� ������, ����� �� ������� ������ � ��� 5 �� ��������� ������
SELECT TOP 5
    author_id,
    author_name,
    COUNT(*) AS books_borrowed
FROM (
    SELECT
        a.author_id,
        CONCAT(a.author_firstname, ' ', a.author_lastname) AS author_name,
        b.book_id
    FROM
        author a
    JOIN book b ON a.author_id = b.author_id
    JOIN borrowedbook bb ON b.book_id = bb.borrowedbook_id
) AS subquery
GROUP BY
    author_id, author_name
ORDER BY
    books_borrowed DESC
GO


-- 3.2 �������� ������, ����� �� ������� ���������� �� ��� 3 �� ��������� ����� ���-����� ����� ��� ���������� ���� ����� �����
SELECT TOP 3
    lb.librarybranch_id,
    lb.librarybranch_name,
    COUNT(*) AS books_borrowed
FROM
    librarybranch lb
JOIN borrowedbook bb ON lb.librarybranch_id = bb.librarybranch_id -- <- ������ �� �� ������ ����
GROUP BY
    lb.librarybranch_id, lb.librarybranch_name
ORDER BY
    books_borrowed DESC
GO


-- 3.3 �������� view ����� � ��� BooksInventory, ����� �� ������� ���������� �� ���������� ��������� �� ������������ �� ����� �����, ���� ��������� ������ ��� ���� ������ �� �� �������� �� ������� � ��������� ������� ���������� �� ����������� �����, ��������� �� ������� ���.
CREATE VIEW BooksInventory AS
SELECT
    b.book_title,
    SUM(i.inventar_quantity) AS total_quantity
FROM
    book b
JOIN inventar i ON b.book_id = i.book_id
GROUP BY
    b.book_title
GO


-- 3.4 �������� ����� view � ��� OverdueBooks, ����� �� ������� ���������� �� ������ ��� ��������� � ������� �� ��� �����, ����� �� � ��������� �� ����� �� �������, ����� � ����� ��� � ���������. ���������� �� ���� ���������� ��� � �������� ���.
CREATE VIEW OverdueBooks AS
SELECT
    m.member_id,
    CONCAT(m.member_firstname, ' ', m.member_lastname) AS member_name,
    b.book_title,
    DATEDIFF(DAY, bb.borrowedbook_startdate, bb.borrowedbook_enddate) AS overdue_days
FROM
    member m
JOIN borrowedbook bb ON m.member_id = bb.member_id
JOIN inventar i ON bb.borrowedbook_id = i.borrowedbook_id
JOIN book b ON i.book_id = b.book_id
WHERE
    bb.borrowedbook_enddate < GETDATE();
GO



-- 3.5 �������� view �����, ����� �� ������� ���������� �� �����������, ����� ���� ��������� �����, ������ ��� ������ �� ������� � ��������� ���� ������� � � ���������.
CREATE VIEW UnpaidFines AS
SELECT
    m.member_id,
    CONCAT(m.member_firstname, ' ', m.member_lastname) AS member_name,
    fr.fine_amount,
    fr.fine_status,
    CASE
        WHEN fr.fine_dateofpaid IS NULL AND fr.fine_dateofpaid < GETDATE() THEN 'Yes'
        ELSE 'No'
    END AS overdue
FROM
    member m
JOIN finerecord fr ON m.member_id = fr.member_id
WHERE
    fr.fine_status = 'Unpaid'
GO


-- 3.6 ��������� ���� �� ������� �� �������, ����� �������� �������� � �B� � 10, �� ���� � ������� ���� �� ������������.
UPDATE inventar
	SET inventar_quantity = inventar_quantity + 10
WHERE book_id IN (SELECT book_id FROM book WHERE UPPER(book_title) LIKE 'B%')
      AND librarybranch_id = (SELECT librarybranch_id FROM librarybranch WHERE librarybranch_name = 'Main Branch') -- <- ��� � ������� ���� �� ������������???
GO


-- 3.7 ��������� delete statement, ����� �� ������ �������� �� ��������� �� ������������, ����� ������ �� �� ������� �����.
DELETE FROM member
WHERE member_id NOT IN (SELECT DISTINCT member_id FROM borrowedbook)
GO -- < �������� ���� �������