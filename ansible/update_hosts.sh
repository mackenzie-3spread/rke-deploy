#!/bin/bash

# Define the path to your inventory.ini file
INVENTORY_FILE="./inventory.ini"
HOSTS_FILE="/etc/hosts"

# Temporary file to store the updated /etc/hosts content
TEMP_FILE=$(mktemp)

# Copy the first 9 lines of /etc/hosts into the temp file
head -n 9 "$HOSTS_FILE" > "$TEMP_FILE"

# Debug: Print current status
echo "Copied the first 9 lines of /etc/hosts to the temporary file."

# Loop through each line in the inventory file
while IFS= read -r line; do
    # Debug: Print current line being processed
    echo "Processing line: $line"

    # Skip empty lines or lines starting with a bracket
    [[ -z "$line" || "$line" == "["* ]] && continue

    # Extract the hostname and IP address using regex
    if [[ "$line" =~ ^([a-zA-Z0-9._-]+)[[:space:]]+ansible_host=([0-9.]+)[[:space:]]*ansible_user=([a-zA-Z0-9._-]+) ]]; then
        HOSTNAME=${BASH_REMATCH[1]}
        IP=${BASH_REMATCH[2]}
        
        # Debug: Print extracted hostname and IP
        echo "Extracted HOSTNAME: $HOSTNAME, IP: $IP"

        # Check if the hostname is already in the file
        if ! grep -q "$HOSTNAME.local" "$TEMP_FILE"; then
            # Add the new hostname and IP
            echo "$IP $HOSTNAME.local" >> "$TEMP_FILE"
            # Debug: Print added entry
            echo "Added entry: $IP $HOSTNAME.local"
        fi
    else
        # Debug: Print if line does not match expected format
        echo "Line did not match expected format: $line"
    fi
done < "$INVENTORY_FILE"

# Overwrite /etc/hosts with the new content
sudo mv "$TEMP_FILE" "$HOSTS_FILE"

# Debug: Print completion message
echo "Hosts have been added to /etc/hosts."
