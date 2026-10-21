#!/bin/bash

# Создание юзеров Prototype по шаблону, запускать только на виртуалке

# Определяем фиксированный UID и GID и параметры
uid=1000
gid=1000
home_dir="/home/Prototype"
shell="/bin/bash"
# Хеш пароля задаётся пользователем; секретов и значений по умолчанию в коде нет.
read -r -s -p "Введите хеш пароля для создаваемых тестовых пользователей: " password
printf '\n'
if [[ -z "$password" ]]; then
    echo "Ошибка: хеш пароля не задан." >&2
    exit 1
fi
last_change_days=19793

# Запрос максимального количества создаваемых пользователей (до 10)
read -p "Введите максимальное количество создаваемых пользователей (максимум 10): " max_users

# Проверка на корректность ввода
if ! [[ "$max_users" =~ ^[0-9]+$ ]] || [ "$max_users" -lt 1 ] || [ "$max_users" -gt 10 ]; then
    echo "Ошибка: введите число от 1 до 10."
    exit 1
fi

# Получаем список всех существующих пользователей в системе в нижнем регистре
existing_users=$(cut -d: -f1 /etc/passwd | tr '[:upper:]' '[:lower:]')

# Начинаем с номера 1
number=1
created_users=0

# Цикл для создания пользователей
while [ "$created_users" -lt "$max_users" ]; do
    username="Prototype${number}"
    lower_username=$(echo "$username" | tr '[:upper:]' '[:lower:]')
    
    # Проверка, существует ли аналогичный пользователь (независимо от регистра)
    if echo "$existing_users" | grep -qx "$lower_username"; then
        echo "Пользователь с именем $username уже существует. Пропускаем."
        ((number++))
        continue
    fi

    # Создание пользователя с одинаковым UID и GID, используя флаг -o
    useradd -m -u "$uid" -g "$gid" -d "${home_dir}${number}" -s "$shell" -o "$username"

    # Установка хешированного пароля
    usermod --password "$password" "$username"

    # Установка времени последней смены пароля
    chage -d "$last_change_days" "$username"

    echo "Пользователь $username создан с UID $uid, GID $gid"
    
    # Обновляем список существующих пользователей (добавляем текущего в нижнем регистре)
    existing_users+=$'\n'"$lower_username"

    # Увеличиваем номер для следующего пользователя и счетчик созданных
    ((number++))
    ((created_users++))
done

echo "Создано пользователей: $created_users"
