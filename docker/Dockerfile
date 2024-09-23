FROM osrf/ros:noetic-desktop-full

ARG USER=user
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -y ros-noetic-moveit \
    ros-noetic-ros-controllers ros-noetic-gazebo-ros-control \
    ros-noetic-rosserial ros-noetic-rosserial-arduino \
    ros-noetic-roboticsgroup-upatras-gazebo-plugins \
    ros-noetic-actionlib-tools \
    python3-catkin-tools ros-noetic-pybind11-catkin
    
RUN apt-get install -y git terminator python3-pip \
    liburdfdom-dev liboctomap-dev libassimp-dev \
    libglpk-dev python3-dev

RUN rm -rf /var/lib/apt/lists/*

RUN pip install flask flask-ask-sdk ask-sdk

## Set up your catkin workspace
RUN mkdir -p /catkin_ws/src
WORKDIR /catkin_ws

# Source ROS setup.bash in .bashrc
RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc

## Build OCS2
WORKDIR /catkin_ws/src
# Clone OCS2
RUN git clone https://github.com/leggedrobotics/ocs2.git
# Clone pinocchio
RUN git clone --recurse-submodules https://github.com/leggedrobotics/pinocchio.git
# Clone hpp-fcl
RUN git clone --recurse-submodules https://github.com/leggedrobotics/hpp-fcl.git
# Clone ocs2_robotic_assets
RUN git clone https://github.com/leggedrobotics/ocs2_robotic_assets.git

# Go to workspace
WORKDIR /catkin_ws
# Initialize catkin workspace
RUN /bin/bash -c ". /opt/ros/noetic/setup.bash && catkin init"

# Build the packages
RUN /bin/bash -c "catkin config -DCMAKE_BUILD_TYPE=RelWithDebInfo"
RUN /bin/bash -c "source /opt/ros/noetic/setup.bash && \
    catkin build ocs2_legged_robot_ros ocs2_self_collision_visualization"

# Source the workspace setup in bashrc
RUN echo "source /catkin_ws/devel/setup.bash" >> ~/.bashrc

## Install mujoco
# Check Python version
RUN python3 --version

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libgl1-mesa-dev \
    libgl1-mesa-glx \
    libglew-dev \
    libosmesa6-dev \
    software-properties-common \
    python3-numpy

# Remove exisitng openssl, which causes trouble.
RUN apt-get remove -y python3-openssl
RUN pip3 install --upgrade pip setuptools
RUN pip3 install pyopenssl --upgrade

# Install MuJoCo
RUN pip3 install --no-cache-dir mujoco

## Install pynput
RUN pip3 install pynput

## Bash setting to enable quicker development
# Alternatively, you can add the bindings to .inputrc (works for multiple shells)
RUN echo "\"\e[A\": history-search-backward" >> /etc/inputrc && \
    echo "\"\e[B\": history-search-forward" >> /etc/inputrc

# Source ROS setup.bash when starting a new shell
SHELL ["/bin/bash", "-c"]

# Set the default command to bash
CMD ["bash"]
