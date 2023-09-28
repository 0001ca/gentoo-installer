#!/bin/bash

# Function to compile the Gentoo world set
compile_world() {
    emerge --update --deep --newuse @world
}

# Function to compile the Gentoo system set
compile_system() {
    emerge --update --deep --newuse @system
}

# Function to compile the Gentoo world set but skip-first package
compile_world_skipfirst() {
    emerge --update --deep --newuse --skip-first @world 2>&1
}

# Function to perform the compilation and retries
perform_compilation() {
    # Maximum number of retry attempts for compile_world_skipfirst
    max_retries=3
    retry_count=0

    # Compile the system set
    compile_system

    # Check if the system compilation was successful
    if [ $? -eq 0 ]; then
        echo "System compilation successful"
        # Compile the world set
        compile_world
        # Check if the world compilation was successful
        if [ $? -eq 0 ]; then
            echo "World compilation successful"
            exit 0
        else
            echo "World compilation failed, retrying with skip-first..."
            # Retry world compilation with skip-first up to max_retries times
            while [ $retry_count -lt $max_retries ]; do
                compile_world_skipfirst
                # Check if the retry was successful
                if [ $? -eq 0 ]; then
                    echo "World compilation successful after retry"
                    exit 0
                else
                    echo "World compilation failed (Retry $((retry_count + 1)) of $max_retries)"
                    retry_count=$((retry_count + 1))
                fi
            done
            echo "World compilation failed even after $max_retries retries"
            exit 1
        fi
    else
        echo "System compilation failed"
        exit 1
    fi
}

# Call the function to perform the compilation and retries
perform_compilation

