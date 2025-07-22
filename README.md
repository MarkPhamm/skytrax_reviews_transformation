# British Airways Data Transformation

This project implements a modern data transformation pipeline for British Airways, designed to process and model customer review data from [Airline Quality](https://www.airlinequality.com/airline-reviews/british-airways/). It leverages **dbt**, **Snowflake**, and **Apache Airflow**, orchestrated via **Astronomer**, to create a scalable, production-ready workflow.

![image](https://github.com/user-attachments/assets/44063b8d-ad6b-45a3-b802-de5b449cc5d4)

---

## 🗂 Project Structure

```
.
├── data/                 # Raw and processed data files
├── data_model/           # Data model diagrams and definitions
│   ├── schema.jpeg       # Visual data model
│   └── schema.txt        # Text-based schema description
├── dbt-dags/             # dbt models and Airflow DAGs
│   ├── dags/             # DAG definitions
│   ├── tests/            # Data quality tests
│   └── .astro/           # Astronomer CLI configuration
├── notebooks/            # Jupyter notebooks for Snowflake analysis
│   ├── snowflake_connection.ipynb
│   └── snowflake_connection.py
└── requirements.txt      # Python package requirements
```

---

## ⚙️ Technology Stack
<img width="1560" height="540" alt="image" src="https://github.com/user-attachments/assets/57dc62cb-46b2-4586-b1f6-5225ab8ca2af" />

- **Data Source**: [British Airways Reviews on AirlineQuality](https://www.airlinequality.com/airline-reviews/british-airways/)
- **Programming Language**: Python 3.12.5  
- **Data Warehouse**: Snowflake  
- **Transformation Tool**: dbt
- **Orchestration**: Apache Airflow powered by [Astronomer](https://www.astronomer.io/)  

---

## 🧱 Data Architecture

### 1. Data Source
Customer reviews are scraped from [AirlineQuality.com](https://www.airlinequality.com/airline-reviews/british-airways/), capturing structured and unstructured data elements including:

- **Flight Route** (e.g., *Singapore to Sydney*)  
- **Aircraft Type** (e.g., *Boeing 777*)
- **Seat Type** (e.g., *Business Class*)  
- **Type of Traveller** (e.g., *Solo Leisure*)  
- **Date Flown** (e.g., *March 2025*) 
- **Star Ratings** (Seat Comfort, Cabin Staff, Food & Beverages, Entertainment, Ground Service, Value for Money)  
- **Review Text** and **Submission Date**  
- **Verification Flag** (Trip Verified)  
- **Reviewer Info** (Name, Country, Number of Reviews)
--- 

### 2. Data Model

#### Dimension Tables
- `dim_customer`: Identity, loyalty, and flight history  
- `dim_aircraft`: Manufacturer, model, and seating layout  
- `dim_location`: Airports, cities, and time zones  
- `dim_date`: Calendar and fiscal date tracking  

#### Fact Table
- `fct_review`: One row per customer review per flight  
  - Includes metrics (ratings), booleans (verified, recommended), and categorical fields (seat type, travel type)

### 3. Data Flow
- **Source Layer**: Web scraping + staging  
- **Transformation Layer**: dbt modeling + business logic  
- **Orchestration Layer**: DAG scheduling and task dependency management via **Astronomer**  
- **Presentation Layer**: Clean fact/dim tables for BI/reporting

### 4. Data Quality Framework
- Null checks  
- Foreign key validation  
- Freshness and completeness monitoring  
- dbt tests for schema integrity and logic rules  

---

## 🧩 Project Components

### 📊 Data Model

Located in `data_model/`:
- `schema.jpeg`: visual schema overview  
- `schema.txt`: detailed textual schema

### 🛠 dbt + Airflow with Astronomer

Located in `dbt-dags/`:
- dbt model definitions and tests  
- Airflow DAGs orchestrated via **Astro CLI**
- Modular structure for local development and deployment to Astronomer Cloud or Docker environments

### 📈 Analysis & Validation

Notebook resources in `notebooks/` for:
- Establishing a connection to Snowflake  
- Running exploratory queries  
- Testing pipeline output  

---

## 📦 Key Dependencies

- `dbt-snowflake==1.9.2`  
- `pandas==2.2.3`  
- `snowflake-sqlalchemy==1.7.3`  
- Managed via `requirements.txt`

---

## 🔄 CI/CD Pipeline

This project uses GitHub Actions for automated data transformation pipeline:

### Workflow Triggers
- **Push**: Triggers on pushes to `main` branch
- **Pull Request**: Runs on PRs to `main` branch
- **Schedule**: Executes daily at 00:00 UTC
- **Manual**: Can be triggered via workflow_dispatch

### Pipeline Steps
1. **Environment Setup**
   - Python 3.12 setup
   - Dependencies installation
   - dbt package installation

2. **Data Transformation**
   - Runs dbt build process
   - Uses Snowflake credentials from secrets

3. **Notifications**
   - Sends email notifications on completion
   - Includes run time, trigger info, and status

### Workflow Status
[![BA Transformation](https://github.com/MarkPhamm/british-airways-transformation/actions/workflows/cicd.yml/badge.svg)](https://github.com/MarkPhamm/british-airways-transformation/actions/workflows/cicd.yml)

---

## 🌐 Data Modeling Approach
Let me know if you'd like a diagram for the Airflow DAG flow or a `README.md` version with clickable section links and badges.

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

## ⭐ Star Schema Overview

This model follows a classic **star schema** structure where the `fct_review` table sits at the center and joins to dimension tables via foreign keys:

| Foreign Key in `fct_review`      | Dimension Table      | Description                            |
|----------------------------------|-----------------------|----------------------------------------|
| `customer_id`                    | `dim_customer`        | Links each review to a specific customer |
| `date_submitted_id` / `date_flown_id` | `dim_date`       | Supports dual-date tracking (when submitted vs when flown) |
| `origin_location_id`, `destination_location_id`, `transit_location_id` | `dim_location` | Connects review to flight locations |
| `aircraft_id`                    | `dim_aircraft`        | Captures aircraft-related context |

![schema](https://github.com/user-attachments/assets/f6276b06-9f03-410a-b2cc-785b0a23b8f2)

This schema supports efficient slicing, filtering, and aggregating reviews by date, location, customer, and aircraft, enabling detailed insights across British Airways’ customer experience.

