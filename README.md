# Web Server Assembly Project

This project implements a simple web server in ARM assembly language, designed to run on a Raspberry Pi. The server handles HTTP requests and responds with predefined messages based on the requested URL.

## Features

- Responds to HTTP GET requests for specific URLs (`/urmom` and `/urdad`).
- Returns appropriate HTTP status codes:
  - **413 Entity Too Large** for `/urmom`
  - **410 Gone** for `/urdad`
  - **405 Method Not Allowed** for any other requests
- Logs incoming requests and server status messages to the console.

## Requirements

- Raspberry Pi (or any ARM-based architecture)
- GCC and Binutils installed for assembling and linking the code

## Installation

1. **Install Required Tools**:
   Make sure you have the necessary development tools installed on your Raspberry Pi. You can do this by running:

   ```bash
   sudo apt update
   sudo apt install build-essential
