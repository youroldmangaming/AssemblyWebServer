# Install necessary tools
sudo apt update
sudo apt install build-essential

# Save your assembly code to a file named webserver.s
# (You can use nano or any text editor to do this)
nano server.s

# Assemble the code
as -o server.o server.s

# Link the object file to create an executable
ld -o server server.o

# Run the server
sudo ./server
