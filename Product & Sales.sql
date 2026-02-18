-- Total Sales transactions
select count(*)
from sales;

-- List Unique product categories
select distinct category 
from products;

-- Total revenue from all sales
select sum(s.quantity * p.unitprice) as Total_revenue
from sales as s
join products as p
on s.ProductID = p.ProductID;

-- Revenue, Profit & Gross Margin Percentage
select sum(s.quantity * p.unitprice) as Total_revenue, 
	round(sum(quantity*(unitprice - unitcost)),0) as Profit,
    round((sum(quantity*(unitprice - unitcost))/ sum(s.quantity * p.unitprice))*100,2) as Gross_margin_percent
from sales as s
join products as p
on s.ProductID = p.ProductID;

-- Top 3 Product categories by revenue
select Category, sum(s.quantity * p.unitprice) as Total_revenue
from sales as s
join products as p
on s.ProductID = p.ProductID
group by category
order by 2 desc
limit 3;

-- Sales done by sales rep
select SalesRep,sum(Quantity) as Total_units, sum(s.quantity * p.unitprice) as Total_sales
from sales as s
join products as p
on s.ProductID = p.ProductID
group by 1
order by 3 desc;

-- Top 5 customers by revenue
select customername, sum(s.quantity * p.unitprice) as Total_revenue
from sales as s
join products as p
on s.ProductID = p.ProductID
join customers as c
on s.CustomerID = c.CustomerID
group by 1
order by 2 desc
limit 5;

-- Revenue by region
select region, sum(s.quantity * p.unitprice) as Total_revenue
from sales as s
join products as p
on s.ProductID = p.ProductID
join customers as c
on s.CustomerID = c.CustomerID
group by 1
order by 2 desc;

-- Profit per Product
select productname, round(sum(quantity*(unitprice - unitcost)),2) as Profit
from sales as s
join products as p
on s.ProductID = p.ProductID
group by 1
order by 2 desc;

-- Average order value by customer
select c.CustomerId, CustomerName, round(sum(s.quantity * p.unitprice)/count(distinct saleid),2) as avg_order_value
from sales as s
join products as p
on s.ProductID = p.ProductID
join customers as c
on s.CustomerID = c.CustomerID
group by 1,2
order by 3 desc;

-- Monthly sales trend
select year(SaleDate) as `Year`, month(SaleDate) as `Month`, sum(s.quantity * p.unitprice) as Total_revenue
from sales as s
join products as p
on s.ProductID = p.ProductID
group by 1,2
order by 1,2;

-- Top 10 High-value Customers by CLV 
select 
	c.CustomerId, CustomerName,
	sum(s.quantity * p.unitprice) as CLV, 
	count(distinct s.saleid) as total_orders, 
    max(cast(s.saledate as date)) as last_order_date,
    min(cast(s.saledate as date)) as first_order_date,
    round(avg(s.quantity * p.unitprice),2)as Avg_order_value
from sales as s
join products as p
on s.ProductID = p.ProductID
join customers as c
on s.CustomerID = c.CustomerID
group by 1,2    	
order by 3 desc
limit 10;

-- Top 10 products by profit margin percent
select ProductName, 
	round((sum(quantity*(unitprice - unitcost))/ sum(s.quantity * p.unitprice))*100,2) as Profit_margin_percent
from sales as s
join products as p
on s.ProductID = p.ProductID
group by 1
order by 2 desc
limit 10;

-- Running total revenue per year
select year(saleDate) as `Year`, sum(s.quantity * p.unitprice) as Revenue, 
sum(sum(s.quantity * p.unitprice)) over(order by year(saleDate)) as Running_total
from sales as s	
join products as p
on s.ProductID = p.ProductID
group by 1
order by 1;

-- Category contribution % to total revenue
select Category, 
	round(sum(s.quantity * p.unitprice)*100/ 
    (select sum(s1.quantity * p1.unitprice)from sales as s1 join products as p1 on s1.ProductID = p1.ProductID),2) 
    as Revenue_percent
from sales as s	
join products as p
on s.ProductID = p.ProductID
group by 1
order by 2 desc;

-- Customers with no purchases in last 1 year
select distinct c.CustomerId, CustomerName
from customers as c
left join sales as s
on c.CustomerId =s.CustomerId
where c.CustomerId not in(
	select CustomerId
    from sales
    where SaleDate >= current_date - interval 1 year
);

-- Year-over-year(YoY) revenue growth
select year(SaleDate) as `Year`, sum(s.quantity * p.unitprice) as Revenue,
	lag(sum(s.quantity * p.unitprice)) over(order by year(SaleDate)) as Prev_year_revenue,
    round((sum(s.quantity * p.unitprice) - lag(sum(s.quantity * p.unitprice)) over(order by year(SaleDate)))*100/
    nullif(lag(sum(s.quantity * p.unitprice)) over(order by year(SaleDate)),0),2) as YoY_growth_percent
from sales as s	
join products as p
on s.ProductID = p.ProductID
group by 1;

-- Customers with declining YoY revenue
with cte_revenue as(
	select c.CustomerId, CustomerName, year(SaleDate) as `Year`, sum(s.quantity * p.unitprice) as Revenue
    from sales as s
	join products as p
	on s.ProductID = p.ProductID
	join customers as c
	on s.CustomerID = c.CustomerID
    group by 1,2,3
), 
cte_prev as(
	select CustomerId, CustomerName, Revenue,`Year`, lag(Revenue) over(partition by customerid order by `year`) as prev_revenue
    from cte_revenue
)
select CustomerId, CustomerName, `Year`, Revenue as actual_revenue, prev_revenue, (Revenue-prev_revenue) as YoY_change
from cte_prev
where Revenue < prev_revenue and prev_revenue is not null
group by 1,2,3
order by 2, 4;

-- Repeat vs new customers
with cte_first as(
	select CustomerId, min(SaleDate) as first_order
    from sales as s
    group by 1
)
select month(SaleDate) as `Month`,
		count(distinct case when month(first_order) = month(SaleDate) then s.CustomerId end) as New_Customer,
		count(distinct case when month(first_order) < month(SaleDate) then s.CustomerId end) as Repeat_Customer
from sales as s
join cte_first as c
on s.CustomerId = c.CustomerId
group by 1
order by 1;

-- Top Sales rep each year
with cte_sales_rep as (
	select year(SaleDate) as `Year`, SalesRep,  sum(s.quantity * p.unitprice) as Revenue,
		rank() over(partition by year(SaleDate) order by sum(s.quantity * p.unitprice) desc) as ranks
	from sales as s
	join products as p
	on s.ProductID = p.ProductID
    group by 1,2
)
select `Year`, SalesRep, Revenue
from cte_sales_rep as c
where ranks = 1;

-- RFM(Recency, Frequency, Monetary) segmentation
with cte_rfm as(
	select c.CustomerID, max(SaleDate) as last_order, count(s.SaleId) as Frequency,
		   sum(s.quantity * p.unitprice) as Monetary
    from sales as s
	join products as p
	on s.ProductID = p.ProductID
    join customers as c
	on s.CustomerID = c.CustomerID
    group by 1
)
select CustomerId, datediff(current_date, last_order) as Recency, Frequency, Monetary
from cte_rfm
order by 1;






