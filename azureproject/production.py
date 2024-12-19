import os
import secrets

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.getenv('AZURE_SECRET_KEY') or secrets.token_hex()

DEBUG = False
ALLOWED_HOSTS = [os.environ['WEBSITE_HOSTNAME']] if 'WEBSITE_HOSTNAME' in os.environ else []
CSRF_TRUSTED_ORIGINS = ['https://'+ os.environ['WEBSITE_HOSTNAME']] if 'WEBSITE_HOSTNAME' in os.environ else []

# Configure Postgres database; the full username for PostgreSQL flexible server is
# username (not @server-name).
DATABASE_URI = 'postgresql+psycopg2://{dbuser}:{dbpass}@{dbhost}/{dbname}?sslmode=require'.format(
    dbuser=os.environ['DBUSER'],
    dbpass='PASSWORDORTOKEN',
    dbhost=os.environ['DBHOST'] + ".postgres.database.azure.com",
    dbname=os.environ['DBNAME']
)
