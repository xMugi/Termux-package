#!/data/data/com.termux/files/usr/bin/bash

# Check if we are already inside the 'metasploit' directory
if [ "${PWD##*/}" = "metasploit" ]; then
    echo "Already inside the 'metasploit' directory."
else
    # Check if the 'metasploit' directory exists
    if [ ! -d "metasploit" ]; then
        # Create the 'metasploit' directory
        mkdir metasploit
        echo "Directory 'metasploit' created."
    fi
    # Change to the 'metasploit' directory
    cd metasploit
    echo "Changed to the 'metasploit' directory."
fi

# Download the Metasploit script
wget https://github.com/gushmazuko/metasploit_in_termux/raw/master/metasploit.sh

# Make the script executable
chmod +x metasploit.sh

# Run the script
./metasploit.sh
