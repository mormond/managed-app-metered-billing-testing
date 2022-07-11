# This is a series of bash code snippets to call the metered billing API
# Adapted from https://docs.microsoft.com/en-us/azure/marketplace/marketplace-metering-service-authentication

#
# Call the ARM APIs to get information about the app's managed resource group
# In particular the managed app id which is required to submit metering events
#
HEADER="Metadata:true"

#CLIENT_ID=""

# Sometimes the resource has multiple client IDs in which case you need to explicitly define it (above)
if [[ -v CLIENT_ID ]]
then
    METADATA_URL="http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F&client_id=$CLIENT_ID"
else
    METADATA_URL="http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F"
    echo "No client ID"
fi

# Get an auth token for the ARM API and construct the auth header for the ARM request
METADATA_TOKEN=$(curl -H "$HEADER" "$METADATA_URL" | jq -r '.access_token') 
METADATA_AUTH_HEADER="Authorization:Bearer $METADATA_TOKEN"

# Get instance metadata to extract the subscription and resource group details
METADATA=$(curl -H $HEADER http://169.254.169.254/metadata/instance?api-version=2019-06-01)
SUB_ID=$(echo "$METADATA" | jq -r '.compute.subscriptionId')
RG_NAME=$(echo "$METADATA" | jq -r '.compute.resourceGroupName')

# Call the ARM API to get the managed app ID
MANAGEMENTURL="https://management.azure.com/subscriptions/$SUB_ID/resourceGroups/$RG_NAME?api-version=2019-10-01"
RG_INFO=$(curl -H "$HEADER" -H "$METADATA_AUTH_HEADER" "$MANAGEMENTURL")
MANAGED_APP_ID=$(echo "$RG_INFO" | jq -r '.managedBy')

#
# Call the metering service to report an event
#
if [[ -v CLIENT_ID ]]
then
    METERING_API_TOKEN_URL="http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=20e940b3-4c77-4b0b-9a53-9e16a1b010a7&client_id=$CLIENT_ID"
else
    METERING_API_TOKEN_URL="http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=20e940b3-4c77-4b0b-9a53-9e16a1b010a7"
    echo "No client ID"
fi

# Get an auth token for the metered billing API resouce - 20e940b3-4c77-4b0b-9a53-9e16a1b010a7
METERING_API_TOKEN=$(curl -H "$HEADER" "$METERING_API_TOKEN_URL" | jq -r '.access_token')
METERING_AUTH_HEADER="Authorization:Bearer $METERING_API_TOKEN"

# Call the metered billing API to report a usage event
START_TIME="2022-05-31T15:30:14"
QUANTITY=5.0
DIMENSION="0"
PLAN_ID="metered"
curl -X POST -H "$METERING_AUTH_HEADER" -H "Content-Type: application/json" \
 "https://marketplaceapi.microsoft.com/api/usageEvent?api-version=2018-08-31" \
 -d "{ \"resourceUri\": \"$MANAGED_APP_ID\", \"quantity\": $QUANTITY, \"dimension\": \"$DIMENSION\", \"effectiveStartTime\": \"$START_TIME\", \"planId\": \"$PLAN_ID\" }"

