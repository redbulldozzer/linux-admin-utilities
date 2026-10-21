#!/bin/bash

# Скрипт для установки телеги в контейнере, 
# помогает при большей части проблемм с железом и частыми вылетами и фризами на определенной учетке
# Возможно не установит с первого раза, нужно проверить


# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

sudo groupadd docker

sudo usermod -aG docker $USER
 
newgrp docker

sudo systemctl enable docker.service
sudo systemctl enable containerd.service

mkdir $HOME/TelegramDocker

DOWNLOADS_EN="$HOME/Downloads"
DOWNLOADS_RU="$HOME/Загрузки"
DESKTOP_EN="$HOME/Desktop"
DESKTOP_RU="$HOME/Рабочий стол"

# Проверяем, какая папка существует
if [ -d "$DOWNLOADS_RU" ]; then
    DOWNLOADS_FOLDER="$HOME/Загрузки"
elif [ -d "$DOWNLOADS_EN" ]; then
    DOWNLOADS_FOLDER="$HOME/Downloads"
else
    echo "Downloads folder not defined"
fi

# Проверяем, какая папка существует
if [ -d "$DESKTOP_RU" ]; then
    DESKTOP_FOLDER="$HOME/Загрузки"
elif [ -d "$DESKTOP_EN" ]; then
    DESKTOP_FOLDER="$HOME/Downloads"
else
    echo "Downloads folder not defined"
fi


echo -e '[Desktop Entry]
Version=1.0
Type=Application
Name=Telegram in Docker
Comment=Run Telegram via Docker container
Exec=bash -c "docker run --rm --name telegram --hostname=$(hostname) -e DISPLAY=unix$DISPLAY -e PULSE_SERVER=unix:$XDG_RUNTIME_DIR/pulse/native -v /tmp/.X11-unix:/tmp/.X11-unix -v /home/$(whoami)/.Xauthority:/home/user/.Xauthority -v $XDG_RUNTIME_DIR/pulse:$XDG_RUNTIME_DIR/pulse -v /etc/localtime:/etc/localtime:ro -v /home/$(whoami)/TelegramDocker/.TelegramDesktop:/home/user/.local/share/TelegramDesktop/ -v $DOWNLOAD_FOLDER:/home/user/Downloads xorilog/telegram /home/user/Telegram"
Icon=telegram
Terminal=false
Categories=Network;Chat;' > "$DESKTOP_FOLDER/Telegram-docker.desktop"

chmod +x "$DESKTOP_FOLDER/Telegram-docker.desktop"

echo "Done! Check your desktop"

