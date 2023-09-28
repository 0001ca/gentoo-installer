#!/bin/bash
#
# Pulls the live system for packages installed
# Writes /etc/portage/package.use/custom
# Writes installed_packages.txt
#
# Define the output file for the package.use file
OUTPUT_FILE="/etc/portage/package.use/custom"

# Remove the OUTPUT_FILE
rm /etc/portage/package.use/custom

# Ensure the output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Create an array to store the list of installed packages
installed_packages=($(equery list '*' | cut -f 1 -d " "))

# Loop through the installed packages and their USE flags
for package in "${installed_packages[@]}"; do
    # Get the list of USE flags enabled for the package
    flags=$(equery uses "$package" | tr '\n' ' ')

    # Remove the '+' sign from USE flags
    flags=$(echo "$flags" | sed 's/+//g')

    # Use sed to remove the version number (if present)
    stripped_package=$(echo "$package" | sed 's/-[0-9].*//')

    # Output the package and its USE flags to the package.use file
    echo "$stripped_package $flags" >> "$OUTPUT_FILE"
    echo "Added $stripped_package $flags to $OUTPUT_FILE"
done

# Inform the user about the generated package.use file
echo "Package USE flags have been written to $OUTPUT_FILE"

# You can edit the file to customize USE flags as needed
echo "You can edit the file to customize USE flags as needed."

# Output the list of installed packages to installed_packages.txt
#echo "List of installed packages:" > installed_packages.txt
for package in "${installed_packages[@]}"; do
    echo "$package" >> installed_packages.txt
done

# Inform the user about the generated installed_packages.txt file
echo "List of installed packages has been written to installed_packages.txt"
