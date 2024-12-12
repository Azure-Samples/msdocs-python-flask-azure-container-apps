from pathlib import Path
import os

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

DEBUG = True

if 'USE_REMOTE_POSTGRESQL' in os.environ:
    DATABASE_URI = 'postgresql+psycopg2://{dbuser}:{dbpass}@{dbhost}/{dbname}'.format(
        dbuser=os.environ['DBUSER'],
        dbpass='PASSWORDORTOKEN',
        dbhost=os.environ['DBHOST'] + ".postgres.database.azure.com",
        dbname=os.environ['DBNAME']
    )
else:
    DATABASE_URI = 'postgresql+psycopg2://{dbuser}:{dbpass}@{dbhost}/{dbname}'.format(
        dbuser=os.environ['DBUSER'],
        dbpass= os.environ['DBPASS'],
        dbhost=os.environ['DBHOST'],
        dbname=os.environ['DBNAME']
    )

TIME_ZONE = 'UTC'

STATICFILES_DIRS = (str(BASE_DIR.joinpath('static')),)
STATIC_URL = 'static/'
