#!/bin/bash

# Проверка на root права
if [ "$EUID" -ne 0 ]; then
  echo "Брат, запускай скрипт через sudo!"
  exit
fi

echo "=== ПЕРЕИМЕНОВАНИЕ LINUX MINT ==="

# 1. Запоминаем текущее имя (чтобы найти и заменить его в hosts)
CURRENT_HOSTNAME=$(hostname)

# 2. Спрашиваем номер
read -p "Введи номер компьютера (только цифру, например 5 или 12): " INPUT_NUM

# 3. Проверка: является ли введенное значение числом
if ! [[ "$INPUT_NUM" =~ ^[0-9]+$ ]]; then
    echo "Ошибка: Нужно ввести число!"
    exit 1
fi

# 4. Форматируем имя (добавляем ноль, если цифра одна, чтобы было pc05)
# %02d означает: выводить число минимум из 2 знаков, дополняя нулями
NEW_HOSTNAME=$(printf "pc%02d" $INPUT_NUM)

echo "Текущее имя: $CURRENT_HOSTNAME"
echo "Новое имя будет: $NEW_HOSTNAME"
echo "--------------------------------"

read -p "Продолжаем? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "Отмена."
    exit 0
fi

# 5. Меняем hostname через systemd (стандарт для Mint)
hostnamectl set-hostname "$NEW_HOSTNAME"

# 6. Самое важное: меняем имя в /etc/hosts, чтобы sudo не тупил
# Делаем бэкап на всякий случай
cp /etc/hosts /etc/hosts.bak
# Ищем старое имя и меняем на новое через sed
sed -i "s/$CURRENT_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts

echo "Готово! Имя изменено на $NEW_HOSTNAME."
echo "В /etc/hosts запись обновлена."

# 7. Предлагаем ребут
read -p "Нужна перезагрузка для полного применения. Ребутнуть сейчас? (y/n): " REBOOT
if [[ "$REBOOT" == "y" ]]; then
    reboot
else
    echo "Ок, не забудь перезагрузить позже."
fi
