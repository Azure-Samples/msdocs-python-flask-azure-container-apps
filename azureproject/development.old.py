from pathlib import Path
import os

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

DEBUG = True

SECRET_KEY = os.getenv('LOCAL_SECRET_KEY')

# Configure database connection for remote PostgreSQL instance.
if 'USE_REMOTE_POSTGRESQL' in os.environ:
    DBHOST=os.environ['AZURE_POSTGRESQL_HOST']
    DBNAME=os.environ['AZURE_POSTGRESQL_DATABASE']
    DBUSER=os.environ['AZURE_POSTGRESQL_USERNAME']
    DBPASS=os.environ['AZURE_POSTGRESQL_PASSWORD']
else:
    # Local to instance settings.
    DBHOST=os.environ['LOCAL_HOST']
    DBNAME=os.environ['LOCAL_DATABASE']
    DBUSER=os.environ['LOCAL_USERNAME']
    DBPASS=os.environ['LOCAL_PASSWORD']

DATABASE_URI = 'postgresql+psycopg2://{dbuser}:{dbpass}@{dbhost}/{dbname}'.format(
    dbuser=DBUSER,
    dbpass=DBPASS,
    dbhost=DBHOST,
    dbname=DBNAME
)

TIME_ZONE = 'UTC'

STATICFILES_DIRS = (str(BASE_DIR.joinpath('static')),)
STATIC_URL = 'static/'
