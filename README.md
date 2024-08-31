![demo-gif](demo.gif)

## uvc-gadget README

### Dirty hack
This is a dirty and heavily unoptimized fork of https://github.com/hacksider/Deep-Live-Cam
with some lame hack and scripts which add uvc-gadget functionality to the project.
_(pretty sure upstream will have a rtps stream-out functionality soon, which will make the Deep-Live-Cam hack part of this project obsolete)_

*massive la, low fps, no audio...*

I doubt I will spend much time into polishing this and it is too fragile to get it merged into upstream.
You better should wait until someone provides a more straightforward solution - you have been warned :)
It works in my environment at least for some fun, ymmv.

### environment

Deep-Live-Cam is running on a headless pretty strong machine _(*AAA*)_ here. An usb cam is directly connected to it and uses the device node `/dev/video0`.

A separate device is used as uvc-gadget - I use a *rpi4*, which offers otg functionality through the usb-c port.
As the uvc-gadget is attached to a usb-hub which is switched between multiple machines, I use a usb-c splitter cable with pd and otg functionality
_(to keep power for the *rpi4* stable when switching the usb hub)_

_(not every computer has otg support! There is a `dummy_hcd` kernel module which emulates that function, but it seems like it is not uvc compatible)_

### workflow chain:

rpi4:

prepare two video4loopback devices:

```
modprobe v4l2loopback devices="2" video_nr="23,24" max_buffers="8" max_width="640" max_height="480"
v4l2loopback-ctl set-fps 30 /dev/video23
v4l2loopback-ctl set-fps 30 /dev/video24
```

