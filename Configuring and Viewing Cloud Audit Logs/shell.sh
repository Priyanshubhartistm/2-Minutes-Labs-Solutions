clear

#!/bin/bash
# Define color variables

BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`

# Array of color codes excluding black and white
TEXT_COLORS=($RED $GREEN $YELLOW $BLUE $MAGENTA $CYAN)
BG_COLORS=($BG_RED $BG_GREEN $BG_YELLOW $BG_BLUE $BG_MAGENTA $BG_CYAN)

# Pick random colors
RANDOM_TEXT_COLOR=${TEXT_COLORS[$RANDOM % ${#TEXT_COLORS[@]}]}
RANDOM_BG_COLOR=${BG_COLORS[$RANDOM % ${#BG_COLORS[@]}]}

# Function to prompt user to check their progress
function check_progress {
    while true; do
        echo
        echo -n "${BOLD}${YELLOW}Have you created sink AuditLogsExport? (Y/N): ${RESET}"
        read -r user_input
        if [[ "$user_input" == "Y" || "$user_input" == "y" ]]; then
            echo
            echo "${BOLD}${CYAN}Great! Proceeding to the next steps...${RESET}"
            echo
            break
        elif [[ "$user_input" == "N" || "$user_input" == "n" ]]; then
            echo
            echo "${BOLD}${RED}Please check your progress up to Task 4 and then press Y to continue.${RESET}"
        else
            echo
            echo "${BOLD}${MAGENTA}Invalid input. Please enter Y or N.${RESET}"
        fi
    done
}

#----------------------------------------------------start--------------------------------------------------#

echo "${RANDOM_BG_COLOR}${RANDOM_TEXT_COLOR}${BOLD}Starting Execution${RESET}"

# Step 1: Setting the default zone
echo -e "${CYAN}${BOLD}Step 1: Setting the default zone...${RESET}"
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

# Step 2: Exporting the current IAM policy
echo -e "${MAGENTA}${BOLD}Step 2: Exporting the current IAM policy to policy.json...${RESET}"
gcloud projects get-iam-policy $DEVSHELL_PROJECT_ID \
--format=json >./policy.json

# Step 3: Updating the IAM policy to enable audit logging
echo -e "${BLUE}${BOLD}Step 3: Updating IAM policy to enable audit logging...${RESET}"
jq '.auditConfigs = [
  {
    "service": "allServices",
    "auditLogConfigs": [
      { "logType": "ADMIN_READ" },
      { "logType": "DATA_READ" },
      { "logType": "DATA_WRITE" }
    ]
  }
] | .' policy.json > updated_policy.json

# Step 4: Applying the updated IAM policy
echo -e "${GREEN}${BOLD}Step 4: Applying the updated IAM policy...${RESET}"
gcloud projects set-iam-policy $DEVSHELL_PROJECT_ID \
./updated_policy.json

# Step 5: Creating a BigQuery dataset for audit logs
echo -e "${YELLOW}${BOLD}Step 5: Creating a BigQuery dataset named 'auditlogs_dataset'...${RESET}"
bq --location=US mk --dataset $DEVSHELL_PROJECT_ID:auditlogs_dataset

# Step 6: Log console instructions
echo -e "${RED}${BOLD}Step 6: Visit the Logs Explorer in GCP Console...${RESET}"
echo
echo "Go to: https://console.cloud.google.com/logs/query"
echo
echo "Copy this filter: ""'logName = (\"projects/$DEVSHELL_PROJECT_ID/logs/cloudaudit.googleapis.com%2Factivity\")'"
echo
echo "SINK NAME: AuditLogsExport"
echo
# Call function to check progress before proceeding
check_progress

# Step 7: Setting up a Cloud Storage bucket
echo -e "${BLUE}${BOLD}Step 7: Creating a Cloud Storage bucket and uploading a sample file...${RESET}"
gsutil mb gs://$DEVSHELL_PROJECT_ID
echo "this is a sample file" > sample.txt
gsutil cp sample.txt gs://$DEVSHELL_PROJECT_ID

# Step 8: Creating a VPC network and VM instance
echo -e "${MAGENTA}${BOLD}Step 8: Creating a VPC network and VM instance...${RESET}"
gcloud compute networks create mynetwork --subnet-mode=auto
gcloud compute instances create default-us-vm \
--machine-type=e2-micro \
--zone="$ZONE" --network=mynetwork

# Step 9: Deleting the bucket and capturing logs
echo -e "${GREEN}${BOLD}Step 9: Deleting the bucket and capturing logs...${RESET}"
gsutil rm -r gs://$DEVSHELL_PROJECT_ID

gcloud logging read \
"logName=projects/$DEVSHELL_PROJECT_ID/logs/cloudaudit.googleapis.com%2Factivity \
AND protoPayload.serviceName=storage.googleapis.com \
AND protoPayload.methodName=storage.buckets.delete"

# Step 10: Creating and testing another bucket
echo -e "${YELLOW}${BOLD}Step 10: Creating and testing another bucket...${RESET}"
gsutil mb gs://$DEVSHELL_PROJECT_ID
gsutil mb gs://$DEVSHELL_PROJECT_ID-test
echo "this is another sample file" > sample2.txt
gsutil cp sample.txt gs://$DEVSHELL_PROJECT_ID-test

# Step 11: Deleting the VM instance and logging
echo -e "${RED}${BOLD}Step 11: Deleting the VM instance and logging...${RESET}"
gcloud compute instances delete --zone="$ZONE" \
--delete-disks=all default-us-vm --quiet

# Step 12: Deleting the bucket and capturing logs
echo -e "${GREEN}${BOLD}Step 9: Deleting the bucket and capturing logs...${RESET}"
gsutil rm -r gs://$DEVSHELL_PROJECT_ID
gsutil rm -r gs://$DEVSHELL_PROJECT_ID-test

# Step 13: Creating VM instance and capturing logs
echo -e "${MAGENTA}${BOLD}Step 8: Creating a VPC network and VM instance...${RESET}"
gcloud compute instances create default-us-vm \
--zone="$ZONE" --network=mynetwork
gcloud compute instances delete --zone="$ZONE" \
--delete-disks=all default-us-vm --quiet

# Step 14: BigQuery query for instance deletion logs
echo -e "${CYAN}${BOLD}Step 12: Querying BigQuery for instance deletion logs...${RESET}"
bq query --nouse_legacy_sql --project_id=$DEVSHELL_PROJECT_ID '
SELECT
  timestamp,
  resource.labels.instance_id,
  protopayload_auditlog.authenticationInfo.principalEmail,
  protopayload_auditlog.resourceName,
  protopayload_auditlog.methodName
FROM
  `auditlogs_dataset.cloudaudit_googleapis_com_activity_*`
WHERE
  PARSE_DATE("%Y%m%d", _TABLE_SUFFIX) BETWEEN
  DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND
  CURRENT_DATE()
  AND resource.type = "gce_instance"
  AND operation.first IS TRUE
  AND protopayload_auditlog.methodName = "v1.compute.instances.delete"
ORDER BY
  timestamp,
  resource.labels.instance_id
LIMIT
  1000'

# Step 15: BigQuery query for bucket deletion logs
echo -e "${BLUE}${BOLD}Step 13: Querying BigQuery for bucket deletion logs...${RESET}"
bq query --nouse_legacy_sql --project_id=$DEVSHELL_PROJECT_ID '
SELECT
  timestamp,
  resource.labels.bucket_name,
  protopayload_auditlog.authenticationInfo.principalEmail,
  protopayload_auditlog.resourceName,
  protopayload_auditlog.methodName
FROM
  `auditlogs_dataset.cloudaudit_googleapis_com_activity_*`
WHERE
  PARSE_DATE("%Y%m%d", _TABLE_SUFFIX) BETWEEN
  DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND
  CURRENT_DATE()
  AND resource.type = "gcs_bucket"
  AND protopayload_auditlog.methodName = "storage.buckets.delete"
ORDER BY
  timestamp,
  resource.labels.bucket_name
LIMIT
  1000'

echo

# Function to display a random congratulatory message
function random_congrats() {
    MESSAGES=(
        "${GREEN}Congratulations For Completing The Lab! Keep up the great work!${RESET}"
        "${CYAN}Well done! Your hard work and effort have paid off!${RESET}"
        "${YELLOW}Amazing job! You’ve successfully completed the lab!${RESET}"
        "${BLUE}Outstanding! Your dedication has brought you success!${RESET}"
        "${MAGENTA}Great work! You’re one step closer to mastering this!${RESET}"
        "${RED}Fantastic effort! You’ve earned this achievement!${RESET}"
        "${CYAN}Congratulations! Your persistence has paid off brilliantly!${RESET}"
        "${GREEN}Bravo! You’ve completed the lab with flying colors!${RESET}"
        "${YELLOW}Excellent job! Your commitment is inspiring!${RESET}"
        "${BLUE}You did it! Keep striving for more successes like this!${RESET}"
        "${MAGENTA}Kudos! Your hard work has turned into a great accomplishment!${RESET}"
        "${RED}You’ve smashed it! Completing this lab shows your dedication!${RESET}"
        "${CYAN}Impressive work! You’re making great strides!${RESET}"
        "${GREEN}Well done! This is a big step towards mastering the topic!${RESET}"
        "${YELLOW}You nailed it! Every step you took led you to success!${RESET}"
        "${BLUE}Exceptional work! Keep this momentum going!${RESET}"
        "${MAGENTA}Fantastic! You’ve achieved something great today!${RESET}"
        "${RED}Incredible job! Your determination is truly inspiring!${RESET}"
        "${CYAN}Well deserved! Your effort has truly paid off!${RESET}"
        "${GREEN}You’ve got this! Every step was a success!${RESET}"
        "${YELLOW}Nice work! Your focus and effort are shining through!${RESET}"
        "${BLUE}Superb performance! You’re truly making progress!${RESET}"
        "${MAGENTA}Top-notch! Your skill and dedication are paying off!${RESET}"
        "${RED}Mission accomplished! This success is a reflection of your hard work!${RESET}"
        "${CYAN}You crushed it! Keep pushing towards your goals!${RESET}"
        "${GREEN}You did a great job! Stay motivated and keep learning!${RESET}"
        "${YELLOW}Well executed! You’ve made excellent progress today!${RESET}"
        "${BLUE}Remarkable! You’re on your way to becoming an expert!${RESET}"
        "${MAGENTA}Keep it up! Your persistence is showing impressive results!${RESET}"
        "${RED}This is just the beginning! Your hard work will take you far!${RESET}"
        "${CYAN}Terrific work! Your efforts are paying off in a big way!${RESET}"
        "${GREEN}You’ve made it! This achievement is a testament to your effort!${RESET}"
        "${YELLOW}Excellent execution! You’re well on your way to mastering the subject!${RESET}"
        "${BLUE}Wonderful job! Your hard work has definitely paid off!${RESET}"
        "${MAGENTA}You’re amazing! Keep up the awesome work!${RESET}"
        "${RED}What an achievement! Your perseverance is truly admirable!${RESET}"
        "${CYAN}Incredible effort! This is a huge milestone for you!${RESET}"
        "${GREEN}Awesome! You’ve done something incredible today!${RESET}"
        "${YELLOW}Great job! Keep up the excellent work and aim higher!${RESET}"
        "${BLUE}You’ve succeeded! Your dedication is your superpower!${RESET}"
        "${MAGENTA}Congratulations! Your hard work has brought great results!${RESET}"
        "${RED}Fantastic work! You’ve taken a huge leap forward today!${RESET}"
        "${CYAN}You’re on fire! Keep up the great work!${RESET}"
        "${GREEN}Well deserved! Your efforts have led to success!${RESET}"
        "${YELLOW}Incredible! You’ve achieved something special!${RESET}"
        "${BLUE}Outstanding performance! You’re truly excelling!${RESET}"
        "${MAGENTA}Terrific achievement! Keep building on this success!${RESET}"
        "${RED}Bravo! You’ve completed the lab with excellence!${RESET}"
        "${CYAN}Superb job! You’ve shown remarkable focus and effort!${RESET}"
        "${GREEN}Amazing work! You’re making impressive progress!${RESET}"
        "${YELLOW}You nailed it again! Your consistency is paying off!${RESET}"
        "${BLUE}Incredible dedication! Keep pushing forward!${RESET}"
        "${MAGENTA}Excellent work! Your success today is well earned!${RESET}"
        "${RED}You’ve made it! This is a well-deserved victory!${RESET}"
        "${CYAN}Wonderful job! Your passion and hard work are shining through!${RESET}"
        "${GREEN}You’ve done it! Keep up the hard work and success will follow!${RESET}"
        "${YELLOW}Great execution! You’re truly mastering this!${RESET}"
        "${BLUE}Impressive! This is just the beginning of your journey!${RESET}"
        "${MAGENTA}You’ve achieved something great today! Keep it up!${RESET}"
        "${RED}You’ve made remarkable progress! This is just the start!${RESET}"
    )

    RANDOM_INDEX=$((RANDOM % ${#MESSAGES[@]}))
    echo -e "${BOLD}${MESSAGES[$RANDOM_INDEX]}"
}

# Display a random congratulatory message
random_congrats

echo -e "\n"  # Adding one blank line

cd

remove_files() {
    # Loop through all files in the current directory
    for file in *; do
        # Check if the file name starts with "gsp", "arc", or "shell"
        if [[ "$file" == gsp* || "$file" == arc* || "$file" == shell* ]]; then
            # Check if it's a regular file (not a directory)
            if [[ -f "$file" ]]; then
                # Remove the file and echo the file name
                rm "$file"
                echo "File removed: $file"
            fi
        fi
    done
}

remove_files