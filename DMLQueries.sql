-- 3.1 Създайте заявка, която да извлича списък с топ 5 на заеманите автори
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


-- 3.2 Създайте заявка, която да показва информация за топ 3 на клоновете заели най-много книги със съответния брой заети книги
SELECT TOP 3
    lb.librarybranch_id,
    lb.librarybranch_name,
    COUNT(*) AS books_borrowed
FROM
    librarybranch lb
JOIN borrowedbook bb ON lb.librarybranch_id = bb.librarian_id
GROUP BY
    lb.librarybranch_id, lb.librarybranch_name
ORDER BY
    books_borrowed DESC
GO


-- 3.3 Създайте view обект с име BooksInventory, който да съдържа информация за моментното състояние на наличностите на всяка книга, като наличните колони във вюто трябва да са заглавие на книгата и сумарното налично количество от съответната книга, сортирани по азбучен ред.
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


-- 3.4 Създайте обект view с име OverdueBooks, което да съдържа информация за списък със заематели и заетите от тях книги, които са в просрочие на срока за връщане, както и броят дни в просрочие. Сортирайте по брой просрочени дни в низходящ ред.
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



-- 3.5 Създайте view обект, който да съдържа информация за заемателите, които имат неплатени глоби, заедно със сумата за плащане и индикатор дали глобата е в просрочие.
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


-- 3.6 Увеличете броя на копията на книгите, чийто заглавия започват с “B” с 10, но само в главния клон на библиотеката.
UPDATE inventar
	SET inventar_quantity = inventar_quantity + 10
WHERE book_id IN (SELECT book_id FROM book WHERE UPPER(book_title) LIKE 'B%')
      AND librarybranch_id = (SELECT librarybranch_id FROM librarybranch WHERE librarybranch_name = 'Main Branch') -- <- Кой е главния клон на библиотеката???
GO


-- 3.7 Изпълнете delete statement, който да изтрие записите на членовете на библиотеката, които никога не са заемали книги.
DELETE FROM member
WHERE member_id NOT IN (SELECT DISTINCT member_id FROM borrowedbook)
GO


-- 3.8 Създайте procedure за заемане на книги, която да приема като параметри member_id, copy_id, librarian_id, due_date и да обновява автоматично данните в свързаните с отдаването на книги таблици. Трябва да има проверка дали даденото копие е налично и да извежда съобщение „Book borrowed successfully“ или „Book is not available for borrowing“ съответно ако е налично или не.
CREATE OR ALTER PROCEDURE borrow_book 
    @p_member_id INT,
    @p_copy_id INT,
    @p_librarian_id INT,
    @p_due_date DATE
AS
BEGIN
    -- Check if the book is available
    IF EXISTS (SELECT 1 FROM inventar WHERE inventar_id = @p_copy_id AND inventar_quantity > 0)
    BEGIN
        -- Borrow the book
        INSERT INTO borrowedbook (borrowedbook_startdate, borrowedbook_enddate, borrowedbook_isreturned, librarian_id, member_id)
        VALUES (GETDATE(), @p_due_date, 'N', @p_librarian_id, @p_member_id);

        -- Mark the copy as borrowed
        UPDATE inventar
        SET inventar_quantity = inventar_quantity - 1
        WHERE inventar_id = @p_copy_id;

        PRINT 'Book borrowed successfully.';
    END
    ELSE
    BEGIN
        PRINT 'Book is not available for borrowing.';
    END
END;
GO


-- 3.9 Създайте procedure за връщане на книги, която да приема като параметри borrow_id и return_date. Да проверява дали книгата е върната в срок и ако не, да налага глоба от 5 лева на ден за всеки просрочен ден. Да обновява автоматично информацията в свързаните с процедурата таблици. Ако е създадена глоба, да слага автоматично статус Unpaid и срок на глобата 1 месец от датата на втъщане. Ако няма наложена глоба да изписва съобщение „Book returned on time. No fine imposed.“ , а ако пък е наложена такава то да изписва съобщение „Book returned late. Fine of {fine amount} imposed.“
CREATE OR ALTER PROCEDURE return_book 
    @p_borrow_id INT,
    @p_return_date DATE
AS
BEGIN
    DECLARE @v_fine_amount INT;

    -- Check for overdue and calculate fine
    SELECT @v_fine_amount = 
        CASE
            WHEN @p_return_date > borrowedbook_enddate THEN
                5 * DATEDIFF(DAY, borrowedbook_enddate, @p_return_date)
            ELSE
                0
        END
    FROM borrowedbook
    WHERE borrowedbook_id = @p_borrow_id;

    -- Update information about book return
    UPDATE borrowedbook
    SET borrowedbook_enddate = @p_return_date,
        borrowedbook_isreturned = 'Y'
    WHERE borrowedbook_id = @p_borrow_id;

    -- If there is a fine, create a record in the fines table
    IF @v_fine_amount > 0
    BEGIN
        INSERT INTO finerecourd (fine_amount, fine_reason, fine_status, fine_dateofpaid, member_id)
        VALUES (@v_fine_amount, 'Late return', 'Unpaid', DATEADD(MONTH, 1, @p_return_date), (SELECT member_id FROM borrowedbook WHERE borrowedbook_id = @p_borrow_id));

        PRINT 'Book returned late. Fine of ' + CAST(@v_fine_amount AS VARCHAR(10)) + ' imposed.';
    END
    ELSE
    BEGIN
        PRINT 'Book returned on time. No fine imposed.';
    END
END;
GO


