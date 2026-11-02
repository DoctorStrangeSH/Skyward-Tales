# AI HANDOFF — Skyward Tales

Последнее обновление: 2 ноября 2026 года.

Этот документ — обязательная точка входа для следующего ИИ-разработчика. Прочитай его и `docs/ROADMAP.md` до изменения кода.

## 1. Видение проекта

Skyward Tales — 2D top-down pixel-art fantasy RPG с исследованием открытого мира, магией, прокачкой, сюжетом, квестами, NPC, подземельями и боссами.

Основной язык игры на текущем этапе — русский. Пользователь — владелец проекта и тестировщик. ИИ выступает техническим лидом: самостоятельно принимает обоснованные инженерные решения, реализует функции, поддерживает документацию и предоставляет пользователю сборки для тестирования.

## 2. Технологии и принципы

- Движок: Godot 4.x.
- Язык: GDScript.
- Жанр/камера: 2D top-down action RPG.
- Внутреннее разрешение: 640×360; окно: 1280×720; nearest texture filtering.
- Репозиторий: https://github.com/DoctorStrangeSH/Skyward-Tales
- Основная ветка: `main`.
- Рабочая ветка первого инкремента: `feat/godot-rpg-foundation`.

Почему Godot: проект ориентирован на 2D, пиксельную графику, частые итерации и модульные игровые системы. Не мигрировать на Unity/Unreal без конкретной технической причины.

Архитектурные принципы:
1. Разделять игровые системы по ответственности.
2. Квесты, заклинания, предметы, врагов и NPC переводить на ресурсы или JSON-данные, а не размножать хардкод.
3. Не помещать всю игру в один огромный скрипт.
4. Сохранять исходники арта и единые правила импорта.
5. Поддерживать русский язык в интерфейсе и контенте.
6. После каждого изменения обновлять ROADMAP и этот HANDOFF.
7. Не утверждать, что тесты пройдены, если Godot действительно не запускался.

## 3. Текущая структура репозитория

На коммите централизации каталогов — 80 отслеживаемых файлов: 22 runtime GDScript, 36 headless-тестов, 4 сцены, 5 JSON-каталогов, 3 PNG-атласа и инструменты/документация.

- `project.godot` — настройки проекта, viewport и Input Map.
- `scenes/` — 4 сцены: главное меню, основная игровая сцена, игрок и магический снаряд.
- `scripts/main.gd` — orchestration игровой сцены, регионы, взаимодействия, бой, лут, квестовые события и восстановление мира.
- `scripts/game_catalogs.gd` — единая загрузка словарных каталогов бестиария, талантов и заклинаний; файлы закрываются после чтения.
- `scripts/save_system.gd` — запись/чтение versioned JSON save и структурная валидация через `validate_snapshot()`.
- `scripts/player.gd` — движение, рывок, здоровье/мана, опыт, таланты, инвентарь и экипировка.
- `scripts/hud.gd` — HUD, инвентарь, сравнение экипировки, карта, бестиарий, диалоги, пауза и окна поражения.
- `scripts/enemy.gd` и наследники — AI, бой, стихийные статусы и реакции.
- `scripts/quest_manager.gd` — состояние квестов из `data/quests.json`.
- `scripts/world.gd` — геометрия регионов и коллизии.
- `data/` — 5 JSON-каталогов: бестиарий, экипировка, квесты, заклинания и таланты.
- `assets/sprites/` — 3 текущих runtime PNG-атласа, manifest и README; исходные PNG не удалять до миграции ссылок на утверждённый арт.
- `tests/` — 36 headless-регрессионных тестов; каждый тест должен присутствовать в Godot CI ровно один раз.
- `tools/validate_sprite_atlases.py` — проверка PNG-атласов.
- `docs/ROADMAP.md`, `docs/AI_HANDOFF.md` — актуальные план и передача проекта.

Новые каталоги пока не объединяют `data/quests.json` и `data/equipment.json`: QuestManager и PlayerCharacter загружают их самостоятельно. Не переводить эти системы на общий загрузчик без отдельного теста и обоснования.

## 4. Пиксельная графика и 8 направлений

Текущий runtime использует самостоятельные PNG напрямую из res://; ZIP-архив и SpriteArchive.extract_if_needed() не нужны. Атласы:

- Герой: assets/sprites/characters/hero_8dir_walk.png.
- Слизень: assets/sprites/enemies/forest_slime_true8.png.
- Огненный шар: assets/sprites/magic/fireball_8dir.png.

Все атласы: RGBA 128×256 px, 4 столбца × 8 строк, клетка 32×32 px. Порядок строк: down, down-right, right, up-right, up, up-left, left, down-left. Герой и враги должны иметь настоящие задние и задне-диагональные ракурсы; нельзя имитировать их поворотом фронтального кадра. Снаряд уже нарисован по направлениям и не должен дополнительно вращаться.

tools/validate_sprite_atlases.py проверяет формат и размеры, но не качество анатомии/анимации. Текущие PNG — временный технический арт, который пользователь ранее отклонил по качеству. Не выдавать его за финальный стиль. См. assets/ART_GUIDE.md и assets/sprites/README.md.

## 5. Текущий игровой фрагмент

Проект вырос из первого квестового среза в игровой прототип. Сейчас присутствуют два региона, NPC и задания, три заклинания (огонь, лёд, молния), несколько типов противников, лесной босс с двумя фазами, уклонение, таланты, бестиарий, карты, сундуки, добыча, экипировка и сохранение прогресса.

Базовое управление:
- WASD / стрелки — движение.
- E — взаимодействие, сбор и закрытие диалога.
- ЛКМ — применить выбранное заклинание.
- Esc — пауза.

Во время диалога движение и каст блокируются. Перед добавлением новых клавиш сверяйся с Input Map в project.godot и обработчиками main.gd.

## 6. Проверенное состояние на 2026-11-02

Рабочая ветка feat/godot-rpg-foundation содержит полноценный игровой прототип, а не только стартовый вертикальный срез. Последовательность последних изменений включает сундуки и редкость добычи, постоянную Звёздную эссенцию, data-driven экипировку, четыре слота и три стихийные реликвии.

