# MD Peek

Нативный просмотрщик Markdown для macOS 14+. Документы открываются только для чтения. Ориентир интерфейса — Apple Preview: отдельное окно на документ, одна колонка текста, системная светлая и тёмная тема. Стек: Swift 6, SwiftUI, AppKit и MarkdownUI 2.4.1. Проект открывается в Xcode через `Package.swift`.

## Карта кода

| Задача | Где смотреть |
| --- | --- |
| Открытие документов, меню, горячие клавиши | `Sources/MDPeek/MDPeekApp.swift`: `MDPeeKApp`, `MarkdownDocument` |
| Рендеринг, относительные пути, масштаб, перечитывание | Там же: `ReaderView`, `ReadingScale`, `FileWatcher` |
| Типографика, таблицы, цитаты и блоки кода | `Sources/MDPeek/ReaderTheme.swift`: `Theme.reader` |
| Регистрация .md/.markdown в LaunchServices | `Info.plist`: роль Viewer, UTI Markdown, bundle ID `com.mdpeek.app` |
| Сборка и локальная подпись | `scripts/build.sh` |
| Документ для ручной проверки | `Tests/Fixtures/elements.md` и соседний `sample.png` |

## Сборка и проверка

- `./scripts/build.sh` собирает Release для arm64 и создаёт `build/MD Peek.app` с ad-hoc подписью. Для первой загрузки пакетов нужен доступ к GitHub. Версии закреплены в `Package.resolved`.
- Из корня проекта: `open -a "$PWD/build/MD Peek.app" "$PWD/Tests/Fixtures/elements.md"`. Для просмотра новой сборки сначала полностью завершите старый экземпляр через ⌘Q.
- Release-сборка проходит. LaunchServices принимал запрос на открытие тестового файла. Этот результат не подтверждает визуальный рендеринг всех элементов или работу нескольких окон.
- `.build/` и `build/` — генерируемые каталоги. Для изучения проекта достаточно исходников и файлов из таблицы. Если в корне есть `.codegraph/`, сначала используйте CodeGraph для навигации по коду.

## Известные ограничения

- `FileWatcher` использует polling. Событийное наблюдение и явное восстановление позиции прокрутки после перечитывания пока отсутствуют.
- `ReaderView` передаёт строку в `Markdown` при построении view. Отдельного кеша разобранного Markdown пока нет.
- Сохраняйте режим чтения: `DocumentGroup(viewing:)` и запрет записи в `MarkdownDocument`. Для Markdown используйте существующий рендерер. HTML и код из документа не должны исполняться.
