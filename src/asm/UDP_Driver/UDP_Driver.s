.include "linux/sys.h"

.include "syscalls.h"
.include "netdevice.h"
.include "skbuff.h"
.include "udp.h"


.section .text

li s11, 0 # Device counter, used as name



# Network device struct, size 18 bytes
net_device:
  .byte 0 # name (0)
  .word 0 # state (1)
  .word 0 # next - Pointer to the next device in a linked list (5)
  .word 0 # dev_addr - MAC address (9)
  .word 0 # base_addr - address for I/O memory (13)
  .byte 0 # iqr - interrupt number (17)



# Socket buffer struct, size 36 bytes 
sk_buff:
  .word 0 # Data (0)
  .word 0 # Len (4)
  .word 0 # dev, Pointer to net_device that is using this buffer (8)
  .word 0 # head (12)
  .word 0 # tail (16)
  .word 0 # Dest IP (20)
  .word 0 # Source IP (24)
  .word 0 # Dest Port (28)
  .word 0 # Source Port (32)


# Define the open function ptr to device is in a0
open:
    # Allocate space for the net_device structure
    li a1, 18 # the number of bytes in a net_device
    li a7, 222 # SYS_call for mmap
    ecall
    mv 13(sp), a0 # Loads base_addr

    # Request resources for the device base_addr

    lw t0, 13(sp) # stores base_addr in t0
    li a7, request_region
    ecall

    
    # Initialize the net_device structure
    la t0, net_device # Init
    sw s11, 0(t0) # store name
    addi s11, s11, 1 # Increase device counter

    li t1, 1 # State place holder
    sw t1, 1(t0) # store state

    ### Put in next ptr in t1 ###
    sw t1, 5(t0)

    ### Get MAC addr, can't find SYScall, load into t1 ###
    sw t1, 9(t0)


    ### Get IQR in t1 ###
    sw t1, 17(t0)

    
    



# Define the close function
close:
    mv a0, t0 # copies device into t0
    # Free the resources allocated in the open function
    ##### free_iqr syscall in a7
    lw a0, 17(t0)     # Set the interrupt number to free
    li a1, 0                # Set the data to pass to the free_irq function
    ecall                   # Call the free_irq system call to free the interrupt

    li a7, 215      # Set the system call number for munmap
    la a0, 13(t0)        # Set the address of the base address to unmap
    li a1, DEVICE_SIZE      # Set the length of the memory region to unmap
    ecall                   # Call the iounmap system call to unmap the memory region
    
    # Clear the device structure
    la a0, t0            # Load the address of the device structure
    li a1, DEVICE_SIZE       # Load the size of the device structure
    li a2, 0                 # Set the value to clear the memory to
    ecall                    # Call the memset system call to clear the device structure
    



# Define the transmit function
tx:
    # Load the packet length and data address from the skb
    lw t0, a0     # Load the address of the skb from the stack
    lw t1, 16(t0)    # Load the address of the packet data from the skb
    lw t2, 20(t0)    # Load the length of the packet data from the skb

    
    # Prepare the destination socket address
    la t3, 20(t0)  # Load the address of the destination socket structure
    lw t4, AF_INET      # Load the address family (AF_INET for IPv4)
    lw t5, 28(t3)      # Load the destination port
    lw t6, 32(t3)      # Load the source port
    addi sp, sp, -16   # Allocate space on the stack for the sockaddr_in structure
    sw t4, 0(sp)      # Store the address family in the sockaddr_in structure
    sw t5, 4(sp)      # Store the destination IP address in the sockaddr_in structure
    sw t6, 8(sp)      # Store the destination port number in the sockaddr_in structure
    sw zero, 12(sp)   # Set the remaining fields of the sockaddr_in structure to zero
    la a4, (sp)       # Set the address of the sockaddr_in structure as the destination address
    li a5, 16         # Set the length of the sockaddr_in structure
    
    # Init and bind socket
    li a7, 198     # Set the system call number for socket
    li a0, AF_INET        # Set the address family to AF_INET (IPv4)
    li a1, SOCK_DGRAM    # Set the socket type to SOCK_DGRAM (UDP)
    li a2, IPPROTO_UDP    # Set the protocol to IPPROTO_UDP (UDP)
    ecall                 # Call the socket system call to create a UDP socket

    mv s0, a0  #Save the socket file descriptor
    li a7, 200       # Set the system call number for bind
    la a1, t1             # Set the address of the sockaddr_in structure as the bind address
    li a2, 16             # Set the length of the sockaddr_in structure
    ecall                 # Call the bind system call to bind the socket to a specific address


    mv a0, t0         # Save the socket file descriptor for future use
    li a7, 206     # Set the system call number for sendto
    la a1, t1             # Set the buffer address to the packet data
    mv a2, t2           # Set the buffer size to the packet length
    li a3, 0             # Set the flags to zero (no special behavior)
    la a4, (sp)           # Set the address of the destination sockaddr_in structure
    li a5, 16             # Set the length of the destination sockaddr_in structure
    ecall                 # Call the sendto system call to transmit the packet
    
    # Free the skb
    li a7, 215  # Set the system call number for munmap
    la a0, t1          # Set the address of the buffer to free
    mv a1, t2        # Set the length
    ecall





# Define the receive function
rx:
    # Allocate space on the stack for the receive buffer and sockaddr_in structure
    addi sp, sp, -32   # Allocate 32 bytes for the receive buffer and sockaddr_in structure
    la t0, (sp)        # Load the address of the receive buffer into t0
    addi t1, t0, 16    # Calculate the address of the sockaddr_in structure as the receive buffer + 16
    
    # Init and bind socket
    li a7, 198     # Set the system call number for socket
    li a0, AF_INET        # Set the address family to AF_INET (IPv4)
    li a1, SOCK_DGRAM    # Set the socket type to SOCK_DGRAM (UDP)
    li a2, IPPROTO_UDP    # Set the protocol to IPPROTO_UDP (UDP)
    ecall                 # Call the socket system call to create a UDP socket

    mv s0, a0  #Save the socket file descriptor
    li a7, 200       # Set the system call number for bind
    la a1, t1             # Set the address of the sockaddr_in structure as the bind address
    li a2, 16             # Set the length of the sockaddr_in structure
    ecall                 # Call the bind system call to bind the socket to a specific address


    li a7, 207   # Set the system call number for recvfrom
    li a0, s0         # Set the file descriptor for the UDP socket
    la a1, t0             # Set the buffer address to the receive buffer
    li a2, 4096           # Set the buffer size to 4096 bytes (adjust as needed)
    li a3, 0              # Set the flags to zero (no special behavior)
    la a4, t1             # Set the address of the sockaddr_in structure for storing the source address
    la a5, 16             # Set the length of the sockaddr_in structure
    ecall                 # Call the recvfrom system call to receive a packet
    

    # Process Packet
    
    
    # Free the receive buffer and sockaddr_in structure
    addi sp, sp, 32    # Free the stack space allocated for the receive buffer and sockaddr_in structure
    
    # Return to the caller
    jr ra