**Последний подтверждённый CI перед этим handoff-обновлением:** Godot 4.7.2, runs 41464519864 и 41464507093 на commit `808591d4ba399beacc1939cc13d3d24a0b6461f3` — оба success, каждый job прошёл 42/42 шага. В workflow подключены все 35 файлов `tests/*.gd`, включая проверки экипировки, сохранений и синергии «Огненная буря». Этот handoff-only commit запустит новый CI; следующий ИИ должен проверить самый свежий run. Headless CI не заменяет ручную проверку окна игры.

CI не заменяет ручную проверку окна игры, UX, визуального качества, расположения объектов и баланса. Эти пункты остаются открытыми. Не заявлять, что пользовательская ручная QA выполнена.

Первое действие следующего ИИ — сверить фактический HEAD, PR и этот документ, затем не повторять уже готовые системы. Провести/получить ручной QA и продолжить по актуальной дорожной карте.

## 7. Следующие инженерные задачи

Приоритет A — ручная проверка и стабилизация:
- Попросить пользователя пройти игру в оконном режиме и собрать конкретные замечания по бою, картам, инвентарю, экипировке, сундукам и сохранениям.
- Вручную проверить панель сравнения экипировки на 640×360: длинные названия, прокрутку сумки, читаемость чисел и цветов улучшения/ухудшения.
- Проверить баланс редкого дропа: 7% редкости распределяется поровну между четырьмя наградами; при четырёх сундуках в одном прохождении редкие предметы могут не выпасть вовсе.
- Проверить визуальное качество всех текущих временных PNG в реальном масштабе игры.

Приоритет B — развитие RPG и архитектура:
- После ручной QA постепенно разделить main.gd (сейчас около 767 строк: регионы, квесты, бой, лут, экипировка и сохранения) на контроллеры регионов/взаимодействий/боя/сохранения; не делать большой rewrite.
- Постепенно разделить hud.gd (691 строка на HEAD аудита) на отдельные панели/компоненты, сохранив текущие сигналы и тесты.
- Перевести временную геометрию мира на TileMapLayer и отдельные сцены регионов.
- Добавить поселение, торговцев, экономику, продажу и ремесло.
- Развить диалоговую систему, сюжетные цепочки, репутацию и последствия решений.
- Расширить каталог предметов и артефактов через данные; избегать ручных списков item ID в HUD и обработчиках.
- Сравнение экипировки реализовано: `PlayerCharacter.get_equipment_comparison()` рассчитывает фактические значения до/после замены слота; HUD показывает боковую таблицу при наведении. Покрыто `tests/equipment_comparison.gd`.
- Фильтры и сортировка инвентаря реализованы; см. `tests/inventory_filter_sort.gd`.
- Добавлена первая дополнительная синергия «Огненная буря»: попадание цепной молнии по горящей цели наносит +4 lightning damage и распространяет половину исходного burn damage (округление вверх) на врагов в радиусе 64 px на срок до 1 секунды. Источник сохраняет горение; на одном враге повторная синергия ограничена cooldown 0,75 с. Код — `SlimeEnemy.react_to_spell()`; тест — `tests/elemental_synergies.gd`; описание добавлено в `data/spells.json`.
- Следом: ручная проверка визуала/баланса «Огненной бури», затем синергия льда и молнии и эффекты комбинаций экипировки.

Приоритет C — визуал и релиз:
- После фиксации масштаба и UX заменить отклонённые технические PNG на детализированный fantasy pixel art.
- Добавить анимации персонажей, врагов, магии, окружения, звуки и музыку.
- Настроить экспорт Windows и полноценное тестирование прохождения.

## 8. Рабочий процесс

- Работать небольшими вертикальными срезами.
- Предпочитать отдельные feature-ветки и PR в `main`.
- В описании PR перечислять изменения, тесты и ограничения.
- Не удалять исходники или контент без проверки ссылок и использования.
- После каждого завершённого шага обновлять ROADMAP и HANDOFF.
- Пользователь тестирует Windows-сборки; после стабилизации настроить экспорт и GitHub Actions для EXE.
- Не заявлять о готовом EXE, пока он действительно не собран и не опубликован.

## 9. Текущий Git-контекст на 2026-11-02

- Основная ветка: main; рабочая ветка: feat/godot-rpg-foundation.
- Последний функциональный коммит: `88ac4c08f30bc668fd2a259991bbd60e6044649a` — синергия «Огненная буря».
- Архитектурные коммиты: `77c014cddf5d29921cfe7a414b005d9b98f00b1c` (централизация проверки сохранений), `7273003c4b3e9cd46dfb8ef5b16a2f5f66a71a72` (GameCatalogs и тест загрузки каталогов).
- Документационная уборка: `6dfc53e4849f70ca3b596c14a27117d711880613`, `6a1d1cdf7a8088bb66b3b371d92d9820ecdfaf3d`, `808591d4ba399beacc1939cc13d3d24a0b6461f3`.
- На последнем кодовом коммите ветка опережала `main` на 114 коммитов и не отставала (behind 0). Перед следующей работой обязательно получи live HEAD.
- PR #1: “feat: playable Skyward Tales RPG foundation and progression”; открыт, Draft, mergeable=true; 114 коммитов и 80 файлов на последнем кодовом коммите. Не сливать до ручной проверки UX/баланса в оконном режиме и подтверждения владельца.
- Godot 4.7.2 CI на GameCatalogs-коммите: runs 41470947947 и 41470957999 — оба success, 43/43 шага, включая новый `tests/game_catalogs.gd`.
- Неиспользуемый scripts/sprite_archive.gd удалён после проверки всех 54 GDScript-файлов, сцен и project.godot: ссылок не осталось.
- Поиск issues не вернул открытых задач; PR #1 — единственный найденный pull request.
- Не переписывать историю, не создавать второй PR для того же инкремента и не сливать Draft без ручного QA.

## Правило истинных восьми ракурсов

Для всех игровых врагов обязателен **true 8-direction** (НЕ front-biased). Строки атласа: down, down-right, right, up-right, up, up-left, left, down-left. Направление up показывает зад без глаз/рта; диагонали up-left/up-right показывают задний профиль. Для летающих и округлых врагов силуэт должен правдоподобно меняться по сторонам. Исключение для симметричных эффектов магии, где внешняя симметрия естественна. Первая реализация — `assets/sprites/enemies/forest_slime_true8.png`, но её графика пока техническая и потребует художественной полировки.

