# FiveStar + GTA5RP HUD + P2P discovery (v1.1)

Исходный пользовательский файл: `GTA5Port-iOS-v1.5.2.ipa`, SHA-256 `42724954c1daff374919370a0db19976f7e5bf7bb073cb727bb2de06d4d12d34`. Второй пользовательский P2P-порт: `GTAV-unsigned.ipa`, SHA-256 `44ef714866abc59a08c3777cccaf1593768f7ed205f054243ac62e823376793a`.

Пользователь также предоставил установщик `RAGEMultiplayer_Setup.exe` (PE32 Nullsoft/NSIS для Windows, SHA-256 `8514e5a87261e6afc39d81d686d99d2cb691e01ccfcb16d822a7bb6bd8edd788`). Установщик не исполнялся и в iOS-приложение не включался.

## Что реализовано

- Подключена отдельная ARM64 библиотека `libGTA5RPOverlay.dylib` (GitHub Actions [successful build](https://github.com/opoaal080-eng/gta-5-rp/actions/runs/41319423056)) к **первому** порту через `LC_LOAD_DYLIB`, не меняя игровые байты вне Mach-O заголовка.
- Добавлены меню и диагностика GTA5RP (masterlist онлайн, STUN, RakNet и HTTP без загрузки ресурсов), экспорт лога.
- Добавлен read-only Bonjour browser `_gtavmp._udp`, такой же тип объявления присутствует в `libgtacompat.dylib` **второго** P2P-порта. Для этого в Info.plist заданы `NSBonjourServices` и `NSLocalNetworkUsageDescription`.
- Проверено статически: исходный `PlayGTA5Native` сохранён вне первых 16 КиБ заголовка; полный пакет ресурсов и Metal-шейдеры исходного FiveStar не изменены; модуль встроен, IPA открывается как корректный ZIP.

## Ограничения

**Настоящий P2P-мультиплеер второго порта НЕ перенесён в игровой мир первого.** `libgtacompat.dylib` экспортирует `compat_P2pAttach`, `compat_P2pSend`, `compat_P2pJoin`, но первый движок не содержит точек вызова этих функций и использует другую архитектуру рендера. Копировать DLL в IPA без адаптера движка бессмысленно и потенциально приводит к нестабильному запуску.

Браузер обнаруживает объявления в одной LAN, **не присоединяет игрока к сессии и не создаёт персонажей**. Для полноценного онлайна нужны адаптер сетевого транспорта к объектам FiveStar и поддержка состояния персонажей. GTA5RP использует иной клиент RAGE MP; Windows установщик не даёт готовый ARM64 iOS модуль, а клиентский протокол RAGE MP/авторизация пока не реализованы.

Новая IPA имеет bundle ID `fun.nightwell.gta5rp.fivestar`, version `1.1.0`, **не подписана**. Установка требует переподписи всего приложения и новой dylib. На реальном iPhone запуск этой комбинации ещё не проверялся.

RAGE MP официально описывает TCP/UDP порт 22005 и HTTP порт клиентских пакетов 22006: https://wiki.rage.mp/wiki/Getting_Started_with_Server.
