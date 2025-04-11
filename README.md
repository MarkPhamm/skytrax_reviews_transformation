# British Airways `dbt-airflow` Transformation Pipelines

## Data Model Overview

### **Step 1: Business Processes**
Business processes represent real-world events that generate measurable data. For British Airways, the core business process is the **collection of customer flight reviews**. Each review submitted by a customer reflects their experience on a specific flight and becomes a fact event. These reviews include detailed ratings on various service categories, forming the backbone of our analytical layer.

### **Step 2: Define the Grain**
The grain defines the level of detail stored in the fact table. For this model, the grain is defined as:

> **One customer review per flight.**

Each row in the `fct_review` table represents a unique review event containing metrics tied to a specific customer’s flight experience. This atomic grain ensures consistency and supports granular performance analysis across multiple service touchpoints.

### **Step 3: Dimensions for Descriptive Context**
Dimension tables provide the **who, what, where, when** context for interpreting facts.

- **Who:** `dim_customer` — describes the reviewer through `customer_name`, `nationality`, and `number_of_flights`.
- **What:** `dim_aircraft` — provides context on the aircraft via `aircraft_model`, `aircraft_manufacturer`, and `seat_capacity`.
- **Where:** `dim_location` — captures the origin, destination, and transit points, using a combination of `city` and `airport_name`.
- **When:** `dim_date` — captures both `date_flown` and `date_submitted` and supports calendar and financial date logic (`cal_year`, `fin_quarter`, etc.).

### **Step 4: Facts for Measurement**
Facts are the **quantitative outputs** from the review process, collected per flight review:

- **Ratings:**  
  `seat_comfort`, `cabin_staff_service`, `food_and_beverages`, `inflight_entertainment`, `ground_service`, `wifi_and_connectivity`, `value_for_money`

- **Booleans:**  
  `verified`, `recommended`

- **Categorical Descriptions:**  
  `seat_type`, `type_of_traveller`, `review_text`

These facts represent real customer input and form the foundation for performance dashboards, KPIs, and customer sentiment insights.

---

## Star Schema Implementation

This model follows a classic **star schema** structure where the `fct_review` table sits at the center and joins to dimension tables via foreign keys:

| Foreign Key in `fct_review`      | Dimension Table      | Description                            |
|----------------------------------|-----------------------|----------------------------------------|
| `customer_id`                    | `dim_customer`        | Links each review to a specific customer |
| `date_submitted_id` / `date_flown_id` | `dim_date`       | Supports dual-date tracking (when submitted vs when flown) |
| `origin_location_id`, `destination_location_id`, `transit_location_id` | `dim_location` | Connects review to flight locations |
| `aircraft_id`                    | `dim_aircraft`        | Captures aircraft-related context |

This schema supports efficient slicing, filtering, and aggregation of reviews by date, location, customer, and aircraft, enabling detailed insights across British Airways’ customer experience.
