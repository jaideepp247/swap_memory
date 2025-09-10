#!/bin/bash

# Function to display usage information
usage() {
  echo "This script helps you add swap memory to your system."
  echo "It will prompt you for the amount of swap memory you want to add."
  echo "The script will automatically check if you already have sufficient swap."
  echo "If not, it will create the swap file of the requested size."
  exit 1
}

# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run the script as root or with sudo."
  exit 2
fi

# Function to check existing swap and memory info
check_swap() {
  total_swap=$(free -h | grep Swap | awk '{print $2}')
  total_memory=$(free -h | grep Mem | awk '{print $2}')

  if [ -z "$total_swap" ]; then
    echo "Error: Unable to retrieve swap information."
    exit 3
  fi

  # Output the current swap usage and total swap
  echo "Current swap size: $total_swap"
  echo "Total system memory: $total_memory"
}

# Check if swap is already present and sufficient
check_swap

# Prompt user for the size of swap memory to add
echo -n "Enter the amount of swap memory to add (in GB): "
read SWAP_SIZE

# Validate if the input is a number
if ! [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then
  echo "Error: Please enter a valid number for the swap size."
  exit 4
fi

# Check if the system already has enough swap
existing_swap_size=$(free -m | grep Swap | awk '{print $2}')
required_swap_size=$((SWAP_SIZE * 1024))  # Convert GB to MB for comparison

if [ "$existing_swap_size" -ge "$required_swap_size" ]; then
  echo "Your system already has enough swap space ($existing_swap_size MB). No need to add more."
  exit 0
fi

# Define swap file location
SWAP_FILE="/swapfile"

# Create swap file of the requested size
echo "Creating a $SWAP_SIZE GB swap file..."

# Use fallocate to create the swap file. If it fails, fallback to dd
sudo fallocate -l ${SWAP_SIZE}G $SWAP_FILE

# If fallocate fails, use dd instead (for systems where fallocate isn't supported)
if [ $? -ne 0 ]; then
  echo "Fallocate failed, using dd to create swap file..."
  sudo dd if=/dev/zero of=$SWAP_FILE bs=1M count=$(($SWAP_SIZE * 1024)) status=progress
fi

# Set correct permissions for the swap file
sudo chmod 600 $SWAP_FILE

# Set up the swap space
sudo mkswap $SWAP_FILE

# Enable the swap
sudo swapon $SWAP_FILE

# Verify the swap is active
sudo swapon --show

# Make the swap change persistent by adding to /etc/fstab
if ! grep -q "$SWAP_FILE" /etc/fstab; then
  echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab
  echo "Swap file added to /etc/fstab for persistence."
fi

echo "Swap file of ${SWAP_SIZE}GB has been created and enabled!"
