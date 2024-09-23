
#!/bin/bash

set -e

GREEN="\033[0;32m"
NOCOLOR="\033[0m"

if [ $# != 1 ]
then
    echo "Usage: ./run.sh <workspace_directory>"
    echo "The <workspace_directory> will be mounted to /root/workspace inside the container."
    exit 1
fi

if [ ! -d $1 ]
then
    echo -e "${GREEN}Note: $1 is not an existing directory. It will be automatically created... ${NOCOLOR}"
fi

cleanup () {
    xhost -local:docker
}
trap cleanup EXIT

IMAGE_NAME="humanoid-control:latest"
CONTAINER_NAME="humanoid-control-container"
HOST_WORKSPACE_DIR=$(readlink -f $1)
CONTAINER_WORKSPACE_DIR="/catkin_ws"
DOCKERFILE_PATH="$HOST_WORKSPACE_DIR/src/humanoid-control/docker/Dockerfile"



echo "Building image at $IMAGE_NAME"
docker build -t $IMAGE_NAME "$HOST_WORKSPACE_DIR/src/humanoid-control/docker"
echo "Built image $IMAGE_NAME"

XAUTH=/tmp/.docker.xauth
if [ ! -f $XAUTH ]
then
    xauth_list=$(xauth nlist :0 | sed -e 's/^..../ffff/' | tail -1)
    if [ ! -z "$xauth_list" ]
    then
        echo $xauth_list | xauth -f $XAUTH nmerge -
    else
        touch $XAUTH
    fi
    chmod a+r $XAUTH
fi

xhost +local:docker

echo -e "${GREEN}$HOST_WORKSPACE_DIR will be mounted as $CONTAINER_WORKSPACE_DIR in the container ${NOCOLOR}"

docker run -it \
    --name="humanoid-control-container" \
    --env="DISPLAY=$DISPLAY" \
    --env="QT_X11_NO_MITSHM=1" \
    --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    --env="XAUTHORITY=$XAUTH" \
    --volume="$XAUTH:$XAUTH" \
    --volume="$HOST_WORKSPACE_DIR:$CONTAINER_WORKSPACE_DIR" \
    --runtime=nvidia \
    $IMAGE_NAME
