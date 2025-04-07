from snowflake import connector
import pathlib
from dotenv import dotenv_values
import pandas as pd
from sqlalchemy import create_engine

# Load config
script_path = pathlib.Path(__file__).parent.parent.resolve()
config = dotenv_values(f"{script_path}/configuration.env")

# Create the connection URL with proper formatting
connection_url = (
    f"snowflake://{config.get('snowflake_user')}:"
    f"{config.get('snowflake_password')}@"
    f"{config.get('snowflake_account')}/"
    f"{config.get('snowflake_database')}/"
    f"{config.get('snowflake_schema')}?"
    f"warehouse={config.get('snowflake_warehouse')}&"
    f"role={config.get('snowflake_role')}"
)
engine = create_engine(connection_url)

# Load data with pandas
query = "SELECT * FROM BRITISH_DATA;"
df = pd.read_sql(query, engine)

print(df.head())
