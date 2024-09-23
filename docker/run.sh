
#!/bin/bash

set -e

GREEN="\033[0;32m"
NOCOLOR="\033[0m"

REBUILD_FLAG=false
WORKSPACE_DIR=""

# Function to display usage
usage() {
    echo "Usage: $0 [-r|--rebuild] [workspace_directory]"
    echo "  -r, --rebuild    Force rebuild of the Docker image"
    echo "  workspace_directory    Path to the workspace directory (default: current directory)"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -r|--rebuild)
            REBUILD_FLAG=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [ -z "$WORKSPACE_DIR" ]; then
                WORKSPACE_DIR="$1"
            else
                echo "Error: Unexpected argument '$1'"
                usage
            fi
            shift
            ;;
    esac
done

# If no workspace directory is provided, use the current directory
if [ -z "$WORKSPACE_DIR" ]; then
    WORKSPACE_DIR=$(pwd)
fi

echo -e "${GREEN}Using workspace directory: $WORKSPACE_DIR ${NOCOLOR}"
if [ "$REBUILD_FLAG" = true ]; then
    echo -e "${GREEN}Rebuild flag set. Will rebuild the image. ${NOCOLOR}"
fi

if [ ! -d "$WORKSPACE_DIR" ]; then
    echo -e "${GREEN}Note: $WORKSPACE_DIR is not an existing directory. It will be automatically created... ${NOCOLOR}"
    mkdir -p "$WORKSPACE_DIR"
fi

cleanup () {
    xhost -local:docker
}
trap cleanup EXIT

IMAGE_NAME="humanoid-control:latest"
CONTAINER_NAME="humanoid-control-container"
HOST_WORKSPACE_DIR="$WORKSPACE_DIR"
CONTAINER_WORKSPACE_DIR="/catkin_ws"
DOCKERFILE_PATH="$HOST_WORKSPACE_DIR/src/humanoid-control/docker/Dockerfile"

# Function to check if the image needs to be rebuilt
need_rebuild() {
    if [ "$REBUILD_FLAG" = true ]; then
        echo "Rebuild flag is set. Rebuilding image."
        return 0
    fi
    
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        echo "Dockerfile not found. Rebuilding image."
        return 0
    fi
    
    if [ "$(docker images -q $IMAGE_NAME 2> /dev/null)" = "" ]; then
        echo "Image does not exist. Building for the first time."
        return 0
    fi
    
    echo "No need to rebuild the image."
    return 1
}

# Function to build the Docker image
build_image() {
    echo "Building image $IMAGE_NAME"
    docker build -t $IMAGE_NAME "$HOST_WORKSPACE_DIR/src/humanoid-control/docker"
    echo "Built image $IMAGE_NAME"
}

# Function to stop and remove existing containers
remove_existing_containers() {
    echo "Removing existing containers..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
}

# Function to set up X11 forwarding
setup_x11() {
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
}

# Function to run a new container
run_container() {
    echo -e "${GREEN}$HOST_WORKSPACE_DIR will be mounted as $CONTAINER_WORKSPACE_DIR in the container ${NOCOLOR}"
    
    docker run -it \
        --name="$CONTAINER_NAME" \
        --env="DISPLAY=$DISPLAY" \
        --env="QT_X11_NO_MITSHM=1" \
        --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
        --env="XAUTHORITY=$XAUTH" \
        --volume="$XAUTH:$XAUTH" \
        --volume="$HOST_WORKSPACE_DIR:$CONTAINER_WORKSPACE_DIR" \
        --runtime=nvidia \
        $IMAGE_NAME
}

# Function to attach to an existing container
attach_container() {
    echo "Attaching to existing container..."
    docker exec -it $CONTAINER_NAME /bin/bash
}

# Main logic
if need_rebuild; then
    remove_existing_containers
    build_image
    setup_x11
    run_container
elif [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    attach_container
else
    setup_x11
    run_container
fi