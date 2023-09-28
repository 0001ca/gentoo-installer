#!/bin/bash
#
# Reads saved_packages.txt and pulls the live system flags
# Writes to /etc/portage/package.use/custom
#
# Depends on running this on the system you want to copy
# gentoo-generate-package-use.sh --> rename the installed_packages.txt to saved_packages.txt
# Then run this script on the system you want to install i.e. the new stage3 chroot
#
# Define the output file for the package.use file
OUTPUT_FILE="/etc/portage/package.use/custom"

# Ensure the output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Check if the saved_packages.txt file exists
SAVED_PACKAGES_FILE="saved_packages.txt"

if [ ! -f "$SAVED_PACKAGES_FILE" ]; then
  echo "Error: The 'saved_packages.txt' file does not exist."
  exit 1
fi

# Create an array to store the list of installed packages from saved_packages.txt
installed_packages=($(cat "$SAVED_PACKAGES_FILE"))

# Remove the OUTPUT_FILE
rm "$OUTPUT_FILE"

# Loop through the installed packages and their USE flags
for package in "${installed_packages[@]}"; do
    # Strip the version number from the package name
    stripped_package=$(echo "$package" | sed 's/-[0-9].*//')

    # Get the list of USE flags enabled for the package
    flags=$(equery uses "$stripped_package" | tr '\n' ' ')

    # Remove the '+' sign from USE flags
    flags=$(echo "$flags" | sed 's/+//g')

    # Output the package and its USE flags to the package.use file
    echo "$stripped_package $flags" >> "$OUTPUT_FILE"
    echo "Added $stripped_package $flags to $OUTPUT_FILE"
done

# Inform the user about the generated package.use file
echo "Package USE flags have been written to $OUTPUT_FILE"

# You can edit the file to customize USE flags as needed
echo "You can edit the file to customize USE flags as needed."
