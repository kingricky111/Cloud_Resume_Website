import logging
import os
import json

import azure.functions as func
from azure.data.tables import TableServiceClient
from azure.core.exceptions import ResourceNotFoundError


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Processing visit count request")

    # Read connection info from app settings (Terraform created these)
    conn_str = os.getenv("TABLES_CONNECTION_STRING")
    table_name = os.getenv("TABLES_TABLE_NAME")

    if not conn_str or not table_name:
        logging.error("Missing TABLES_CONNECTION_STRING or TABLES_TABLE_NAME")
        return func.HttpResponse(
            json.dumps({"error": "Server configuration error"}),
            status_code=500,
            mimetype="application/json",
        )

    service = TableServiceClient.from_connection_string(conn_str)
    table_client = service.get_table_client(table_name)

    partition_key = "counter"
    row_key = "site"

    try:
        # Try to get the existing entity
        entity = table_client.get_entity(partition_key=partition_key, row_key=row_key)
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

    body = json.dumps({"count": new_count})

    # CORS is already configured in Terraform, but we can be extra-safe here
    return func.HttpResponse(
        body,
        status_code=200,
        mimetype="application/json",
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
        },
    )