prepare a usb gadget device
there are multiple scripts which could be used _(as an example [this](https://www.raspberrypi.com/tutorials/plug-and-play-raspberry-pi-usb-webcam/) one looks good)_
I successfully used `gadget-uvc` from the [libusbgx](https://github.com/linux-usb-gadgets/libusbgx) project instead

You should end up with a `/dev/video0` gadget device and two v4l2loopback devices:

```
v4l2-ctl --list-devices
fe980000.usb (gadget.0):
	/dev/video0

Dummy video device (0x0000) (platform:v4l2loopback-000):
	/dev/video23

Dummy video device (0x0001) (platform:v4l2loopback-001):
	/dev/video24
```

install ffmpeg, uvc-gadget (I used https://github.com/wlhe/uvc-gadget, but upstream - mentioned in the readme - very likely works as well),
copy 'get-deep-live-cam-stream.py' from this project to /usr/local/bin, adjust it to your needs, make sure the deps are installed and working _(v4l2, pickle)_

To activate your usb gadget the content of /sys/class/udc/ needs to be written to
/sys/kernel/config/usb_gadget/${YOURDEVICENAME}/UDC

your script/tool you use might have already done this for you (`gadget-uvc` did) - just cat the UDC file to find out - on my rpi4:

```
cat /sys/kernel/config/usb_gadget/g1/UDC 
fe980000.usb
```

AAA:

After selecting a face and clicking "Live", Deep-Live-Cam is opening a socket _(on port 9999)_ and is waiting for a client connection before it continues.

rpi4:


terminal 1:

`get-deep-live-cam-stream.py`

_(connects to the socket and streams the received Deep-Live-Cam modified frames into the v4l2loopback device /dev/video23)_

_(the script uses the python 'v4l2' module - it seems to be unmaintained for years and needed some minor manual edits to get it working)_

terminal 2:

`ffmpeg -i /dev/video23 -f v4l2 -vcodec rawvideo -pix_fmt yuyv422 /dev/video24`

_(converts the video format in /dev/video23 to a v4l/uvc gadget compatible format with the v4l2loopback device /dev/video24 as destination)_

terminal 3:

`uvc-gadget -f 0 -o 1 -r 0 -s 1 -v /dev/video24 -u /dev/video0`
_(writes the /dev/video24 video stream into the uvc gadget device /dev/video0, upstream uvc-gadget uses different command line parameters - those used work for me for now)_


*PROFIT*

when everything works as it should, the device, which has the usb-gadget attached now has a working usb webcam with the modified face
_(`1d6b:0104 Linux Foundation Multifunction Composite Gadget` when using `gadget-uvc`)_
Of course no special drivers are required on that device, just use any program which works with webcams.

exiting the program:
kill it with fire


### Deep-Live-Cam v4l2loopback video source 
side hint:

As an alternative to a physical webcam you could as well use any rtsp stream (of a network camera for example) as Deep-Live-Cam source and stream it to a v4l2loopback device.

```
SRC="rtsp://your.rtsp.source:8554/eugen"

if ! lsmod | grep -q v4l2loopback; then
  modprobe v4l2loopback devices="1" video_nr="0" max_buffers="8" max_width="640" max_height="480"
  v4l2loopback-ctl set-fps 25 /dev/video0
fi
ffmpeg -i ${SRC} -f v4l2 /dev/video0
```

# original Deep-Live-Cam readme starting here:


## Disclaimer
This software is meant to be a productive contribution to the rapidly growing AI-generated media industry. It will help artists with tasks such as animating a custom character or using the character as a model for clothing etc.

The developers of this software are aware of its possible unethical applications and are committed to take preventative measures against them. It has a built-in check which prevents the program from working on inappropriate media including but not limited to nudity, graphic content, sensitive material such as war footage etc. We will continue to develop this project in the positive direction while adhering to law and ethics. This project may be shut down or include watermarks on the output if requested by law.

Users of this software are expected to use this software responsibly while abiding by local laws. If the face of a real person is being used, users are required to get consent from the concerned person and clearly mention that it is a deepfake when posting content online. Developers of this software will not be responsible for actions of end-users.

## How do I install it?


### Basic: It is more likely to work on your computer but it will also be very slow. You can follow instructions for the basic install (This usually runs via **CPU**)
#### 1.Setup your platform
-   python (3.10 recommended)
-   pip
-   git
-   [ffmpeg](https://www.youtube.com/watch?v=OlNWCpFdVMA) 
-   [visual studio 2022 runtimes (windows)](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
#### 2. Clone Repository
    https://github.com/hacksider/Deep-Live-Cam.git

#### 3. Download Models

 1. [GFPGANv1.4](https://huggingface.co/hacksider/deep-live-cam/resolve/main/GFPGANv1.4.pth)
 2. [inswapper_128_fp16.onnx](https://huggingface.co/hacksider/deep-live-cam/resolve/main/inswapper_128_fp16.onnx)

Then put those 2 files on the "**models**" folder

#### 4. Install dependency
We highly recommend to work with a  `venv`  to avoid issues.
```
pip install -r requirements.txt
```
For MAC OS, You have to install or upgrade python-tk package:
```
brew install python-tk@3.10
```
##### DONE!!! If you dont have any GPU, You should be able to run roop using `python run.py` command. Keep in mind that while running the program for first time, it will download some models which can take time depending on your network connection.

### *Proceed if you want to use GPU Acceleration
### CUDA Execution Provider (Nvidia)*

1.  Install  [CUDA Toolkit 11.8](https://developer.nvidia.com/cuda-11-8-0-download-archive)
    
2.  Install dependencies:
    

```
pip uninstall onnxruntime onnxruntime-gpu
pip install onnxruntime-gpu==1.16.3

```

3.  Usage in case the provider is available:

```
python run.py --execution-provider cuda

```

### [](https://github.com/s0md3v/roop/wiki/2.-Acceleration#coreml-execution-provider-apple-silicon)CoreML Execution Provider (Apple Silicon)

1.  Install dependencies:

```
pip uninstall onnxruntime onnxruntime-silicon
pip install onnxruntime-silicon==1.13.1

```

2.  Usage in case the provider is available:

```
python run.py --execution-provider coreml

```

### [](https://github.com/s0md3v/roop/wiki/2.-Acceleration#coreml-execution-provider-apple-legacy)CoreML Execution Provider (Apple Legacy)

1.  Install dependencies:

```
pip uninstall onnxruntime onnxruntime-coreml
pip install onnxruntime-coreml==1.13.1

```

2.  Usage in case the provider is available:

```
python run.py --execution-provider coreml

```

### [](https://github.com/s0md3v/roop/wiki/2.-Acceleration#directml-execution-provider-windows)DirectML Execution Provider (Windows)

1.  Install dependencies:

```
pip uninstall onnxruntime onnxruntime-directml
pip install onnxruntime-directml==1.15.1

```

2.  Usage in case the provider is available:

```
python run.py --execution-provider directml

```

### [](https://github.com/s0md3v/roop/wiki/2.-Acceleration#openvino-execution-provider-intel)OpenVINO™ Execution Provider (Intel)

1.  Install dependencies:

```
pip uninstall onnxruntime onnxruntime-openvino
pip install onnxruntime-openvino==1.15.0

```

2.  Usage in case the provider is available:

```
python run.py --execution-provider openvino
```

## How do I use it?
> Note: When you run this program for the first time, it will download some models ~300MB in size.

Executing `python run.py` command will launch this window:
![gui-demo](instruction.png)

Choose a face (image with desired face) and the target image/video (image/video in which you want to replace the face) and click on `Start`. Open file explorer and navigate to the directory you select your output to be in. You will find a directory named `<video_title>` where you can see the frames being swapped in realtime. Once the processing is done, it will create the output file. That's it.

## For the webcam mode
Just follow the clicks on the screenshot
1. Select a face
2. Click live
3. Wait for a few seconds (it takes a longer time, usually 10 to 30 seconds before the preview shows up)

![demo-gif](demo.gif)

Just use your favorite screencapture to stream like OBS
> Note: In case you want to change your face, just select another picture, the preview mode will then restart (so just wait a bit).


Additional command line arguments are given below. To learn out what they do, check [this guide](https://github.com/s0md3v/roop/wiki/Advanced-Options).

```
options:
  -h, --help                                               show this help message and exit
  -s SOURCE_PATH, --source SOURCE_PATH                     select a source image
  -t TARGET_PATH, --target TARGET_PATH                     select a target image or video
  -o OUTPUT_PATH, --output OUTPUT_PATH                     select output file or directory
  --frame-processor FRAME_PROCESSOR [FRAME_PROCESSOR ...]  frame processors (choices: face_swapper, face_enhancer, ...)
  --keep-fps                                               keep original fps
  --keep-audio                                             keep original audio
  --keep-frames                                            keep temporary frames
  --many-faces                                             process every face
  --nsfw-filter                                            filter the NSFW image or video
  --video-encoder {libx264,libx265,libvpx-vp9}             adjust output video encoder
  --video-quality [0-51]                                   adjust output video quality
  --live-mirror                                            the live camera display as you see it in the front-facing camera frame
  --live-resizable                                         the live camera frame is resizable
  --max-memory MAX_MEMORY                                  maximum amount of RAM in GB
  --execution-provider {cpu} [{cpu} ...]                   available execution provider (choices: cpu, ...)
  --execution-threads EXECUTION_THREADS                    number of execution threads
  -v, --version                                            show program's version number and exit
```

Looking for a CLI mode? Using the -s/--source argument will make the run program in cli mode.

## Want the Next Update Now?
If you want the latest and greatest build, or want to see some new great features, go to our [experimental branch](https://github.com/hacksider/Deep-Live-Cam/tree/experimental) and experience what the contributors have given.

## TODO
- [ ] Support multiple faces feature
- [ ] Develop a version for web app/service
- [ ] UI/UX enhancements for desktop app
- [ ] Speed up model loading
- [ ] Speed up real-time face swapping

*Note: This is an open-source project, and we’re working on it in our free time. Therefore, features, replies, bug fixes, etc., might be delayed. We hope you understand. Thanks.*

## Credits

- [ffmpeg](https://ffmpeg.org/): for making video related operations easy
- [deepinsight](https://github.com/deepinsight): for their [insightface](https://github.com/deepinsight/insightface) project which provided a well-made library and models.
- [havok2-htwo](https://github.com/havok2-htwo) : for sharing the code for webcam
- [GosuDRM](https://github.com/GosuDRM/nsfw-roop) : for uncensoring roop
- [vic4key](https://github.com/vic4key) : For supporting/contributing on this project
- and [all developers](https://github.com/hacksider/Deep-Live-Cam/graphs/contributors) behind libraries used in this project.
- Foot Note: [This is originally roop-cam, see the full history of the code here.](https://github.com/hacksider/roop-cam) Please be informed that the base author of the code is [s0md3v](https://github.com/s0md3v/roop)
