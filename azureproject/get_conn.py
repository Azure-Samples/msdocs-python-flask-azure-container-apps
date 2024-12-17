import os

from azure.identity import DefaultAzureCredential
from flask import current_app


def get_conn():
    # Azure hosted, refresh token that is used as the PostgreSQL password.
    azure_credential = DefaultAzureCredential()
    # Get token for Azure Database for PostgreSQL
    token = azure_credential.get_token("https://ossrdbms-aad.database.windows.net/.default")
    conn = current_app.config.get('DATABASE_URI').replace('PASSWORDORTOKEN', token.token)
    return conn