## Обновление: самостоятельные PNG, без ZIP

Герой, слизень и огненный шар находятся в GitHub как отдельные RGBA PNG (128×256, 4×8 кадров по 32×32): assets/sprites/characters/hero_8dir_walk.png, assets/sprites/enemies/forest_slime_true8.png, assets/sprites/magic/fireball_8dir.png. Runtime загружает их напрямую через res://; ZIP-архив и распаковка при старте не используются. scripts/sprite_archive.gd уже удалён в коммите 6296584 после проверки ссылок; не восстанавливать его без осознанного возврата ZIP-пайплайна. Эти PNG нужны текущему runtime, поэтому не удалять их до интеграции и проверки замен. Их качество отклонено как финальный арт: это временные технические атласы, которые нужно заменить после ручной проверки пропорций и UX.

## GitHub Actions / проверка (актуально на 2026-11-02)

.github/workflows/godot-validation.yml выполняет проверку PNG через tools/validate_sprite_atlases.py, headless-импорт Godot 4.7.2, все 35 файлов tests/*.gd и smoke-запуск сцены на 120 кадров. На HEAD 4c822b2c9f5aa424aafc9f407ea49651f7d592e8 оба последних workflow run (41460337752, 41460328908) завершились успешно; каждый job прошёл 42/42 шага. CI подтверждает импорт, автоматические регрессии и headless smoke, но не доказывает визуальную корректность, читаемость интерфейса, баланс, управление в окне или полное прохождение квестов. Эти проверки остаются ручными.

## Совместимость Godot 4.7 (1 ноября 2026)

Пользователь использует Godot 4.7. Ошибка `scripts/world.gd:14 Cannot infer the type of variation` исправлена явной аннотацией `var variation: int = absi(...) % 7`. В `scripts/directional_sprite.gd` аналогично типизирован `octant`. Проект отмечает features=4.7, а `.github/workflows/godot-validation.yml` использует `barichello/godot-ci:4.7.2`. Следующему ИИ обязательно проверить статус нового CI и исправить любые дополнительные ошибки парсинга именно в Godot 4.7; успешный тест под 4.3 больше не считать достаточным.

## Важнейшая обратная связь пользователя (2026-11-01)

Пользователь сообщил: игра запускается в Godot 4.7, но магия по ЛКМ не работала, а качество всех текущих пиксельных PNG категорически отвергнуто. **Не выдавать эти изображения за финальную графику и не продолжать их как утверждённый стиль.** Они лишь временные технические заглушки. Желаемый результат — детализированный, профессиональный fantasy pixel art, похожий на ранее выбранный пользователем референс. Использовать прозрачные PNG, настоящие восемь ракурсов с задними видами, оригинальные исходники и анимации. Перед интеграцией художественно проверить кадры в масштабе игры.

В `scripts/main.gd` события кастования перенесены из `_unhandled_input` в `_input`; в `scripts/hud.gd` визуальные Controls используют MOUSE_FILTER_IGNORE, чтобы не поглощать клики. В `scripts/player.gd` введено восстановление маны 4/сек. Требуется проверить это именно в окне Godot 4.7 с движением, кастом, попаданием по слизню, паузой и диалогом; headless smoke test сам по себе не проверяет интерактивность.

## Регрессионная проверка магии

На 2026-11-01 добавлен `tests/magic_smoke.gd` (SceneTree integration test). Проверка запускается CI после импорта Godot 4.7.2 с `godot --headless --path . --script res://tests/magic_smoke.gd`. Тест отправляет реальный `InputEventMouseButton` в главный скрипт, проверяет расход маны, появление `MagicBolt`, загрузку PNG, направления героя и урон слизню через коллизионный callback. Следующему ИИ нужно сверить результаты CI на коммите `99e8be4d5c069bc1354ae57a7eb02f93aa92645c`; не считать тест пройденным до подтверждённого зелёного прогона. Тест не заменяет визуальную QA и не проверяет физическое пересечение снаряда в движении.

## ТЕКУЩИЙ ПРИОРИТЕТ ВЛАДЕЛЬЦА (01.11.2026): GAMEPLAY FIRST

Пользователь уточнил: **не стоит сильно заморачиваться над графикой сейчас**. Главная цель — механики и надёжная работа игры. НЕ тратить ближайшие итерации на генерацию/перерисовку огромных атласов, не подменять разработку интерфейса художественными постерами. Нынешние PNG могут временно оставаться; это не отменяет их ранее отклонённого качества как финальных ассетов.

Следующему ИИ: улучшать механику по порядку из ROADMAP: бой и тестирование физического попадания/коллизий, нормальные враги, заклинания, лут, инвентарь, квесты, сохранения. Изменять код в небольших PR-коммитах, проверять на Godot 4.7.2. **Интеграционный тест магии успешно прошёл** в GitHub Actions run 41300161195, однако он не проверяет физическое столкновение при полёте и реальное восприятие игры пользователем. Не заявлять о полном прохождении без ручной проверки. Задача с красивым артом остаётся запланированной для позднего этапа.

## Механика физических препятствий — 2026-11-01

`world.gd` создаёт StaticBody2D (layer 4) на границах карты, у стволов деревьев, в зоне пруда и руин. Список TREE_POSITIONS общий для отрисовки и физики. Герой: mask=6 (враги 2 + мир 4), слизень: mask=5 (игрок 1 + мир 4), fireball: mask=6 (враги 2 + мир 4). Снаряд удаляется при столкновении со StaticBody2D. Добавлен тест `tests/world_collisions.gd` в CI; проверить его результат. Важное ограничение: слизни пока не умеют обходить стены — будущий шаг steering/pathfinding. Не отмечать ручное тестирование выполненным до проверки пользователем.

## AI слизня (текущий этап)

`SlimeEnemy` поддерживает состояния `IDLE`, `CHASE`, `RETURN`, `RETREAT`: обнаруживает игрока на 180 px, прекращает преследование после 270 px, возвращается к точке появления, отступает при здоровье <=25%. В режиме погони делает пробы лучами по слою статического мира 4 для грубого обхода препятствий. `home_position` захватывается в `_ready()`, поэтому позицию слизня теперь устанавливать **до** `add_child`. Это базовая система steering, не полноценный AStar; её необходимо проверить в игре и при необходимости заменить навигацией. Не объявлять AI проверенным без CI и ручного теста.

## Новое заклинание: ледяная стрела

`main.gd`: `selected_spell_id`, метод `select_spell`, клавиши `1` (fireball) и `2` (frostbolt), `ЛКМ` стреляет выбранной магией. `data/spells.json` содержит независимые стоимость маны/урон/скорость/cooldown и параметры замедления. `MagicBolt.configure_effect` настраивает визуальный оттенок и дебафф; `SlimeEnemy.apply_slow` накладывает 60% замедление на 2.5 секунды, таймер обновляется в `_physics_process`. Визуал намеренно временный. Протестировать в Godot 4.7.2; следующая задача — дополнительный боевой тест ледяной стрелы и проверка эффектов при столкновении.

## Новая механика: цепная молния

Клавиша 3 выбирает `chain_lightning` из `data/spells.json`. Основной снаряд — `MagicBolt`; при попадании вызывает `_apply_chain_lightning(first_target)`, выбирая ближайшую ещё не поражённую цель не далее 150 px от **предыдущей**. Максимум 2 последующих прыжка, урон каждый раз ×0.7, визуальный `Line2D` исчезает через 0.14 s. При необходимости доработать проверку линии видимости; нынешняя цепь проходит через стены. Обязательно смотреть результаты CI.

## Боевой интерфейс

В `scripts/hud.gd` добавлены `spell_label`, `spell_cooldown_bar` и `update_spell(name, mana_cost, mana, remaining, total)`. В `scripts/main.gd` введены `cast_cooldown_total`, `_update_spell_hud()` вызывается после смены магии, после каста и каждый кадр. HUD показывает имя выбранной магии, стоимость MP, текст отката и полосу готовности; все новые Controls имеют MOUSE_FILTER_IGNORE. Тестировать Godot 4.7.2; UI остаётся временным и приоритет ниже игровых механик.

## Добыча и зелья

В `scripts/loot.gd` WorldLoot — подбираемый предмет с сигналом `collected`. При убийстве слизня `main.gd` создаёт зелье в месте появления врага (временная логика; точное место смерти надо поправить позже). `PlayerCharacter.inventory` — словарь item_id → количество; `add_item` и `use_item` проверяют количество и лимиты восстановления. Q: health_potion +35 HP; R: mana_potion +25 MP. Количество отображает `GameHud.update_status`. Никаких сохранений инвентаря пока нет. Следующий ИИ должен протестировать в Godot 4.7, проверить что зелья не расходуются при полном ресурсе и создать регрессионные тесты.

## Окно сумки

С 2026-11-01: `GameHud` создает интерактивную `inventory_panel`, кнопку на каждый вид зелья, показывает имя/количество/эффект и выдаёт сигнал `inventory_use_requested`. `main.gd` открывает сумку по `I`, вызывает `_on_inventory_use` и отключает ЛКМ-каст при открытой панели. `stats_changed` вызывает обновление HUD и панели. Основной фон HUD остаётся `MOUSE_FILTER_IGNORE`; сама сумка перехватывает клики, когда видима. Ручной QA пока обязателен.

## Первый набор экипировки

`PlayerCharacter.equipment = {weapon, armor, amulet}`. `equip_item` проверяет наличие предмета, переносит в слот; `apprentice_staff` +5 урона ко всем заклинаниям (`main.gd`); `leather_armor` -4 урона (`player.take_damage`), минимум 1 от удара; `mana_amulet` +20 к максимальной мане. Окно `GameHud` показывает три новых предмета и даёт надеть кликом. Первые 3 слизня дают демонстрационные предметы. Известное ограничение: обмен и снятие амулета пока не вычитают его бонус; до реализации полноценного снятия не менять логику экипировки амулета. Приоритет — интеграционный тест на Godot 4.7.2 и проверка в игре.

## Снятие и замена экипировки (новый этап)

В `PlayerCharacter` добавлен `unequip_slot(slot)` и переработан `equip_item(item_id)`: бонус +20 max_mana снимается при удалении амулета, текущая мана ограничивается новым максимумом. `GameHud` теперь содержит `equipment_list` с кнопками для снятия каждого предмета, сигнал `inventory_unequip_requested`; `main.gd` направляет действие в игрока. Приоритет — дождаться CI, проверить ручное управление. Старое упоминание о проблеме со снятием амулета выше устарело.

## Сохранения F6/F9 (01.11.2026)

`SaveSystem` в `scripts/save_system.gd` сериализует словарь в `user://skyward_tales_save.json`, формат v1. `main.gd`: `make_save_snapshot`, `save_game`, `load_game`, `restore_save_snapshot`; сохраняются игрок (в том числе прямые max_mana + equipment, без повторного начисления бонусов), квест, позиции/HP живых слизней, доступные листья, предметы на земле, количество убийств, выбранная магия. F6 — сохранить, F9 — загрузить; не загружать автоматически, чтобы тесты продолжали начинаться с чистого состояния. Ручной QA: сохранить, закрыть игру, снова запустить и нажать F9. Текущий формат экспериментальный, без автосейва и защиты от обрыва записи. Следующему ИИ: проверить CI, добавить атомарность и UX кнопок сохранения в меню.

## Главное меню и пауза

`project.godot` теперь начинает с `scenes/title_menu.tscn` (`scripts/title_menu.gd`). Кнопка «Продолжить» доступна, только если `SaveSystem.load_snapshot()` вернул валидный словарь; перед сменой сцены устанавливается метаданные `SceneTree.skyward_continue`. `main.gd:_ready()` проверяет флаг, снимает и вызывает `load_game`; обычное создание сцены тестами по-прежнему начинает свежую игру. `hud.gd` обрабатывает Esc, включает `pause_panel` в CanvasLayer с process_mode ALWAYS и кнопками сохранения, загрузки, главного меню. При возврате в меню пауза снимается. Нужно CI и ручной QA; настройки пока не реализованы.

## Второй регион: Зачарованный лес (2026-11-01)

В `scripts/world.gd` добавлен `configure_region(region_id)`, палитра/геометрия/коллизии для `moonlit_grove`. `scripts/region_gate.gd` — интерактивный переход; в `main.gd` есть `current_region`, `_set_region`, `_populate_region`, `_clear_region_actors`. Проход в лес закрыт до завершения `moonleaf_gathering`. В лесу хранительница Илара запускает `grove_spirits`, нужно собрать три `spirit_blossom`, затем получить 90 XP и 50 золота. `scripts/forest_wolf.gd` — отдельный класс врага на базе SlimeEnemy с 48 HP, 56 speed, 24 XP и большим радиусом обнаружения; пока это placeholder reskin слизня, НЕ финальный волк. Save snapshot содержит `world.region` и id/name трав; загрузка переключает регион и восстанавливает популяцию. Проверить CI/ручной QA. При дальнейшем развитии разделить мир на сцены регионов и заменить временный визуал волка настоящим 8-way спрайтом.


## Лесной волк: телеграфируемый выпад (2026-11-01)

В `scripts/enemy.gd` общая модель ближней атаки настраивается параметрами `attack_damage`, `attack_range`, `attack_cooldown_duration`. Для врагов с `attack_windup_duration`/`attack_lunge_duration` доступна последовательность `WINDUP -> LUNGE -> NONE`: направление фиксируется при предупреждении, рывок двигает врага через `move_and_slide`, попадание проверяется радиусом и может сработать один раз за атаку. Базовый слизень сохраняет контактную атаку. `ForestWolf` задаёт 12 урона, дальность начала атаки 74 px, предупреждение 0.42 s, рывок 0.22 s со скоростью 270 px/s, hit radius 20 px и cooldown 1.8 s. Временный оттенок сохраняется после атаки через `base_visual_tint`. `tests/wolf_pounce.gd` использует реальную сцену игрока и отдельный физический драйвер, проверяет обнаружение, предупреждение, один удар и cooldown. Оба CI запуска на коммите `44806349486a0ca3caa789d15b196d3a54d612dc` успешно прошли все этапы, включая этот тест: run `41314631167` и `41314628206`. Визуал волка по-прежнему placeholder, финальный 8-way арт отложен до стабилизации механик. Ручная проверка уклонения и столкновений выпада с препятствиями ещё не выполнена.


## Steering с кратковременным обходом препятствий

В `scripts/enemy.gd` `_has_world_obstacle` проверяет статический world layer 4; `_avoid_world_obstacles(desired, delta)` ищет обход под углами 90°, 63°, 135° и сохраняет найденное направление на 0.35 s, уменьшая колебания у стволов. Если ни одно направление не свободно, возвращает ZERO. Логика общая для SlimeEnemy и ForestWolf; это НЕ гарантированная навигация вокруг сложных стен. `tests/enemy_steering.gd` включён в GitHub Actions Godot 4.7.2. Следующим ИИ проверить CI и ручной QA.

## Лесной шаман

`ForestShaman` наследует SlimeEnemy, но переопределяет `_physics_process`: держится на расстоянии, отступает ниже 90px и стреляет в пределах 240px раз в 1.7s при отсутствии препятствий world layer 4. `EnemyMagicOrb` — отдельный Area2D на collision_mask 5 (player 1 + world 4), урон 9, блокировка повторного попадания. В `main.gd` шаман появляется в moonlit_grove, удаляется при смене региона, сохраняется с `kind=shaman` и восстанавливается через `_spawn_shaman`. Текущий спрайт временно перекрашен. `tests/forest_shaman.gd` запускается через GitHub Actions Godot 4.7.2; обязательно сверить CI.

## Мини-босс Древний хранитель

`GroveGuardian` extends ForestShaman (`scripts/grove_guardian.gd`), 160 HP. Фаза 1: одиночная сфера, фаза 2 при <= 50% HP: тройной веер, скорость и частота атаки повышаются. Появляется в `moonlit_grove` после завершения `grove_spirits`; убитый босс даёт 100 XP + 100 золота, предмет `ancient_relic` (нерасходуемый трофей). `main.gd` сохраняет `world.guardian_defeated` и `kind=guardian`. Ручной QA и CI ещё нужны.

## Боевой рывок героя

`PlayerCharacter.start_dodge()` по Shift (обработка `main.gd`) запускает 0,20 s движение на скорости 260 px/s по WASD либо `facing`, с `move_and_slide`, invulnerability в `take_damage` и cooldown 0,85s. В `project.godot` добавлена карта действия `dodge`, текущий ввод через KEY_SHIFT. Спрайт временно подсвечивается голубым. `tests/player_dodge.gd` включён в CI; проверить результат, затем вручную испытать в бою.

## Индикатор рывка / багфикc сумки

`GameHud.update_dodge(remaining, cooldown, dodging)` обновляет под полосой магии новую компактную панель SHIFT, а `main.gd._process` передаёт туда актуальные таймеры игрока. Для `ancient_relic` добавлено название в словарь `names` внутри `GameHud.refresh_inventory`; иначе наличие трофея приводило к обращению к отсутствующему ключу и ломало перерисовку сумки. CI тест `tests/dodge_hud.gd` проверяет готовность/откат и русское название. Требуется ручной UI QA и проверка CI Godot 4.7.2.

## Боевой feedback

`scripts/enemy_combat_feedback.gd` — общий Node2D с полосой HP, числами урона через draw_string и кольцом предупреждения. `SlimeEnemy` создаёт feedback в `_ready`, обновляет при получении урона и состояниях WINDUP/LUNGE. `GroveGuardian` отмечает elite и сигнализирует о начале второй фазы. Добавлен `tests/combat_feedback.gd` в CI. Графика временная, проверить визуально.

## Смерть героя / Game Over

`PlayerCharacter.died` испускается однократно при переходе HP > 0 к 0. `main.gd._on_player_died` устанавливает `game_over`, показывает HUD defeat и ставит SceneTree на паузу; HUD работает в PROCESS_MODE_ALWAYS. `GameHud` предоставляет сигналы `defeat_restart_requested`, `defeat_load_requested`, `defeat_menu_requested`. Restart загружает `scenes/main.tscn`, меню ведёт в title, load снимает паузу только при наличии валидного сейва и успешном restore. Сохранение после смерти запрещено, старые сейвы с 0 HP при загрузке восстанавливаются с 1 HP. `tests/death_flow.gd` покрывает смерть, блокировку save, recovery load и отсутствие сейва; тест включён в Godot 4.7.2 CI. Два полных запуска на коммите `eeee04228ac283fd45f13c8b99438f1a72b894b5` завершились SUCCESS (`41320111256`, `41320115054`). Остался ручной UX QA.

## Прокачка: выбор талантов

`data/talents.json` содержит 6 талантов (max rank 3). `PlayerCharacter.talents` хранит ранги; `apply_talent(id)` применяет эффекты. `get_spell_bonus(spell_id)` учитывает общий Arcane Power +3/rank и school bonuses Frost Lore / Storm Focus +3/rank; `get_cooldown_multiplier()` учитывает Swift Cast (8%/rank); Vitality даёт +15 max HP/heal, Mana Well +12 max MP/refill. `main.gd` собирает очередь `pending_level_choices` (важно при получении нескольких уровней одним XP событием), выбирает три случайных незакрытых таланта и ставит игру на паузу. HUD выдаёт сигнал `talent_selected`; после каждого выбора открывает следующий уровень или снимает паузу. Сейв содержит `player.talents`, старые сейвы без этого поля продолжают работать. `tests/level_up_talents.gd` проверяет окно, три выбора, применение, паузу и сохранение. Ручной UX QA ещё нужен.


Talent progression is implemented in commit `4eeaa5374ea5a6bc454b13558f48bf1e8d7cb733`; Godot 4.7.2 CI run `41321517591` passed. Manual UI and balance QA remains.


## Fire burning DoT

`data/spells.json` defines `fireball.burn_damage=3`, `burn_duration=2.0`. `MagicBolt.configure_burning()` injects effect, and `_on_body_entered` calls `apply_burning()` only for surviving enemies. `SlimeEnemy` owns `burn_time_left`, `burn_tick_timer`, `burn_damage`; `_update_burning(delta)` ticks every 0.5 seconds, refreshes on repeat without stacking, and uses `take_damage` for regular defeat signals. `take_damage` ignores already-dead enemies to prevent duplicate rewards. `main.gd` includes burn fields per enemy in save/restore. `tests/fire_burning.gd` is in Godot 4.7.2 CI; check run and manually verify balance. Art is still temporary.


## Elemental reactions

`SlimeEnemy.react_to_spell(spell_id)` consumes a pre-existing status: `frostbolt` on burning enemy consumes burn and deals 8 bonus damage before a fresh slow is applied; `chain_lightning` on slowed enemy consumes slow and deals 6 extra damage. `MagicBolt` invokes it after direct hit on survivors and also on every lightning chain hop. No reaction should apply to already defeated enemies. `tests/elemental_reactions.gd` is in CI.

## Синергия «Огненная буря»

`chain_lightning` hitting a burning enemy triggers a 4-point lightning bonus and spreads weakened burning to other living enemies within 64 px. Spread damage is half the source burn damage (rounded up), duration is at most 1 second, and the source keeps its original burn. A per-enemy 0.75-second cooldown prevents rapid repeat bursts. The reaction label is shown through `EnemyCombatFeedback`; `data/spells.json` documents the interaction. Test `tests/elemental_synergies.gd` covers projectile hit, bonus damage, source status preservation, radius, spread strength/duration, reaction feedback, cooldown and cooldown recovery. Godot 4.7.2 CI runs 41459686853 and 41459696357 both passed (42/42 job steps). Manual visual/balance QA is still required.


## Elemental status visuals

`EnemyCombatFeedback` renders orange embers when burning, an icy ring during slow, and short localized labels for steam and electric reactions. `SlimeEnemy._refresh_elemental_feedback` synchronizes statuses after application, expiration and reactions. `ForestShaman` now calls `_update_burning` and feedback refresh in its overridden physics loop, so shamans and guardian suffer DoT consistently. CI test: `tests/elemental_visuals.gd`. Manual visual QA outstanding.


## Elemental resistances

`SlimeEnemy.elemental_multipliers` maps fire/ice/lightning to factors (clamped 0.25..2), used by `take_elemental_damage` for bolts, DoT and reaction damage. `apply_burning` and `apply_slow` also scale status duration. Wolves weak to fire (1.25) and resist ice (0.8). Shamans resist fire (0.75) and weak to lightning (1.3); Guardian overrides with fire 0.65, ice 1.25, lightning 1.0. `MagicBolt` determines damage element from spell ID and applies resistance both on first hit and chain hops; physical hits unchanged. Test in `tests/elemental_resistances.gd`; watch CI and manual balance.


## Bestiary

`data/bestiary.json` contains Russian names, habitats, attacks, weaknesses and resistances. `main.gd` discovers enemies within 180 px in `_process`, stores `discovered_enemies` in world save snapshot, and toggles `GameHud.toggle_bestiary` with K. Undiscovered entries show `???`, known entries show details; inventory is closed when bestiary opens. `tests/bestiary.gd` added to CI. Confirm CI and manual 640x360 layout.


## Мини-карта

`scripts/world_minimap.gd` — самостоятельный `Control` без внешней графики. Отрисовывает текущий регион (внутренние координаты 1280×864, виджет 132×108 в правом верхнем углу), линию маршрута, положение героя и маркеры известных NPC/переходов. `GameHud.minimap` создаётся при инициализации HUD. `main.gd._update_minimap` обнаруживает NPC и RegionGate в радиусе 150 px и обновляет `discovered_landmarks` по регионам. Сохранение: `world.landmarks`, загрузка обратно совместима с предыдущими файлами. CI тест `tests/minimap.gd` проверяет координаты, обнаружение, save/restore и переключение регионов; требуется ручной QA.


## Full region map

`GameHud.open_world_map(region,hero,landmarks,quest)` presents a scaled `WorldMinimap` inside a 452×345 modal with quest summary. `M` from `main.gd` opens it, closing bestiary or inventory first; HUD processes M during pause and closes it with `close_world_map()` to resume. No unvisited POIs revealed: the existing `discovered_landmarks` drives both map views. Tests: `tests/world_map.gd`, CI updated. Manual 640×360 UX QA remains.


## Treasure chests

`TreasureChest` (`scripts/treasure_chest.gd`) is a simple interactable node with `opened` signal and one-shot state. `main.gd` defines four static chest placements and rewards in two regions; `opened_chests` persists in `world.opened_chests`, restored before `_set_region` repopulates actors; old saves default to unopened. Chest state is not encoded as world loot. `tests/treasure_chests.gd` covers one-time reward, save/restore and region transitions. Manual collision and visual placement QA pending.


## Loot rarity

`TreasureChest.roll_bonus(chance)` gives exactly one extra item on open: common 65% `health_potion`, uncommon 28% `mana_amulet`, rare 7% split evenly across `starlight_essence`, `pyromancer_core`, `frost_heart`, and `storm_eye`. Base chest loot is unchanged. `bonus_found(item_id,rarity)` event from chest is handled by `main.gd._on_chest_bonus` and inserts item into inventory. Existing `world.opened_chests` prevents reroll exploitation, even after loading/region changes. `PlayerCharacter.use_item('starlight_essence')` gives permanent +5 max mana; `starlight_essence_used` tracked in player save, and HUD inventory displays it. CI test `tests/loot_rarity.gd` covers chance ranges, one-time extra reward, save/restore and essence. Manual balancing pending.


## Data-driven equipment and elemental relics

`data/equipment.json` is the item definition catalog. `PlayerCharacter._load_equipment_definitions()` loads it at ready; `get_item_definition/name/description` expose metadata. `equipment` now has four slots: weapon, armor, amulet, relic. `equip_item()` reads the slot and stat deltas from data, returns replaced items to inventory, and handles max-mana deltas generically. `get_spell_bonus()` reads wildcard/specific bonuses; `get_burn_damage_bonus()`, `get_slow_duration_bonus()`, and `get_chain_targets_bonus()` feed the projectile setup in `main.gd._cast_spell()`.

Three rare relics are in the chest rare pool: `pyromancer_core` (+4 fireball damage, +1 burn tick), `frost_heart` (+4 frostbolt damage, +0.75s slow), `storm_eye` (+4 chain lightning damage, +1 chain target). The old `starlight_essence` remains in the rare pool and retains its permanent +5 max mana effect. The rare quality chance remains 7%, divided equally among the four rare rewards. HUD now shows four equipment slots and item names/descriptions/rarity. Save restore initializes all four slots and only copies known slot-compatible items, so old saves without `relic` remain compatible. Tests: `tests/equipment.gd`, `tests/equipment_unequip.gd`, `tests/save_load.gd`, `tests/loot_rarity.gd`.


Equipment milestone verification: Godot 4.7.2 workflow run `41443674839` completed successfully (39/39 steps). Automated checks passed for rare reward pool, relic stat effects on projectiles, data-driven catalog/UI, equip/replace/unequip, and save compatibility. Manual visual/balance QA remains with the player.


## 10. Система добычи, экипировки и артефактов — 2026-11-02

- scripts/treasure_chest.gd выдаёт базовую награду и один дополнительный предмет: 65% обычный (зелье здоровья), 28% необычный (амулет маны), 7% редкий.
- Редкая вероятность 7% разделена поровну между starlight_essence, pyromancer_core, frost_heart и storm_eye. Звёздная эссенция навсегда увеличивает максимальную ману на 5; состояние использования сохраняется.
- data/equipment.json — каталог экипировки. Слоты: weapon, armor, amulet, relic. Эффекты: общий/школьный урон, броня, максимальная мана, горение, длительность замедления и число прыжков молнии.
- PlayerCharacter.equip_item() поддерживает замену и возврат предыдущего предмета в инвентарь; снятие экипировки возвращает предмет. Старые сохранения без слота relic совместимы.
- Автотесты: tests/loot_rarity.gd, tests/equipment.gd, tests/equipment_unequip.gd, tests/equipment_data_driven.gd, tests/inventory_filter_sort.gd, tests/equipment_comparison.gd, tests/save_load.gd. Последний подтверждённый CI — run 41449387549 (Godot 4.7.2, success, 40 шагов).
- Выполнено в коммите f42f6eb: HUD показывает только предметы в сумке, распознаёт экипировку по slot из data/equipment.json, поддерживает новые catalog items без ручного списка ID в main.gd, прокручивает длинный список и обновляет его после экипировки/снятия. Регрессия покрыта tests/equipment_data_driven.gd.
- Неиспользуемый scripts/sprite_archive.gd удалён в коммите 6296584 после проверки всех 54 GDScript-файлов, сцен и project.godot — ссылок не осталось.
- Фильтры «Все предметы / Экипировка / Расходники» и сортировка «Порядок / По названию / По редкости» добавлены; редкость сортируется rare → uncommon → common → без редкости. Покрыто `tests/inventory_filter_sort.gd`, шаг включён в `.github/workflows/godot-validation.yml`.
- Сравнение экипировки: при наведении на предмет открывается боковая панель с колонками «Сейчас / Будет» и подписанной разницей. Сравниваются суммарные показатели с учётом остальных слотов и талантов: броня, максимум маны, огненный шар, ледяная стрела, цепная молния, горение, замедление и дополнительные прыжки молнии. Положительная разница зелёная, отрицательная красная.
- `PlayerCharacter.get_equipment_comparison(item_id)` — единая точка расчёта для UI и тестов. Проверка расчётов и hover-сигнала: `tests/equipment_comparison.gd`.
- Следующий UI-инкремент: проверка компоновки панели на реальном 640×360 и расширение эффектов билдов/каталога предметов.

## 11. Правила продолжения

1. Сначала проверить HEAD, PR #1, ROADMAP.md, CI и фактическую структуру.
2. Не повторять уже реализованные сундуки, редкость, экипировку, сохранения и тесты.
3. Изменения делать небольшими, с регрессионным тестом и обновлением двух документов.
4. Godot 4.7.2 CI обязателен; визуальную проверку явно отделять от headless тестов.
5. Не сливать Draft PR #1 без ручного QA и проверки отставания от main.

## 12. Аудит чистоты репозитория — 2026-11-02

Ревизия выполнена на ветке feat/godot-rpg-foundation, исходный HEAD: 4c822b2c9f5aa424aafc9f407ea49651f7d592e8.

### Что проверено
- Полное дерево Git: 78 отслеживаемых файлов; нет закоммиченных .godot/, .import/, .export/, build/dist, EXE/PCK, ZIP-архивов, логов или очевидных временных файлов.
- 21 runtime GDScript, 4 сцены, 5 JSON-каталогов, 3 PNG-атласа, manifest/README/Art Guide и Python-валидатор.
- Все 35 файлов tests/*.gd перечислены в .github/workflows/godot-validation.yml; ни одного теста вне CI и ни одной ссылки CI на отсутствующий тест не найдено.
- Сцены, runtime-скрипты, JSON-данные и три PNG сверены со статическими res://-ссылками, preload/load, наследованием и использованием глобальных классов. Все 21 runtime-скрипт имеют назначение; подтверждённых осиротевших скриптов или ресурсов не найдено.
- .gitignore уже исключает кэш Godot, импорт, export/build/dist, EXE/PCK и файлы IDE/OS. Добавлять широкие правила, которые могут скрыть нужные исходники, не требуется.
- Проверены PR #1 и актуальные CI. На исходном HEAD PR #1 открыт, Draft, mergeable; ветка опережала main на 107 коммитов и не отставала.

### Результат уборки
- Не удалён ни один игровой файл: доказуемого безопасного кандидата на удаление не обнаружено. Не удалять технические PNG только из-за отклонённого качества: они подключены к runtime и нужны до замены.
- Исправлен устаревший раздел assets/ART_GUIDE.md, ошибочно описывавший ZIP-архив и sprite_archive.gd как действующую runtime-зависимость.
- Исправлен устаревший абзац о спрайтах и версии Godot 4.3 в этом документе; теперь зафиксированы прямые PNG-пути и фактическая проверка Godot 4.7.2.
- Исходники, историю Git, лицензии/авторские сведения и пользовательские данные не меняли. Файл LICENSE в текущем дереве отсутствует: не придумывать лицензию для проекта или графики; при добавлении внешних ассетов сохранять исходные лицензии и атрибуцию.

### Проверки и ограничения
- Godot 4.7.2 CI на исходном HEAD: runs 41460337752 и 41460328908, оба success, 42/42 шагов.
- Это статический аудит Git-дерева и зависимостей, а не полноценный visual QA. Не удалять ресурс только по результату grep: динамические обращения и будущие ссылки должны проверяться отдельно.
- Следующий ИИ: получить live HEAD; проверить PR #1 и CI; сохранить все текущие runtime-файлы; продолжить ручной QA на 640×360 и постепенно разделять main.gd/hud.gd без большого rewrite.

## 13. Граница валидации сохранений — 2026-11-02

- Проверка структуры снимка сохранения централизована в `SaveSystem.validate_snapshot(data)`; проверяются словари player/quest/world, inventory/equipment/talents, quest.states и массивы world.enemies/herbs/loot.
- `SaveSystem.load_snapshot()` теперь отклоняет повреждённые вложенные структуры, а `main.gd::restore_save_snapshot()` повторно использует ту же проверку до изменения состояния игры.
- `tests/save_load.gd` дополнен проверками: некорректный inventory не должен менять живое состояние игрока; загрузчик должен отвергать файл с некорректным world.loot.
- Формат сохранения и VERSION не менялись; новые поля не добавлялись, существующие сохранения остаются совместимыми.
- Godot 4.7.2 CI на кодовом коммите `77c014cddf5d29921cfe7a414b005d9b98f00b1c`: runs 41469890189 и 41469878769 — оба success, каждый прошёл 42/42 шага; `tests/save_load.gd` завершился успешно.
- Формат и версия сохранений не менялись. Автоматические проверки подтверждены; ручной запуск/загрузка в оконной сборке остаются непроверенными.
- Следующий шаг: продолжать малые архитектурные выделения, не затрагивая механику без отдельного теста.


## 14. Централизация игровых каталогов — 2026-11-02

- Загрузка трёх словарных каталогов вынесена из `main.gd` в `scripts/game_catalogs.gd` (`GameCatalogs`): бестиарий, таланты и заклинания.
- `main.gd::_ready()` создаёт каталог один раз и передаёт полученные словари существующим системам; идентификаторы и формат JSON не менялись.
- Загрузчик закрывает открытый файл и выдаёт предупреждение, если каталог отсутствует или корневой JSON-тип не является Dictionary.
- Добавлен `tests/game_catalogs.gd` и отдельный шаг GitHub Actions. Проверяются обязательные записи огненного шара, ледяной стрелы, цепной молнии, талантов и бестиария.
- Godot 4.7.2 CI на коммите `7273003c4b3e9cd46dfb8ef5b16a2f5f66a71a72`: runs 41470947947 и 41470957999 — оба success, 43/43 шага; `tests/game_catalogs.gd` прошёл.
- Проверено, что все 36 файлов `tests/*.gd` включены в workflow ровно по одному разу; отсутствующих и лишних ссылок нет.
- Не переводить quests/equipment на новый загрузчик без отдельного теста и обоснования.


## 15. Безопасное выделение форматирования интерфейса — 2026-11-02

- Создан `scripts/inventory_comparison_formatter.gd` (`InventoryComparisonFormatter`), чистые статические методы `value_text()` и `delta_text()`.
- `GameHud._format_comparison_value()` и `_format_comparison_delta()` сохранены как совместимые обёртки. Формирование строк и логика округления не менялись; сигналы и структура UI не менялись.
- Создан `tests/inventory_comparison_formatter.gd`, включён отдельным шагом CI. Проверяет числа, длительность, знаки и делегирование HUD.
- Исходный HEAD до изменения `86a615d62c5fd59818d68ed343935a377d9eddbd`. Получить live HEAD и проверить текущий CI, затем записать результаты в handoff. Draft PR #1 не сливать без ручного QA.
