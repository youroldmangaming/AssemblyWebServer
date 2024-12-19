.section __TEXT,__const
# Define HTTP response messages
mom_response:
    .ascii "HTTP/1.1 413 Entity Too Large\r\n"  # Response status line
    .ascii "Content-Type: text/plain\r\n"        # Content type header
    .ascii "Content-Length: 43\r\n"              # Content length header
    .ascii "\r\n"                                 # End of headers
    .ascii "Honey, mama is busy right now. Ask your dad."  # Response body
mom_response_len = . - mom_response              # Calculate length of mom_response

dad_response:
    .ascii "HTTP/1.1 410 Gone\r\n"                # Response status line
    .ascii "Content-Type: text/plain\r\n"        # Content type header
    .ascii "Content-Length: 36\r\n"              # Content length header
    .ascii "\r\n"                                 # End of headers
    .ascii "I'll buy some milk and get back soon" # Response body
dad_response_len = . - dad_response              # Calculate length of dad_response

default_response:
    .ascii "HTTP/1.1 405 Method Not Allowed\r\n" # Response status line
    .ascii "Content-Type: text/plain\r\n"        # Content type header
    .ascii "Content-Length: 29\r\n"              # Content length header
    .ascii "Allow: GET\r\n"                       # Allowed methods header
    .ascii "\r\n"                                 # End of headers
    .ascii "Method is not allowed for URL"       # Response body
default_response_len = . - default_response      # Calculate length of default_response

# Define URL paths for requests
mom_url: .asciz "GET /urmom"                    # URL for mom's response
dad_url: .asciz "GET /urdad"                    # URL for dad's response

# Define messages for server status
start_msg: .asciz "Server starting on port %d...\n"  # Server start message
listen_msg: .asciz "Server is listening...\n"          # Listening message
listen_msg_len = . - listen_msg                       # Calculate length of listen_msg
close_msg: .asciz "Connection closed\n"               # Connection closed message
close_msg_len = . - close_msg                         # Calculate length of close_msg
error_msg: .asciz "Error occurred!\n"                 # Error message
error_msg_len = . - error_msg                         # Calculate length of error_msg

.section __DATA,__data
.align 4
.globl _sockaddr
_sockaddr:
    .short AF_INET                                   # Address family (IPv4)
    .short 0                                         # Port (will be set later)
    .long 0                                          # IP address (will be set later)
_reuseaddr:
    .word 1                                         # Set SO_REUSEADDR option

.section __TEXT,__text
.globl _main
.align 2
.equ SOCK_STREAM, 1                                 # Define constant for TCP socket
.equ AF_INET, 2                                     # Define constant for IPv4
.equ SOL_SOCKET, 0xffff                             # Define constant for socket level
.equ SO_REUSEADDR, 0x4                              # Define constant for socket option
.equ HTTP_PORT, 6969                                # Define HTTP port number

# Print syscall function
print: 
    mov x2, x1                                       # Move message length to x2
    mov x1, x0                                       # Move message address to x1
    mov x0, #1                                       # Set file descriptor 1 (stdout)
    mov x16, #4                                      # Set syscall number for write
    svc #0x80                                         # Make syscall
    ret                                               # Return from function

