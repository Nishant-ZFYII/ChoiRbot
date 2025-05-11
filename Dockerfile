# Base image with GPU/OpenGL support
FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu22.04

# Environment variables
ENV ROS_DISTRO=humble \
    TURTLEBOT3_MODEL=burger \
    DEBIAN_FRONTEND=noninteractive \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=graphics,utility,compute \
    ROS_DOMAIN_ID=30 \
    GAZEBO_MODEL_PATH=/opt/ros/humble/share/turtlebot3_gazebo/models

# 1. Install all tools (including editors)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg2 lsb-release software-properties-common \
    git wget xterm python3-pip python3-colcon-common-extensions \
    python3-rosdep build-essential \
    nano gedit \
    && rm -rf /var/lib/apt/lists/*

# 2. Setup ROS 2 and Gazebo repos
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/ros2.list && \
    curl -sSL http://packages.osrfoundation.org/gazebo.key | apt-key add - && \
    echo "deb http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" > /etc/apt/sources.list.d/gazebo-stable.list

# 3. Install ROS 2 and Gazebo
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-desktop \
    ros-humble-turtlebot3* \
    gazebo libgazebo-dev \
    && rm -rf /var/lib/apt/lists/*

# 4. Initialize rosdep
RUN rosdep init || true && rosdep update

# 5. Create user with passwordless sudo
RUN groupadd -g 1000 ubuntu && \
    useradd -m -s /bin/bash -u 1000 -g 1000 ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "Defaults !requiretty" >> /etc/sudoers

USER ubuntu
WORKDIR /home/ubuntu

# 6. Create workspace and clone ChoiRbot PROPERLY (no nesting)
RUN mkdir -p dev_ws/src && \
    git clone https://github.com/Nishant-ZFYII/ChoiRbot.git dev_ws/src/choirbot && \
    rm -rf dev_ws/src/choirbot/.git  # Optional: reduce image size

# 7. Install Python dependencies
RUN pip3 install --upgrade pip && \
    pip3 install disropt

# 8. Setup turtlebot3_ws
RUN bash -c "mkdir -p ~/turtlebot3_ws/src && \
    cd ~/turtlebot3_ws/src && \
    git clone -b humble-devel https://github.com/ROBOTIS-GIT/turtlebot3_simulations.git && \
    cd ~/turtlebot3_ws && \
    source /opt/ros/$ROS_DISTRO/setup.bash && \
    colcon build --symlink-install"

# 9. Configure environment
RUN echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc && \
    echo "source ~/dev_ws/install/setup.bash" >> ~/.bashrc && \
    echo "source ~/turtlebot3_ws/install/setup.bash" >> ~/.bashrc && \
    echo "export TURTLEBOT3_MODEL=burger" >> ~/.bashrc && \
    echo "export ROS_DOMAIN_ID=30" >> ~/.bashrc && \
    echo "export GAZEBO_MODEL_PATH=/opt/ros/humble/share/turtlebot3_gazebo/models" >> ~/.bashrc && \
    echo "alias build_ws='cd ~/dev_ws && colcon build --symlink-install'" >> ~/.bashrc

# 10. Final setup
WORKDIR /home/ubuntu/dev_ws
ENTRYPOINT ["/bin/bash"]
