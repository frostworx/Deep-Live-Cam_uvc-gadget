#!/usr/bin/python3
import os
import cv2
import socket
import pickle
import struct
import v4l2
import fcntl

# ugly frankensteined pseudocode to receive video packets from a socket and squeeze them into a v4l2loopback device
# change at least 'DEEPSRV' to match your Deep-Live-Cam server ip

DEEPRUN = "/tmp/deep.txt"
DEEPSRV = '192.168.1.111'
DEEPORT = 9999

# Create a socket client
video_client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
video_client_socket.connect((DEEPSRV, DEEPORT))  # Replace with the server’s IP address

received_data = b""
payload_size = struct.calcsize("L")

width = 640
height = 480
channels = 3
devName = "/dev/video23"
device = open(devName, 'wb', 0)

print ("Info: opened video device ",devName)

#Set up the formatting of our loopback device - boilerplate
format                      = v4l2.v4l2_format()
format.type                 = v4l2.V4L2_BUF_TYPE_VIDEO_OUTPUT
format.fmt.pix.field        = v4l2.V4L2_FIELD_NONE
format.fmt.pix.pixelformat  = v4l2.V4L2_PIX_FMT_BGR24
format.fmt.pix.width        = width
format.fmt.pix.height       = height
format.fmt.pix.bytesperline = width * channels
format.fmt.pix.sizeimage    = width * height * channels

running = 0

print ("set format result (0 is good):{}".format(fcntl.ioctl(device, v4l2.VIDIOC_S_FMT, format)))
print("begin loopback write")

if os.path.exists(DEEPRUN):
    os.remove(DEEPRUN)

while True:
    # Receive and assemble the data until the payload size is reached
    while len(received_data) < payload_size:
        received_data += video_client_socket.recv(4096)

    # Extract the packed message size
    packed_msg_size = received_data[:payload_size]
    received_data = received_data[payload_size:]
    msg_size = struct.unpack("L", packed_msg_size)[0]

    # Receive and assemble the frame data until the complete frame is received
    while len(received_data) < msg_size:
        received_data += video_client_socket.recv(4096)

    # Extract the frame data
    frame_data = received_data[:msg_size]
    received_data = received_data[msg_size:]

    # Deserialize the received frame
    received_frame = pickle.loads(frame_data)

    # send frame to v4l2loopback device
    device.write(received_frame)

    # the follow up ffmpeg command is ready to start when this file exists
    if not os.path.exists(DEEPRUN) and running == 0:
        with open(DEEPRUN, 'w'): pass
        running = 1

    # when this file is gone, the program exits (and ffmpeg as well)
    if not os.path.exists(DEEPRUN) and running == 1:
        break

    # Press ‘q’ to quit
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

# Release resources
cv2.destroyAllWindows()
video_client_socket.close()