_main:
    sub sp, sp, #16                                  # Allocate space on stack for printf
    mov x8, HTTP_PORT                                 # Load HTTP port number into x8
    str x8, [sp]                                     # Store port number on stack
    adrp x0, start_msg@PAGE                          # Load address of start_msg
    add x0, x0, start_msg@PAGEOFF                    # Add offset to get full address
    bl _printf                                        # Call printf to display start message
    add sp, sp, #16                                   # Restore stack pointer

    mov w0, HTTP_PORT                                 # Move port number to w0
    bl _htons                                         # Convert port number to network byte order
    adrp x1, _sockaddr@PAGE                          # Load address of sockaddr structure
    add x1, x1, _sockaddr@PAGEOFF                    # Add offset to get full address
    strh w0, [x1, #2]                                # Store port number in sockaddr structure

    mov x0, AF_INET                                   # Set address family to AF_INET
    mov x1, SOCK_STREAM                               # Set socket type to SOCK_STREAM
    mov x2, #0                                        # Set protocol to 0 (default)
    mov x16, #97                                      # Set syscall number for socket
    svc #0x80                                         # Make syscall

    cmp x0, #0                                       # Check for socket creation error
    b.lt print_error                                  # Branch to print_error if less than zero
    mov x19, x0                                      # Save socket descriptor in x19

    mov x1, SOL_SOCKET                                # Set socket level to SOL_SOCKET
    mov x2, SO_REUSEADDR                              # Set option to SO_REUSEADDR
    adrp x3, _reuseaddr@GOTPAGE                      # Load address of reuseaddr
    ldr x3, [x3, _reuseaddr@GOTPAGEOFF]             # Load value of reuseaddr
    mov x4, #4                                       # Set option length
    mov x16, #105                                     # Set syscall number for setsockopt
    svc #0x80                                         # Make syscall

    mov x0, x19                                      # Move socket descriptor to x0
    adrp x1, _sockaddr@GOTPAGE                       # Load address of sockaddr
    ldr x1, [x1, _sockaddr@GOTPAGEOFF]              # Load sockaddr structure
    mov x2, #16                                      # Set size of sockaddr
    mov x16, #104                                     # Set syscall number for bind
    svc #0x80                                         # Make syscall

    cmp x0, #0                                       # Check for bind error
    b.lt print_error                                  # Branch to print_error if less than zero

    mov x0, x19                                      # Move socket descriptor to x0
    mov x1, #5                                       # Set backlog for listen
    mov x16, #106                                     # Set syscall number for listen
    svc #0x80                                         # Make syscall

    cmp x0, #0                                       # Check for listen error
    b.lt print_error                                  # Branch to print_error if less than zero

    adrp x0, listen_msg@PAGE                         # Load address of listen_msg
    add x0, x0, listen_msg@PAGEOFF                   # Add offset to get full address
    mov x1, listen_msg_len                           # Load length of listen_msg
    bl print                                          # Call print function

request_loop:                                         # Loop to accept connections
    mov x0, x19                                      # Move socket descriptor to x0
    mov x1, #0                                       # Set flags to 0
    mov x2, #0                                       # Set address length to 0
    mov x16, #30                                     # Set syscall number for accept
    svc #0x80                                         # Make syscall

    cmp x0, #0                                       # Check accept error
    b.lt request_loop                                 # If less than zero, loop again
    mov x20, x0                                      # Save client socket descriptor in x20

    # Read request
    sub sp, sp, #1024                                # Allocate buffer on stack
    mov x1, sp                                       # Move buffer address to x1
    mov x2, #1024                                    # Set buffer size
    mov x16, #3                                      # Set syscall number for read
    svc #0x80                                         # Make syscall

    # Print request
    mov x1, x0                                       # Move read length to x1
    mov x0, sp                                       # Move buffer address to x0
    bl print                                          # Call print function

    mov x0, sp                                       # Check for /urmom URL
    adrp x1, mom_url@PAGE                            # Load address of mom_url
    add x1, x1, mom_url@PAGEOFF                      # Add offset to get full address
    bl _strstr                                       # Call strstr to check for substring
    cmp x0, #0                                       # Check if found
    b.ne load_mom_response                           # If not equal to zero, load mom response

    mov x0, sp                                       # Check for /urdad URL
    adrp x1, dad_url@PAGE                            # Load address of dad_url
    add x1, x1, dad_url@PAGEOFF                      # Add offset to get full address
    bl _strstr                                       # Call strstr to check for substring
    cmp x0, #0                                       # Check if found
    b.ne load_dad_response                           # If not equal to zero, load dad response

    b load_default_response                           # Load default response

load_mom_response:
    adrp x21, mom_response@PAGE                      # Load address of mom_response
    add x21, x21, mom_response@PAGEOFF               # Add offset to get full address
    mov x22, mom_response_len                         # Load length of mom_response
    b send_response                                   # Send response

load_dad_response:
    adrp x21, dad_response@PAGE                      # Load address of dad_response
    add x21, x21, dad_response@PAGEOFF               # Add offset to get full address
    mov x22, dad_response_len                         # Load length of dad_response
    b send_response                                   # Send response

load_default_response:
    adrp x21, default_response@PAGE                  # Load address of default_response
    add x21, x21, default_response@PAGEOFF           # Add offset to get full address
    mov x22, default_response_len                     # Load length of default_response
    b send_response                                   # Send response

send_response:
    mov x0, x20                                      # Move client socket descriptor to x0
    mov x1, x21                                      # Move response address to x1
    mov x2, x22                                      # Move response length to x2
    mov x16, #4                                      # Set syscall number for write
    svc #0x80                                         # Make syscall

    mov x0, x20                                      # Move client socket descriptor to x0
    mov x16, #6                                      # Set syscall number for close
    svc #0x80                                         # Make syscall

    adrp x0, close_msg@PAGE                          # Load address of close_msg
    add x0, x0, close_msg@PAGEOFF                    # Add offset to get full address
    mov x1, close_msg_len                            # Load length of close_msg
    bl print                                          # Call print function

    add sp, sp, #1024                                # Deallocate buffer from stack
    b request_loop                                    # Loop back to request handling

print_error:
    adrp x0, error_msg@PAGE                          # Load address of error_msg
    add x0, x0, error_msg@PAGEOFF                    # Add offset to get full address
    mov x1, error_msg_len                            # Load length of error_msg
    bl print                                          # Call print function
    b request_loop                                    # Loop back to request handling
