# Data Dictionary for silver Layer

## Overview

The **silver Layer** is the cleaned and processed data layer, where raw data has been transformed and standardised. 
It consists of **dimension tables** and **fact tables** that capture sales order management business processes: customer, product, store, sales rep, orders, shipments, and inventory.

---

## 1. silver\_customers

**Purpose**: Stores customer details enriched with demographic and geographic data for analytics.

| Column Name          | Data Type    | Description                                                                           |
| -------------------- | ------------ | --------------------------------------------------------------------------------------|                              
| customer\_id         | VARCHAR(10)  | Unique identifier assign to each customers                                            |
| customer\_full\_name | VARCHAR(100) | Customer’s full name.                                                                 |
| customer\_address    | VARCHAR(255) | Customer’s address.                                                                   |
| customer\_state      | VARCHAR(30)  | Customer’s state of residence.                                                        |
| customer\_country    | VARCHAR(30)  | Customer’s country of residence.                                                      |
| customer\_postcode   | VARCHAR(20)  | Customer’s postal code.                                                               |
| customer\_age        | INT          | Customer’s age (derived from source data).                                            |
| customer\_gender     | VARCHAR(10)  | Customer’s gender.                                                                    |
                                                     

---

## 2. silver\_products

**Purpose**: Provides product master data including categories, pricing, and identifiers.

| Column Name          | Data Type     | Description                                                                           |
| -------------------- | ------------- | --------------------------------------------------------------------------------------| 
| product\_id          | VARCHAR(10)   | Natural identifier assigned to each product.                                          |
| product\_name        | VARCHAR(100)  | Product name.                                                                         |
| product\_category    | VARCHAR(50)   | Product category (e.g., Electronics, Apparel).                                        |
| product\_number      | VARCHAR(30)   | Product reference or SKU number.                                                      |
| product\_price\_usd  | DECIMAL(10,2) | Product unit price in USD.                                                            |
                                                     

---

## 3. silver\_store

**Purpose**: Stores details about physical stores.

| Column Name          | Data Type    | Description                                           |
| -------------------- | ------------ | ----------------------------------------------------- | 
| store\_location\_id  | VARCHAR(10)  | Unique identifier for the store location.             |
| store\_address       | VARCHAR(255) | Location of the store.                                |
| store\_city          | VARCHAR(50)  | City where store is located.                          |
| store\_country       | VARCHAR(50)  | Country where store is located.                       |
| store\_postcode      | VARCHAR(20)  | Postcode where store is located.                      |
                    

---

## 4. silver\_sales\_person

**Purpose**: Stores information on sales representatives, their roles, and salaries.

| Column Name          | Data Type     | Description                                               |
| -------------------- | ------------- | --------------------------------------------------------- |     
| sales\_person\_id    | VARCHAR(10)   | Unique identifier for the sales person.                   |
| store\_location\_id  | VARCHAR(10)   | Identifier of store where sales person assigned.          |
| sales\_rep\_name     | VARCHAR(100)  | Full name of sales representative.                        |
| manager\_flag        | VARCHAR(10)   | Indicates if the sales rep is a manager (Yes/No/Unknown). |
| sales\_rep\_salary   | DECIMAL(10,2) | Sales representative’s salary (USD).                      |
| store\_address       | VARCHAR(255)  | Store address where sales rep is assigned.                |
| store\_city          | VARCHAR(50)   | Store city where sales rep is assigned.                   |
| store\_country       | VARCHAR(50)   | Store country where sales rep is assigned.                |
| store\_postcode      | VARCHAR(20)   | Store postcode where sales rep is assigned.               |
                        

---

## 5. silver\_sales\_order

**Purpose**: Captures details of customer orders, including quantities, values, and related entities.

