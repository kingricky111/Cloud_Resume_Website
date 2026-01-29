import logging
import os
import json

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from azure.data.tables import TableServiceClient
from azure.core.exceptions import ResourceNotFoundError

logging.basicConfig(level=logging.INFO)

app = FastAPI()

# CORS (mirrors what you had configured already)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "OPTIONS"],
    allow_headers=["*"],
)


@app.get("/visits")
def get_visit_count():
    logging.info("Processing visit count request")

    # Same environment variables as Azure Function
    conn_str = os.getenv("TABLES_CONNECTION_STRING")
    table_name = os.getenv("TABLES_TABLE_NAME")

    if not conn_str or not table_name:
        logging.error("Missing TABLES_CONNECTION_STRING or TABLES_TABLE_NAME")
        raise HTTPException(status_code=500, detail="Server configuration error")

    service = TableServiceClient.from_connection_string(conn_str)
    table_client = service.get_table_client(table_name)

    partition_key = "counter"
    row_key = "site"

    try:
        # Try to get the existing entity
        entity = table_client.get_entity(
            partition_key=partition_key,
            row_key=row_key
        )
        current_count = int(entity.get("Count", 0))
        new_count = current_count + 1
        entity["Count"] = new_count
        table_client.update_entity(entity)

    except ResourceNotFoundError:
        # If not found, create the first record
        new_count = 1
        entity = {
            "PartitionKey": partition_key,
            "RowKey": row_key,
            "Count": new_count,
        }
        table_client.create_entity(entity)

    return {"count": new_count}