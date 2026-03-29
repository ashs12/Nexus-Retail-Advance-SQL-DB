USE nexus_retail;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE shipping_logs;
TRUNCATE TABLE order_items;
TRUNCATE TABLE orders;
SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO orders (order_id, customer_id, order_date, priority) VALUES
(1, 1, '2023-01-05', 'High'), (2, 2, '2023-01-07', 'Medium'), (3, 3, '2023-01-10', 'Critical'),
(4, 4, '2023-01-12', 'Low'), (5, 5, '2023-01-15', 'High'), (6, 1, '2023-02-01', 'Medium'),
(7, 2, '2023-02-05', 'Critical'), (8, 3, '2023-02-10', 'Low'), (9, 4, '2023-02-15', 'High'),
(10, 5, '2023-02-20', 'Medium'), (11, 1, '2023-03-01', 'High'), (12, 2, '2023-03-05', 'Critical'),
(13, 3, '2023-03-10', 'Low'), (14, 4, '2023-03-15', 'High'), (15, 5, '2023-03-20', 'Medium'),
(16, 1, '2023-04-01', 'High'), (17, 2, '2023-04-05', 'Critical'), (18, 3, '2023-04-10', 'Low'),
(19, 4, '2023-04-15', 'High'), (20, 5, '2023-04-20', 'Medium');

INSERT INTO order_items (order_id, product_id, quantity, actual_sale_price) VALUES
(1, 10, 1, 299.00), (1, 11, 2, 850.00), (2, 12, 1, 120.00), (3, 13, 1, 550.00),
(4, 14, 5, 400.00), (5, 10, 2, 598.00), (6, 11, 1, 450.00), (7, 12, 3, 360.00),
(8, 13, 1, 550.00), (9, 14, 2, 170.00), (10, 10, 1, 299.00), (11, 11, 1, 450.00),
(12, 12, 2, 240.00), (13, 13, 1, 550.00), (14, 14, 10, 800.00), (15, 10, 1, 299.00),
(16, 11, 3, 1350.00), (17, 12, 1, 120.00), (18, 13, 2, 1100.00), (19, 14, 1, 85.00),
(20, 10, 1, 299.00), (2, 14, 2, 170.00), (5, 12, 1, 120.00), (7, 10, 1, 299.00);


INSERT INTO shipping_logs (order_id, ship_date, ship_mode, shipping_cost)
SELECT order_id, DATE_ADD(order_date, INTERVAL 3 DAY), 'Standard', 15.00 FROM orders;



SELECT 
    c.first_name,
    o.order_date,
    p.product_name,
    oi.actual_sale_price
FROM
    customers c
        JOIN
    orders o ON c.customer_id = o.customer_id
        JOIN
    order_items oi ON o.order_id = oi.order_id
        JOIN
    products p ON oi.product_id = p.product_id; 


-- Question: Show every order_id and its actual_sale_price, plus a column that shows the cumulative sum (running total) 
-- of sales for the entire table     Syntax Hint: SUM(price) OVER (ORDER BY order_id) --

select order_id, actual_sale_price, 

sum(actual_sale_price) over(order by order_id) as running_total from order_items;


-- Show each product's name, its category, and its price. Then, show a Running Total of prices that starts over (resets) for every new category.

select product_name, category, retail_price,

sum(retail_price) over(partition by category order by product_id) as category_running_total from products;

-- For every customer, we want to see their orders in the order they happened, and assign a "Sequence Number" (1, 2, 3...) to each one.

select customer_id, order_id, order_date,
row_number() over(partition by customer_id order by order_date) as order_sequence from orders;


-- Show product_name, category, and retail_price. Then, use RANK() to rank products 
-- from most expensive to least expensive within their category.

select product_id, category, retail_price,

rank() over(partition by category order by retail_price desc) as price_rank from products;

