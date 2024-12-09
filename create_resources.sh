#!/bin/bash

# This script creates the resources used in the tutorial https://learn.microsoft.com/azure/developer/python/tutorial-deploy-python-web-app-azure-container-apps-01
# Make sure you are logged in to Azure. If unsure, run "az login" before using this script.

# Make sure the the Azure CLI is up to date and that 
# the containerapp and rdbms-connect extensions are installed and current
#
# az upgrade
# az extension add --name containerapp --upgrade
# az extension add --name rdbms-connect --upgrade

# Define values.

echo "Where is the code located? (Use . for current directory.)"
read CODE_LOCATION

echo "Enter a password for the PostgreSQL database instance:"
read ADMIN_PASSWORD

echo "What location do you want for the resource group? Examples: eastus, southcentralus, westeurope, southeastasia, australiaeast, japaneast, brazilsouth"
read LOCATION

echo "Enter a target port the container communicates on, e.g., 8000 for Django or 5000 for Flask"
read TARGET_PORT

UNIQUE=$(echo $RANDOM | md5sum | head -c 6)
RESOURCE_GROUP="pythoncontainer-rg-"$UNIQUE
echo "INFO:: Here's the resource group that will be used: $RESOURCE_GROUP."
echo "INFO:: Delete this resource group to delete all resources used in this demo."

REGISTRY_NAME="registry"$UNIQUE
IMAGE_NAME="pythoncontainer:latest"
POSTGRESQL_NAME="postgresql-db-"$UNIQUE
ADMIN_USER="demoadmin"
CONTAINER_ENV_NAME="python-container-env"
CONTAINER_APP_NAME="python-container-app"

# Create resource group.

az group create \
--name $RESOURCE_GROUP \
--location $LOCATION
echo "INFO:: Created resource group: $RESOURCE_GROUP."

# Create a container registry.

az acr create \
--resource-group $RESOURCE_GROUP \
--name $REGISTRY_NAME \
--sku Basic \
--admin-enabled
echo "INFO:: Created container registry: $REGISTRY_NAME."

az acr login --name $REGISTRY_NAME
echo "INFO:: Logged into container registry: $REGISTRY_NAME."

# Build image in Azure.

az acr build \
--registry $REGISTRY_NAME \
--resource-group $RESOURCE_GROUP \
--image $IMAGE_NAME $CODE_LOCATION
echo "INFO:: Completed building image: $IMAGE_NAME."

# Create PostgreSQL database server.

az postgres flexible-server create \
   --resource-group $RESOURCE_GROUP \
   --name $POSTGRESQL_NAME  \
   --location $LOCATION \
   --admin-user $ADMIN_USER \
   --admin-password $ADMIN_PASSWORD \
   --active-directory-auth Enabled \
   --tier burstable \
   --sku-name Standard_B1ms \
   --public-access 0.0.0.0
echo "INFO:: Created PostgreSQL database server: $POSTGRESQL_NAME."

# Add signed-in user as Microsoft Entra admin on the server

az postgres flexible-server ad-admin create \
   --resource-group $RESOURCE_GROUP \
   --server-name $POSTGRESQL_NAME  \
   --display-name $(az ad signed-in-user show --query mail --output tsv) \
   --object-id $(az ad signed-in-user show --query id --output tsv)

# Create a database on the PostgreSQL server.

az postgres flexible-server db create \
   --resource-group $RESOURCE_GROUP \
   --server-name $POSTGRESQL_NAME \
   --database-name restaurants_reviews
echo "INFO:: Completed creating database restaurants_reviews on PostgreSQL server: $POSTGRESQL_NAME."

# Create a user-assigned managed identity named my-ua-managed-id to access database

az identity create \
   --name my-ua-managed-id \
   --resource-group pythoncontainer-rg

# Add user assigned managed identity as role on server (requires rdbms-connect extension for token)

az postgres flexible-server execute \
    --name $POSTGRESQL_NAME \
    --database-name postgres \
    --querytext "select * from pgaadauth_create_principal('"my-ua-managed-id"', false, false);select * from pgaadauth_list_principals(false);" \
    --admin-user $(az ad signed-in-user show --query mail --output tsv) \
    --admin-password $(az account get-access-token --resource-type oss-rdbms --output tsv --query accessToken)

# Grant the user assigned managed identity necessary permissions on restaurants_reviews database (requires rdbms-connect extension for token)

az postgres flexible-server execute \
    --name $POSTGRESQL_NAME \
    --database-name restaurants_reviews \
    --querytext "GRANT CONNECT ON DATABASE restaurants_reviews TO \"my-ua-managed-id\";GRANT USAGE ON SCHEMA public TO \"my-ua-managed-id\";GRANT CREATE ON SCHEMA public TO \"my-ua-managed-id\";GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"my-ua-managed-id\";ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO \"my-ua-managed-id\";" \
    --admin-user $(az ad signed-in-user show --query mail --output tsv) \
    --admin-password $(az account get-access-token --resource-type oss-rdbms --output tsv --query accessToken)


# Deploy (requires containerapp extension)

# Create a container apps environment.

az containerapp env create \
--name $CONTAINER_ENV_NAME \
--resource-group $RESOURCE_GROUP \
--location $LOCATION
echo "INFO:: Completed creating container apps environment: $CONTAINER_ENV_NAME."

# Get sign-in credentials for Azure Container Registry.

ACR_USERNAME=$(az acr credential show --name $REGISTRY_NAME --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name $REGISTRY_NAME --query passwords[0].value --output tsv)

# Get client ID for user assigned managed identity

MID_CLIENT_ID=$(az identity show --name my-ua-managed-id --resource-group $RESOURCE_GROUP --query clientId --output tsv)
MID_RESOURCE_ID=$(az identity show --name my-ua-managed-id --resource-group $RESOURCE_GROUP --query id --output tsv)

# Create container app.

ENV_VARS="DBHOST=$POSTGRESQL_NAME DBNAME=restaurants_reviews DBUSER=my-ua-managed-id RUNNING_IN_PRODUCTION=1 AZURE_CLIENT_ID=$MID_CLIENT_ID"
echo $ENV_VARS

az containerapp create \
--name $CONTAINER_APP_NAME \
--resource-group $RESOURCE_GROUP \
--image $REGISTRY_NAME.azurecr.io/$IMAGE_NAME \
--environment $CONTAINER_ENV_NAME \
--ingress external \
--target-port $TARGET_PORT \
--min-replicas 1 \
--registry-server $REGISTRY_NAME.azurecr.io \
--registry-username $ACR_USERNAME \
--registry-password $ACR_PASSWORD \
--user-assigned $MID_RESOURCE_ID \
--env-vars $ENV_VARS \
--query properties.configuration.ingress.fqdn
echo "INFO:: Completed creating container app $CONTAINER_APP_NAME."

echo "INFO:: If using Django, connect to the container and migrate the schema."
echo "INFO:: Use the following command:"
echo "INFO:: az containerapp exec --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP"
echo "INFO:: Then, run 'python manage.py migrate'."
echo "INFO:: Then, type 'exit'."