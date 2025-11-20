export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
export TF_YC_CLOUD_ID=$YC_CLOUD_ID
export TF_YC_TOKEN=$YC_TOKEN
export TF_YC_FOLDER_ID=$YC_FOLDER_ID

export TF_VAR_yc_cloud_id=$YC_CLOUD_ID
export TF_VAR_yc_token=$YC_TOKEN
export TF_VAR_yc_folder_id=$YC_FOLDER_ID

export TF_YC_SUBNET=$(yc vpc subnet list --format=json | jq -r '.[] | select(.zone_id == "ru-central1-a").id' )

# let's check
env | grep -e YC_F -e YC_S

