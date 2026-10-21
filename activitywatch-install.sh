#!/bin/bash

# Для установки activitywatch на localhost, утилиты для просмотра времени в afk и нахождения в каких либо программах
# Может быть улучшен, если сделать вход по паролю через nginx, либо caddy, со вторым проще 


# Убедимся, что unzip установлен
sudo apt update && sudo apt install -y unzip curl

# Загружаем ActivityWatch (проверяем успешность загрузки)
AW_URL="https://github.com/ActivityWatch/activitywatch/releases/download/v0.13.2/activitywatch-v0.13.2-linux-x86_64.zip"
AW_TMP="/tmp/activitywatch.zip"
AW_DIR="/opt/activitywatch"
CURRENT_USER=$(who | awk 'NR==1{print $1}')
AW_DATA_DIR=$AW_DIR/data
AW_DM_DIR="$HOME/.config/systemd/user"

# Создаём папку systemd/user
mkdir -p "$AW_DM_DIR"

# Заливаем конфиг
mkdir -p $HOME/.config/activitywatch/aw-server/
echo "Залив конфига..."
cat <<EOF | tee $HOME/.config/activitywatch/aw-server/aw-server.toml >/dev/null
[server]
host = "0.0.0.0"
#port = "5600"
#storage = "peewee"
#cors_origins = ""

[server.custom_static]

[server-testing]
#host = "localhost"
#port = "5666"
#storage = "peewee"
#cors_origins = ""

[server-testing.custom_static]
EOF

cat <<EOF | tee $HOME/.config/activitywatch/aw-server/settings.json >/dev/null
{
    "initialTimestamp": "2025-03-25T11:01:01.371Z",
    "startOfDay": "04:00",
    "startOfWeek": "Monday",
    "durationDefault": 3600,
    "landingpage": "/home",
    "theme": "light",
    "newReleaseCheckData": {
        "isEnabled": true,
        "nextCheckTime": "2025-03-26T11:01:01.371Z",
        "howOftenToCheck": 86400,
        "timesChecked": 0
    },
    "userSatisfactionPollData": {
        "isEnabled": true,
        "nextPollTime": "2025-04-01T11:01:01.371Z",
        "timesPollIsShown": 0
    },
    "classes": [
        {
            "name": [
                "Work"
            ],
            "rule": {
                "type": "regex",
                "regex": "Google Docs|libreoffice|ReText"
            },
            "data": {
                "color": "#0F0",
                "score": 10
            }
        },
        {
            "name": [
                "Work",
                "Programming"
            ],
            "rule": {
                "type": "regex",
                "regex": "GitHub|Stack Overflow|BitBucket|Gitlab|vim|Spyder|kate|Ghidra|Scite"
            }
        },
        {
            "name": [
                "Work",
                "Programming",
                "ActivityWatch"
            ],
            "rule": {
                "type": "regex",
                "regex": "ActivityWatch|aw-",
                "ignore_case": true
            }
        },
        {
            "name": [
                "Work",
                "Image"
            ],
            "rule": {
                "type": "regex",
                "regex": "GIMP|Inkscape"
            }
        },
        {
            "name": [
                "Work",
                "Video"
            ],
            "rule": {
                "type": "regex",
                "regex": "Kdenlive"
            }
        },
        {
            "name": [
                "Work",
                "Audio"
            ],
            "rule": {
                "type": "regex",
                "regex": "Audacity"
            }
        },
        {
            "name": [
                "Work",
                "3D"
            ],
            "rule": {
                "type": "regex",
                "regex": "Blender"
            }
        },
        {
            "name": [
                "Media"
            ],
            "rule": {
                "type": "none"
            },
            "data": {
                "color": "#F33"
            }
        },
        {
            "name": [
                "Media",
                "Games"
            ],
            "rule": {
                "type": "regex",
                "regex": "Minecraft|RimWorld"
            },
            "data": {
                "color": "#F80"
            }
        },
        {
            "name": [
                "Media",
                "Video"
            ],
            "rule": {
                "type": "regex",
                "regex": "YouTube|Plex|VLC"
            },
            "data": {
                "color": "#F33"
            }
        },
        {
            "name": [
                "Media",
                "Social Media"
            ],
            "rule": {
                "type": "regex",
                "regex": "reddit|Facebook|Twitter|Instagram|devRant",
                "ignore_case": true
            },
            "data": {
                "color": "#FCC400"
            }
        },
        {
            "name": [
                "Media",
                "Music"
            ],
            "rule": {
                "type": "regex",
                "regex": "Spotify|Deezer",
                "ignore_case": true
            },
            "data": {
                "color": "#A8FC00"
            }
        },
        {
            "name": [
                "Comms"
            ],
            "rule": {
                "type": "none"
            },
            "data": {
                "color": "#9FF"
            }
        },
        {
            "name": [
                "Comms",
                "IM"
            ],
            "rule": {
                "type": "regex",
                "regex": "Messenger|Telegram|Signal|WhatsApp|Rambox|Slack|Riot|Element|Discord|Nheko|NeoChat|Mattermost"
            }
        },
        {
            "name": [
                "Comms",
                "Email"
            ],
            "rule": {
                "type": "regex",
                "regex": "Gmail|Thunderbird|mutt|alpine"
            }
        },
        {
            "name": [
                "Uncategorized"
            ],
            "rule": {
                "type": null
            },
            "data": {
                "color": "#CCC"
            }
        }
    ],
    "views": [
        {
            "elements": [
                {
                    "props": {},
                    "type": "vis_timeline"
                },
                {
                    "type": "sunburst_clock",
                    "props": {}
                }
            ],
            "id": "summary",
            "name": "Summary"
        }
    ],
    "requestTimeout": 30,
    "friends_with_mate": true
}
EOF




