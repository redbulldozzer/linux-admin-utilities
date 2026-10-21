#!/bin/bash

# Скрипт для установки vncx11-сервера на компьютер, может быть полезно для удаленного подключения

# Проверим, что скрипт выполняется от root
if [[ $EUID -ne 0 ]]; then
    echo "Этот скрипт должен быть выполнен от имени пользователя root." 
    exit 1
fi

# Определим, какой менеджер пакетов использовать (для Arch Linux)
if command -v pacman &> /dev/null; then
    package_manager="pacman"
elif command -v apt &> /dev/null; then
    package_manager="apt"
else
    echo "Неизвестный менеджер пакетов. Убедитесь, что установлен pacman или apt."
    exit 1
fi

# Устанавливаем x11vnc в зависимости от менеджера пакетов
if [[ "$package_manager" == "pacman" ]]; then
    echo "Устанавливаем x11vnc с помощью pacman..."
    pacman -Sy --noconfirm x11vnc
elif [[ "$package_manager" == "apt" ]]; then
    echo "Устанавливаем x11vnc с помощью apt..."
    apt update
    apt install -y x11vnc
fi

# Запрашиваем и сохраняем собственный пароль интерактивно, без значения по умолчанию.
x11vnc -storepasswd /etc/x11vnc.pass || exit 1
chmod 600 /etc/x11vnc.pass

# Создаём systemd сервис для x11vnc
cat > /etc/systemd/system/x11vnc.service << EOF
[Unit]
Description=Start x11vnc at startup.
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -auth guess -noxdamage -shared -dontdisconnect -many -noxfixes -rfbauth /etc/x11vnc.pass

[Install]
WantedBy=multi-user.target
EOF

# Перезагружаем systemd для применения изменений
systemctl daemon-reload

# Включаем и запускаем сервис
echo "Включаем и запускаем x11vnc..."
systemctl enable x11vnc
systemctl start x11vnc

# Получаем IP-адрес
ip_address=$(hostname -I | awk '{print $1}')
echo "IP-адрес этого устройства: $ip_address"

# Задаем UUID флешки вручную
flash_uuid="your-uuid-here"  # Укажите UUID вашей флешки

# Находим точку монтирования флешки по UUID
mount_point=$(findmnt -U $flash_uuid -o TARGET -n)

if [ -z "$mount_point" ]; then
    echo "Флешка не найдена или не примонтирована."
    exit 1
else
    # Дописываем IP-адрес в файл на флешке
    echo "Записываем IP-адрес на флешку..."
    echo "IP-адрес: $ip_address" >> "$mount_point/ip-addresses"
fi

echo "Скрипт завершен успешно!"