| Column Name               | Data Type     | Description                                                |
| ------------------------- | ------------- | ---------------------------------------------------------- |  
| order\_id                 | VARCHAR(10)   | Unique identifier for the order.                           |
| product\_id               | VARCHAR(10)   | Identifier of the ordered product.                         |
| store\_location\_id       | VARCHAR(10)   | Store where the order was placed.                          |
| customer\_id              | VARCHAR(10)   | Customer who placed the order.                             |
| sales\_person\_id         | VARCHAR(10)   | Sales representative who handled the order.                |
| order\_number             | VARCHAR(20)   | order number.                                              |
| order\_line\_status       | VARCHAR(20)   | Status of the order line (e.g., Open, Shipped, Cancelled). |
| ordered\_quantity         | INT           | Ordered quantity.                                          |
| cancelled\_quantity       | INT           | Cancelled quantity.                                        |
| returned\_quantity        | INT           | Returned quantity.                                         |
| actual\_ordered\_quantity | INT           | Net quantity ordered (after cancellations/returns).        |
| product\_price\_usd       | DECIMAL(10,2) | Unit price of product.                                     |
| order\_value\_usd         | DECIMAL(12,2) | Total value of the order line.                             |
| customer\_request\_date   | DATE          | Customer’s requested delivery date.                        |
| ship\_date                | DATE          | Actual shipment date.                                      |
| order\_creation\_date     | DATE          | Order creation timestamp.                                  |
| payment\_method           | VARCHAR(30)   | Payment method used.                                       |
| product\_number           | VARCHAR(30)   | Product reference/SKU.                                     |
| invoice\_number           | VARCHAR(30)   | Invoice number.                                            |
| sales\_rep\_name          | VARCHAR(100)  | Sales rep handling the order.                              |
| customer\_name            | VARCHAR(100)  | Customer name.                                             |
| product\_name             | VARCHAR(100)  | Product name.                                              |
| product\_category         | VARCHAR(50)   | Product category.                                          |
| store\_address            | VARCHAR(255)  | Store address.                                             |
| store\_city               | VARCHAR(50)   | Store city.                                                |
| store\_country            | VARCHAR(50)   | Store country.                                             |
| store\_postcode           | VARCHAR(20)   | Store postal code.                                         |                         

---

## 6. silver\_order\_ship

**Purpose**: Captures shipments, deliveries, and fulfillment details for sales orders.

| Column Name          | Data Type    | Description                                                                |
| -------------------- | ------------ | ---------------------------------------------------------------------------|       
| order\_id            | VARCHAR(10)  | Associated order identifier.                                               |
| ship\_id             | VARCHAR(10)  | Shipment identifier.                                                       |
| product\_id          | VARCHAR(10)  | Product identifier.                                                        |
| store\_location\_id  | VARCHAR(10)  | Store shipping the product.                                                |
| delivery\_status     | VARCHAR(20)  | Status of delivery (e.g., Shipped, Delivered, Cancelled).                  |
| customer\_id         | VARCHAR(10)  | Customer receiving the shipment.                                           |
| delivery\_number     | VARCHAR(20)  | Delivery reference number.                                                 |
| delivery\_type       | VARCHAR(20)  | Delivery type (e.g., Express, Standard).                                   |
| cancelled\_quantity  | INT          | Quantity cancelled in shipment.                                            |
| shipped\_quantity    | INT          | Quantity shipped.                                                          |
| delivered\_quantity  | INT          | Quantity delivered.                                                        |
| delivery\_date       | DATE         | Date of delivery.                                                          |
| ship\_date           | DATE         | Date of shipment.                                                          |
| shipping\_method     | VARCHAR(30)  | Shipping method used (e.g., Air, Road).                                    |
| carrier\_type        | VARCHAR(30)  | Carrier type (e.g., FedEx, DHL).                                           |
| tracking\_number     | VARCHAR(50)  | Tracking number for shipment.                                              |
| customer\_name       | VARCHAR(100) | Customer name.                                                             |
| ship\_to\_address    | VARCHAR(255) | Shipping destination address.                                              |
| ship\_to\_state      | VARCHAR(50)  | Shipping destination state.                                                |
| ship\_to\_country    | VARCHAR(50)  | Shipping destination country.                                              |
| ship\_to\_postcode   | VARCHAR(20)  | Shipping destination postal code.                                          |
| ship\_from\_address  | VARCHAR(255) | Origin store address.                                                      |
| ship\_from\_city     | VARCHAR(50)  | Origin store city.                                                         |
| ship\_from\_country  | VARCHAR(50)  | Origin store country.                                                      |
| ship\_from\_postcode | VARCHAR(20)  | Origin store postal code.                                                  |                                          |

---