echo "Загрузка ActivityWatch..."
if ! curl -sSL "$AW_URL" -o "$AW_TMP"; then
    echo "Ошибка загрузки! Проверьте интернет-соединение или URL."
    exit 1
fi

# Проверяем, что архив не повреждён
if ! unzip -tq "$AW_TMP"; then
    echo "Архив повреждён! Повторите загрузку."
    rm -f "$AW_TMP"
    exit 1
fi

# Распаковываем
echo "Установка в $AW_DIR..."
sudo unzip -q "$AW_TMP" -d /opt/
rm -f "$AW_TMP"

# Настраиваем сервис
echo "Настройка сервиса..."
cat <<EOF | tee "$AW_DM_DIR"/aw-server.service >/dev/null
[Unit]
Description=ActivityWatch Server
After=network.target

[Service]
ExecStart=/opt/activitywatch/aw-server/aw-server
Restart=always

[Install]
WantedBy=default.target

EOF



# AFK WATCHE

cat <<EOF | tee "$AW_DM_DIR"/aw-watcher-afk.service >/dev/null
[Unit]
Description=ActivityWatch AFK Watcher
After=network.target

[Service]
ExecStart=/opt/activitywatch/aw-watcher-afk/aw-watcher-afk
Restart=always

[Install]
WantedBy=default.target

EOF


# WINDOW WATCH

cat <<EOF | tee "$AW_DM_DIR"/aw-watcher-window.service >/dev/null
[Unit]
Description=ActivityWatch Window Watcher
After=network.target

[Service]
ExecStart=/opt/activitywatch/aw-watcher-window/aw-watcher-window
Restart=always

[Install]
WantedBy=default.target

EOF




#  INPUT WATCH

cat <<EOF | tee "$AW_DM_DIR"/aw-watcher-input.service >/dev/null
[Unit]
Description=ActivityWatch AFK Watcher
After=network.target

[Service]
ExecStart=/opt/activitywatch/aw-watcher-input/aw-watcher-input
Restart=always

[Install]
WantedBy=default.target

EOF

mkdir


# Запускаем
systemctl --user daemon-reload
systemctl --user start aw-watcher-afk
systemctl --user start aw-watcher-window
systemctl --user start aw-watcher-input
systemctl --user start aw-server
systemctl --user enable aw-watcher-afk
systemctl --user enable aw-watcher-input
systemctl --user enable aw-watcher-window
systemctl --user enable aw-server