-- For each city in the customers table, number the customers based on their signup_date (oldest signup is #1.

select customer_id, city, signup_date, 
rank() over(partition by city order by signup_date) as signup_seq from customers;

-- We want to find the Top 2 most expensive items ever bought by each customer.

with customer_purchases as(

select o.customer_id, p.product_name, oi.actual_sale_price,

dense_rank() over (partition by o.customer_id order by oi.actual_sale_price desc ) as price_rank
from orders o join order_items oi on o.order_id = oi.order_id 
join products p on oi.product_id = p.product_id ) select * from customer_purchases where price_rank <= 2;

-- write a query that shows the single most expensive order item for each city?

 with expensive_order_city as (select o.order_id, c.city, oi.actual_sale_price,
row_number() over(partition by city order by oi.actual_sale_price desc) as most_expensive_orderitem_per_city
from order_items oi join orders o on oi.order_id = o.order_id 
join customers c on c.customer_id = o.customer_id ) select * from expensive_order_city where most_expensive_orderitem_per_city = 1;

-- For each customer, show their order_id, order_date, and actual_sale_price. Then, add a column called diff_from_previous 
-- which shows how much more or less they spent compared to their last order.

select o.customer_id, o.order_date, oi.actual_sale_price, 

oi.actual_sale_price - lag(oi.actual_sale_price) over (partition by o.customer_id order by o.order_date) as delta_sale_price
from orders o join order_items oi on o.order_id = oi.order_id;

-- how many days pass between a customer's orders.

select order_id, customer_id, order_date, 
datediff (order_date , lag(order_date) over (partition by customer_id order by order_date ) )as frequency_of_purchase
from orders;

-- Create a View called v_order_summary that joins customers, orders, and order_items so we can see the 
-- customer name and total order value in one place.

create view v_order_summary as 

select c.first_name, c.last_name, o.order_id, sum(oi.actual_sale_price) as total_value

from customers c join orders o on c.customer_id = o.customer_id
join order_items oi on o.order_id = oi.order_id group by o.order_id;

-- Create a procedure sp_update_shipping_cost that updates the shipping cost for a specific order_id.

delimiter //

create procedure sp_update_shipping_cost (in p_order_id int, in p_new_cost decimal(10,2))

begin

update shipping_logs
set shipping_cost = p_new_cost
where order_id = p_order_id;

end //

delimiter ;

CALL sp_update_shipping_cost(3, 45.50);

SELECT * FROM shipping_logs WHERE order_id = 3;


-- When an order is cancelled, we need to do three things:

-- Delete the shipping log.

-- Delete the order items.

-- Delete the order itself.

delimiter //

create procedure sp_cancel_full_order(in p_order_id int)

begin

delete from shipping_logs where order_id = p_order_id;
delete from order_items where order_id = p_order_id;
delete from orders where order_id = p_order_id;

end // 

delimiter ;

-- Automatically upgrade a customer's segment to 'Corporate' if they have spent more than $5,000 in total.

DROP PROCEDURE IF EXISTS sp_add_item_to_order;
delimiter //

create procedure sp_check_and_promote_customer(in p_cust_id int)
begin
	declare v_total_spend decimal(10,2);
  
	select sum(actual_sale_price) into v_total_spend
	from order_items oi join orders o on oi.order_id = o.order_id
	where o.customer_id = p_cust_id;
  
	if v_total_spend > 5000 then 
		update customers set segment = 'Corporate' where customer_id =p_cust_id;
  
	end if;
  
  end //
  
  
DROP PROCEDURE IF EXISTS sp_add_item_to_order;

DELIMITER //

CREATE PROCEDURE sp_add_item_to_order(
    IN p_order_id INT, 
    IN p_prod_id INT, 
    IN p_qty INT
)
BEGIN
    
    DECLARE v_price DECIMAL(10,2);
    
    SELECT retail_price INTO v_price 
    FROM products 
    WHERE product_id = p_prod_id;

    IF p_qty > 10 THEN
        SET v_price = v_price * 0.90;
    END IF;

    INSERT INTO order_items (order_id, product_id, quantity, actual_sale_price)
    VALUES (p_order_id, p_prod_id, p_qty, v_price);
    
END //

DELIMITER ;


