# tmodloader-macos-arm64

Запуск [tModLoader](https://store.steampowered.com/app/1281930/tModLoader/) из Steam нативно на Apple Silicon, без Rosetta 2.

[English version](README.md)

**Статус:** экспериментальный. Проверено на одном Mac (M3 Pro, macOS 27.2.1, tModLoader v2026.9.3.1, 38 модов, включая Calamity и Fargo's Souls). Если у вас не работает, [создайте issue](../../issues) и приложите `tModLoader-Logs/Launch.log`.

## Установка

Вставьте в Терминал:

```sh
curl -fsSL https://raw.githubusercontent.com/Christian-SC26/tmodloader-macos-arm64/main/install.sh | bash
```

Потом в Steam: **Библиотека → правый клик по tModLoader → Свойства → Общие → Параметры запуска**, добавьте `-arm64`. Установщик сам скопирует `-arm64` в буфер обмена.

Нужен Mac на Apple Silicon и tModLoader, установленный через Steam. Если папка tModLoader лежит вне библиотек Steam, запустите установщик с `TML_DIR=/путь/к/tModLoader`.

## В чём проблема

На Apple Silicon tModLoader запускает x86_64-версию .NET через Rosetta 2. У лаунчера есть флаг `-arm64`, который переключает его на arm64-версию .NET. Но с ним игра закрывается секунды через две после нажатия «Играть» в Steam: ни окна, ни ошибки.

Причина: Steam запускает `start-tModLoader.sh` как x86_64-процесс и прописывает в `DYLD_INSERT_LIBRARIES` свою библиотеку `steamloader.dylib`. С флагом `-arm64` скрипт `LaunchUtils/ScriptCaller.sh` перезапускает себя через `arch -arm64`. `arch` относится к системным программам с архитектурой arm64e, а в `steamloader.dylib` есть только i386, x86_64 и arm64. Поэтому dyld падает:

```
dyld: terminating because inserted dylib '.../steamloader.dylib' could not be loaded:
  (fat file, but missing compatible architecture (have 'i386,x86_64,arm64', need 'arm64e'))
```

На форумах советуют поменять `arm_flag` в `ScriptCaller.sh`. Этот флаг только выбирает версию .NET, а падение из-за dyld остаётся.

## Что меняет установщик

1. Добавляет шесть строк в `start-tModLoader.sh`: при флаге `-arm64` они убирают `DYLD_INSERT_LIBRARIES`. Скрипт tModLoader `EnvironmentFix.sh` перед стартом игры возвращает эту переменную из `STEAM_DYLD_INSERT_LIBRARIES`, поэтому оверлей Steam и учёт времени в игре работают. Оригинал остаётся рядом как `start-tModLoader.sh.orig`.
2. Скачивает arm64-версию .NET в `tModLoader/dotnet_arm64` через `InstallDotNet.sh` из самого tModLoader, чтобы версия совпала с `tModLoader.runtimeconfig.json`.

За пределами папки tModLoader установщик ничего не трогает. Без `-arm64` в параметрах запуска tModLoader запускается через Rosetta, как раньше.

## Как проверить

Запустите игру из Steam, откройте Мониторинг системы и найдите процесс `dotnet`. В колонке **Тип** должно стоять **Apple**. **Intel** означает, что игра работает через Rosetta.

## После обновления tModLoader

Steam заменяет `start-tModLoader.sh` при обновлении tModLoader и при **проверке целостности файлов**. После этого игра с `-arm64` снова не запустится. Просто выполните команду установки ещё раз.

## Ограничения

- Установщик убирает только Rosetta. Тяжёлые моды по-прежнему съедают кадры, и замеров FPS в этом репозитории нет.
- Графика остаётся на MoltenVK 1.1.10, который идёт с tModLoader. При замене на MoltenVK 1.4.2 в тесте сломался рендер, поэтому установщик MoltenVK не трогает.
- На Mac с Intel tModLoader и так работает нативно, им ничего ставить не нужно.

## Удаление

```sh
curl -fsSL https://raw.githubusercontent.com/Christian-SC26/tmodloader-macos-arm64/main/install.sh | bash -s -- --uninstall
```

Команда восстановит `start-tModLoader.sh`, удалит `dotnet_arm64` и напомнит убрать `-arm64` из параметров запуска.

## Лицензия

[MIT](LICENSE). Проект не связан с командой tModLoader, Re-Logic или Valve.
