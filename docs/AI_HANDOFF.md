# AI HANDOFF — Skyward Tales

Последнее обновление: 11 ноября 2026 года — композиция рощ, защита мостов и анимация роста.

**Утверждён один стиль:** подробный пиксельный лесной летающий остров по эталону владельца, чуть более приглушённый дневной свет и тёмный золотой UI. Не генерировать альтернативные варианты. См. docs/ART_DIRECTION.md.

**Первый остров, актуально:** tools/art/island01_polish.py вызывает forest_composition.compose: 17 заданных зон рощ, 114 деревьев вместо прежних 209. Препятствия, тропы, вода, NPC/сундуки/ресурсы, входы башни/штольни, верстаки и будущие участки settlement защищены от новых крон. terrain.tree_variants соответствует terrain.trees; runtime и миникарта используют одинаковые формы: 2 дуба + 2 берёзы. Предыдущая прямоугольная расчистка больше не является источником раскладки. Не возвращать случайное рассыпание деревьев. Проверка воспроизводимости и пиксельных опор — в генераторе ресурсов.

**Мосты и рост:** terrain.bridge_landings=false отключает маленький запечённый дубль на земле Greenreach; WorldBuilder задаёт RegionGate.apron_bridge, чтобы не рисовались ещё одни маленькие перила. Большой мост остаётся в apron. SkyParallax.setup принимает необязательный gates. projected_position проверяет полные мировые габариты острова после параллакса, удерживает его за землёй и вне трёх мостовых коридоров Greenreach. GatherNode показывает отдельные 12-кадровые sprout/growth-атласы дуба/берёзы и vein_growth для stone/iron/copper; _process наследует паузу. Старые сохранения/таймеры сбора совместимы. tools/art/resource_growth_art.py совмещает истощённый камень с готовым по manifest.origin; не масштабировать стадии независимо. tests/forest_presentation.gd проверяет мосты во всём диапазоне камеры, паузу и завершение роста. Контрольный игровой кадр рощи — docs/screenshots/greenreach_grove.jpg.

**Вода в редакторе:** scenes/regions/greenreach_waterfalls.tscn, узел EastLakeSource, ширина 64 вместо 20, высота 160. Камера greenreach: terrain.camera_bottom_margin=148 (ограничено 160, чтобы не показывать пространство вне apron). tests/look_polish.gd обновлён под осознанное новое кадрирование. Он является источником для игры через terrain.waterfall_scene. Общий prefab — scenes/props/island_waterfall.tscn; @tool в IslandWaterfall обновляет ширину, высоту, скорость, оттенок и растворение при редактировании. Show Lip включает обрамление камнями, привязанное к ширине. Есть Animate In Editor; скорость 0 останавливает поток. Текстурная детализация не растягивается вместе с шириной. Список terrain.waterfalls остаётся резервным; при сцене он не создаёт дублей. Руководство: docs/ISLAND01_EDITING.md.

**Проверка сезонов и сборка:** tests/homestead.gd проверяет осеннюю долю и смену всех деревьев зимой относительно фактического числа деревьев сцены, а не старого порога 200. tools/verify_windows_icon.py сравнивает RT_ICON-ресурсы PE со штатным шаблоном Godot, исключая метаданные версии и assets/icon.ico внутри PCK (экспортёр может перекодировать исходный ICO); icoutils больше не нужен. Main всегда упаковывает portable ZIP для Windows/Linux; попытка установки NSIS ограничена минутой и не блокирует эти ZIP. Для tag/release установщик по-прежнему обязателен.

**Проверка:** tests/island_style.gd и tests/waterfall_scene.gd проверяют геометрию, паузу, скорость, инспектор и общую сцену редактора/игры. Workflow Island art review пересобирает графику и делает реальные игровые кадры при дневном свете; полные PNG — docs/screenshots/greenreach_village.png и greenreach_waterfall.png. Компактный preview.jpg — только для просмотра. Полный набор тестов и Windows/Linux-сборка запускаются автоматически после переноса в main; актуальный результат — в GitHub Actions. Художественная приёмка владельцем остаётся отдельной от технических проверок; не объявлять автоматическое точное совпадение только по зелёному CI.

**Фазы удара (этап 22):** `HeroCombat._swing` — удар в замахе (`kind/direction/time/damage`); `sword_slash()/sword_spin()` только начинают замах, попадание делает `finish_swing()` (его же зовут тесты, чтобы не ждать), тикает `_update_swing()` из `_update_sword()`. Константы `WINDUP_*`. Рывок, смерть, `cancel_charge()` и загрузка срывают удар.

**Этап 22 (кратко):** тип врага — мета `kind` (ставит `spawn_enemy`), `SkywardGame.enemy_kind()` читает её, затем ищет скрипт в `ENEMY_SCRIPTS`; загрузчик проверяет `ENEMY_SCRIPTS`, а не `FALLBACK_ENEMY_POSITIONS`. Особые встречи: мета `special_encounter` — не пишутся в сохранение и не удаляются при восстановлении (их ставит `populate()` своей системы); `trial_foe` и `fair_target` тоже не сохраняются. `WorldCollectible.quest_id` сохраняется (`herbs[].quest`). `player.reset_transient()` зовётся при загрузке. Экипировка: надевание не добавляет текущих здоровья/маны. `HeroCombat.wall_between()` — луч по слою 4, считаются только тела с метой `wall` (блокеры подземных стилей). Новые виды узлов `echo_crystal`, `memory_crystal`. CI: тесты падают на `SCRIPT ERROR` в логе; дымовой запуск — `tools/smoke_run.gd` (освобождает звук за несколько кадров до выхода, иначе движок сообщает об утечке потока музыки); оконный `tests/dialogue_click.gd` под xvfb. Локально то же делает `/tmp/claude-0/runclean.sh`. Тест `tests/save_cycle.gd`.

**Этап 21, шаг 12 (кратко):** камера: `SkywardGame.camera_zoom()` (0,75 снаружи, 1,0 под землёй, 1,25 в `INDOORS`, 1,5 при настройке `close_camera`), применяется в `WorldBuilder._apply_camera_limits()`, который теперь вызывается в конце `_set_region` (раньше — только при старте) и центрирует землю меньше экрана. Снимать скриншоты для оценки вида нужно в 1920×1080 (`/tmp/claude-0/shot1080.sh`), а не 1280×720. `scripts/cliff_rim.gd` (`CliffRim`, узел `CliffRim` в мире, z −99; только земли с апроном без `_apron_inner` и стилей day/haven/sky/spires/night; графика `assets/world_hd/cliffs`, `tools/art/cliff_art.py`); при нём нижний предел камеры 78. `GroundShadows.add_cast()` — силуэтные тени (HD-спрайты, не под землёй). Стиль `DAY`: `recolor (0.8, 0.9, 0.78)`, декали цветов ×2. Тест `tests/look_polish.gd`.

**Этап 21, шаг 11 (кратко):** `TowerObject.map_label` — объект-вход/выход попадает в `map_tracker.minimap_markers()` как `gate` с подписью. `SkywardGame.INDOORS` / `is_indoors()` — комнаты домов: музыка `night`, фон `fire`. `TrialTower.BLESSING_CAP = 3`, квадратичная добавка к `health_mult()` после 20-го этажа. Множители боссов: Хозяин цистерны ×14 здоровья и ×1,8 урона, Страж жеоды ×5 здоровья. Оценка баланса Башни (грубая модель без снаряжения): герой 1-го уровня доходит примерно до 4-го этажа, 5-го — до 8–9, 10-го — до 12, 15-го — до 15, 20-го — до 20. Тест `tests/new_places_save.gd` (сохранение/загрузка внутри каждого нового места).

**Этап 21, шаг 10 (кратко):** `scripts/hero_home.gd` (`game.home`): земля `hero_home` (как `guild_lodge`: скрытая, мирная, `art_style: lodge`; `tools/home_layout.py`). `VillageBuildings.use_door("home")` теперь вызывает `home.enter()` (старое меню сна осталось запасным, выбор `home_sleep` работает); постель зовёт `buildings.sleep()`. `TROPHIES` + `earned(id)` — памятные вещи по достижениям других систем; `change_look()` меняет пол героя через `player.set_identity`. Предметы с `"tool": true` не продаются (`MerchantShop.sellable_count`). Тест `tests/hero_home.gd`.

**Этап 21, шаг 9 (кратко):** `scripts/old_adit.gd` (`game.adit`): `ENTRANCE` в `greenreach`, земля `old_adit` (скрытая, стиль `crypt` + `art_style: mine`; раскладка, жилы и враги — `tools/adit_layout.py`). `OldAdit.Cart` — вагонетка между `CART_STOPS` (`ride()`, на время поездки физика героя выключена), `RUBBLE` — два завала (`clear_rubble(i)` требует `copper_pickaxe`; `cleared`), страж — усиленный `golem` (мета `adit_guardian`), сундук `adit_geode`. `tool_bonus(node)` вызывается из `crafting_menu.gd::gather`: кирка +1 к `iron/copper/stone/amethyst`, топор +1 к `wood`. Новые виды узлов `copper`, `amethyst` в `gathering.json` (вид — `GatherNode.staged_art()`), предметы `copper_ore`, `amethyst`, `copper_pickaxe`, `copper_axe`, рецепты `carp_pickaxe`, `carp_axe`. Графика: `tools/art/mine_art.py`; стиль `MINE`. Сохранение: `world.adit`. Тест `tests/old_adit.gd`.

**Этап 21, шаг 8 (кратко):** `scripts/forest_guild.gd` (`game.forestry`): `COTTAGE` в `greenreach`, комната `ROOM` в земле `guild_lodge` (скрытая, мирная, стиль `crypt` + `art_style: lodge`; `tools/lodge_layout.py` также сажает рощу узлов `wood` и расчищает поляну). Вход/выход — `enter()/leave()` (объекты-двери, ворот в данных нет). Стены и мебель — `TowerObject` (`props/lodge_*`), анимированные — через новые поля `TowerObject.sheet/sheet_frames/sheet_fps`; яркость света = альфа `glow`. Лесное дело: хуки в `crafting_menu.gd::gather` (`on_gathered` — бонус и очки, `regrow_factor`, `try_plant` на пне) и `refresh_nodes` (`update_stage`). `GatherNode.stage` (`ready/cut/young`), `staged_art()` — `props/tree_<oak|birch>_<stage>` и `props/vein_<ready|cut>`; такие узлы не бледнеют. Ранги — `RANKS` по `points`. NPC `forester` (Орвин, облик `settler_woodcutter`), выборы `forest_*`. NPC без собственного обработчика, но со своей системой, перечислены в `QuestGivers.is_special()` (иначе разговор не откроется — так был сломан `scout`). Станция `carpentry`, рецепты `carp_*`, предметы `sapling`, `resin`, `planks`, `resin_torch`, `forest_charm`. Графика: `tools/art/guild_art.py`; стиль `LODGE` и `wall_shade` в конвейере земли. Тест `tests/forest_guild.gd`.

**Этап 21, шаг 7 (кратко):** `scripts/village_hens.gd` (`game.hens`; `VillageHens.Hen` — курица-чиби `hen`, двор `YARD`; `count()` = 1 + уровень огорода; яйца — `WorldLoot` предмета `egg`, `eggs_waiting` ≤ `MAX_EGGS`, новые при смене дня). `scripts/scout_trail.gd` (`game.scout`; NPC `scout` в `greenreach`, чиби `scout`; `ROUTES` — три тропы, `route_today()` по дню; `start()`, `reach_flag()`, `time_limit()`, `gold_time()`; выборы `scout_*`; хук в `QuestGivers.talk/marker_for`). `scripts/buff_bar.gd` (`hud.buff_bar`, значки `assets/ui/status/*.png`, соответствие типов — `BuffBar.ICONS`; старый `buff_label` скрыт, но заполняется). Графика: `tools/art/village_life_art.py` (чиби `scout` и `hen` — порядок рядов источника по часовой от севера, переставляется в игровой; сундуки `world_hd/props/chest_<tier>_<state>.png`; значки). Предметы `egg`, `omelette`, рецепт `cook_omelette`. Тест `tests/village_life.gd`.

**Этап 21, шаг 6 (кратко):** `scripts/cistern.gd` (узел `game.cistern`): земля `flooded_cistern` (скрытая, стиль `crypt`, раскладка и ворота у колодца — `tools/cistern_layout.py`, затем `build_hd.py flooded_cistern`). Константы `POOLS` (каналы), `PLATES` (плиты), `BOSS_AT` совпадают с раскладкой. `Cistern.Pool` — вода со столкновением (`flooded`, `drain()`); `press(index)` работает только по порядку (`index == level`); `level` 0..3, `cleared`, `flood_season`, `runs` (входит в id сундуков `cistern_<runs>_*`), `times_cleared`. В `populate()` при `cleared` и другом сезоне цистерна затапливается заново. Хозяин — усиленная жаба (`toad`, мета `cistern_keeper`). Новое в конвейере графики: `terrain.art_style` (здесь `cistern`) выбирает стиль рисования земли отдельно от игрового `style`; стиль `CISTERN` в `tools/art/hd/styles.py`. Декор — `TowerObject` с `props/cistern_*` (`tools/art/cistern_art.py`). Сохранение: `world.cistern`. Котёл кухни теперь на (748, 744). Тест `tests/cistern.gd`.

**Этап 21, шаг 5 (кратко):** `scripts/trial_tower.gd` (узел `game.trials`): `GATE` — врата в `greenreach`, земля `trial_tower` (скрытая, стиль `crypt`, один зал; раскладка — `tools/tower_layout.py`, затем `build_hd.py trial_tower`). Состояния `idle → fight → cleared`; `pull_lever()`, `open_coffer()`, `open_altar()`/`bless(id)`, `climb()`, `enter(floor)`, `end_run()`; `on_fall()` вызывается первым в `main._on_player_died()` и отменяет смерть. Сила врагов — `health_mult()/damage_mult()` от этажа, состав — `TIERS`, правила — `RULES`, благословения — `BLESSINGS` (баффы игрока `power/armor/speed/crit/regen` на 99999 с, снимаются в `end_run`). Чекпоинт `checkpoint` (кратен 5), рекорд `best`, валюта — предмет `trial_seal`, призы — `PRIZES`. Выборы диалога `trial_*` (через `npc_dialogues`). Объекты — `scripts/tower_object.gd` (`TowerObject`: art из `props/tower_*`, `label` → интерактив, группа `region_actor`). Графика: `tools/art/tower_art.py`. Сохранение: `world.trials`. Тест `tests/trial_tower.gd`.

**Этап 21, шаг 4 (кратко):** `scripts/seasons.gd` (узел `game.seasons`; `Seasons.season_of(day)`, `LENGTH = 4`, порядок summer/autumn/winter/spring; `here()` — стили `day`/`haven`; `apply()` меняет текстуры деревьев с метой `season_tree` (ставит `world.gd`), строит узел `SeasonLayer` в мире: вуаль z −99, детали z −97, частицы). Подпись сезона — `WorldMinimap.season_label` (вместо уровня земли). Огород: `farm.gd` — лотки теплицы это грядки с индексами от `TRAY_FIRST = 6` (`tray_count()`, `is_tray()`, `usable()`, `open_greenhouse()`, выборы `farm_tray:<i>`), сезонные правила в `growth_days/plant/harvest`; `farm_bed.gd` рисует спрайты `props/farm_soil(_wet)`, `props/crop_<wheat|carrot|berry>_<0..2>` (`Farm.CROP_ART`), травы — кодом. Постройки `mill` и `greenhouse` — в `data/settlement.json` (обычные здания с `position`/`door`; двери — `VillageBuildings.use_door`), колесо — `scripts/mill_wheel.gd`. Станция `mill` в `gathering.json → stations`, рецепты `mill_flour`, `cook_bread_flour`, `cook_carrot_pie`; предметы `flour`, `carrot`, `seed_carrot`, `carrot_pie` (бафф `crit` учитывается в `player.get_crit_chance()`). Графика: `tools/art/homestead_art.py` (из `assets/New Sprites`), иконки — `tools/art/icons.py`. Котёл кухни переехал на (700, 740). Тест `tests/homestead.gd`.

**Этап 21, шаг 3 (кратко):** `scripts/sky_parallax.gd` (`SkyParallax.setup(map_size, region_id, style)`, создаётся в `world.gd::_add_apron()`, z −109; `items` — словари node/base/depth/drift; острова расставлены по отрезкам кромки слева/справа/сверху в 54–92 px от края — камера видит ~110 px за край; стили marsh/ash/rift без островов). Картинки `assets/world_hd/sky/*.png` вырезаны из `assets/New Sprites` (sky_harbor/parallax). Мост в `tools/art/hd/apron.py::_bridge` — `new:hd/redrawn/islands/rope_bridge.png` (после правки — `build_hd.py`). Кукла героя: `inventory_window.gd::_portrait_region()` (клетка = высота листа / 8; HD — 128 px, линейный фильтр). Подписи пустых слотов — `EquipSlot.SHORT`. Тест `tests/sky_parallax.gd`.

Точка входа для следующего разработчика (человека или ИИ). Прочитай этот файл, затем `docs/ROADMAP.md` (дорожная карта, согласованная с владельцем), `docs/STORY.md` (сюжет) и `assets/ART_GUIDE.md`. История шагов — в `git log` (сообщения коммитов подробные).

---

## 0. Начни отсюда (5 минут)

1. `git log --oneline -15` — что делалось последним.
2. Прогони тесты (раздел 5). Все должны быть зелёными. Если нет — сначала чини.
3. Спроси владельца, что он увидел в окне игры: сам он запускает Godot 4.7 на Windows, ИИ — только headless + скриншоты через Xvfb.
4. Работай маленькими коммитами прямо в `main` (владелец так решил). После каждого коммита — тесты; после пуша — проверь GitHub Actions.

Ветрохвост — обычный противник на восточной тропе Небесного острова. `scripts/windtail.gd` использует общий рывок противников и запускает отдельный шестикадровый эффект. Игровые PNG лежат в `assets/sprites/enemies/windtail_8dir.png` (4×8, ячейка 48×48) и `assets/sprites/magic/windtail_dash_vfx.png` (6×1, ячейка 96×96). Встреча и награда описаны в `data/regions.json` и `data/drops.json`.

На Небесном острове причал размечен в `data/regions.json`. Шесть объектов `decor_harbor_*` используют обычные HD-спрайты мира и препятствия для навигации. У `sky_ship_vetrokryl.png` точка опоры из `assets/art_manifest.json` совпадает с концом трапа. Передвижение и меню посадки проверяет `tests/stage16.gd`.

Дальний план Небесного острова задаётся в `terrain.sky_landmarks` и `terrain.sky_clouds` в `data/regions.json`. Игровые текстуры лежат в `assets/world_hd/sky_scenery/`. Ориентиры рисуются между небом и облаками под игровым рельефом. Другие локации используют стандартные облака.

## 1. Проект

Skyward Tales — 2D top-down pixel-art fantasy RPG: исследование, магия, прокачка, квесты, NPC, боссы. Язык игры — **русский**. Владелец (DoctorStrangeSH) — продюсер и тестировщик; ИИ — технический лид, сам принимает инженерные решения.

- Godot **4.7.2**, GDScript, renderer GL Compatibility.
- Внутреннее разрешение 640×360, окно 1280×720, nearest filtering, 1 пиксель мира = 1 пиксель вьюпорта.
- Репозиторий: https://github.com/DoctorStrangeSH/Skyward-Tales (`main`). Ветка `feat/godot-rpg-foundation` устарела — всё уже в `main`.

## 2. Приоритеты владельца

1. **Сначала геймплей и надёжность**, но графика тоже важна: владелец хочет «красиво, как Sea of Stars и похожие популярные игры».
2. Для арта, создаваемого `tools/art/`, менять генератор и пересобирать PNG. Атласы Ветрохвоста подготовлены отдельно. Арт оригинальный, ничего не копировать из чужих игр.
3. Настоящие 8 ракурсов (спина без лица), свет сверху-слева, цветной (не чёрный) контур.
4. Не заявлять о ручной проверке, если игра не запускалась в окне. Headless-тесты не проверяют UX, баланс и визуал.
5. Владелец пишет по-русски, коротко; отвечай по-русски, с результатом и скриншотами.

## 3. Что есть в игре (карта прогресса)

```
Зелёные Пределы (день)  ──[квест Элиана]──▶  Зачарованный лес (ночь)  ──[победа над хранителем]──▶  Хрустальные пещеры
 Элиан: «Три лунных листа» (выбор награды)    Илара: «Шёпот леса» → босс-хранитель           Дорн: «Сердце пещеры» (4 эхо-кристалла,
 Мира: «Страницы» (выбор, доверие, тайник)     волки, шаман, духовные цветы                      выбор: 80 золота или Хрустальная линза)
 Бран: торговля, продажа, «Потерянные поставки»                                                  летучие мыши, 2 жилы руды, 2 сундука
 Торен: «Охота на волков» → крафт накидки
 Борин: кузня (усиление накидки, железный посох)
```

Акт II: пещеры ──[main_echo]──▶ Небесный остров (стиль sky): архивариус Ориэн, Стражи-автоматы, 3 кристалла памяти, Мира — спутница ──[main_archive]──▶ Ветреные шпили (стиль spires): 3 руны ветра, Вихревые духи, босс Буревой колосс у сердца бури ──[main_tempest]──▶ Расколотый остров (стиль rift): 4 Тени Вейла, трон разлома, босс Вейл → конец Акта II.

Системы: 3 заклинания (огонь/лёд/молния) с реакциями и синергией, рывок, таланты при уровне, сумка с фильтрами/иконками, 4 слота экипировки, реликвии, доверие NPC, скидки/надбавки торговца, крафт, бестиарий, мини-карта и карта, журнал заданий (J), маркеры над NPC (! ? ✦), ручное и авто-сохранение.

## 4. Архитектура

```
scenes/          title_menu, main (игровая сцена), player, magic_bolt
scripts/
  main.gd                SkywardGame — корень сессии: спавн актёров по данным региона,
                         ввод, бой, лут, таланты, сохранение. Публичные методы и `_on_*`
                         обёртки используются тестами — не переименовывать.
  npc_dialogues.gd       NpcDialogues — все разговоры, маркеры (marker_for), сдача
                         квестов, торговля/продажа, крафт; роутинг выбора (handle_choice).
  quest_pickups.gd       QuestPickups — травы/кристаллы, ящики Брана, страницы Миры, руда.
  region_catalog.gd      RegionCatalog — кэш data/regions.json: имя, цвет карты, стиль,
                         ворота и их условия, какой квест двигают травы региона.
  game_save_state.gd     GameSaveState — снимок игры ⇄ JSON (формат v1, обратная совместимость).
  save_system.gd         Атомарная запись (tmp → rename), автосейв-слот, load_latest().
  world.gd               Земля, деревья, декорации, частицы атмосферы, коллизии.
  world_art.gd           Текстуры из assets/ + точки привязки из art_manifest.json.
  vfx.gd                 Частицы (попадания, гибель, блёстки, уровень), вспышка урона.
  directional_sprite.gd  Атласы 4×8, общий кэш, play_action() для разовых анимаций (каст).
  enemy.gd               SlimeEnemy — база: AI-состояния, steering, стихии, атаки.
    forest_wolf.gd, forest_shaman.gd → grove_guardian.gd, cave_bat.gd
  player.gd, quest_manager.gd, npc_relationships.gd, merchant_shop.gd, crafting_service.gd
  hud.gd + hud_vitals.gd + *_panel.gd + inventory_*.gd — интерфейс по компонентам.
  toast_stack.gd         Уведомления (hud.show_message) и одноразовые советы (hud.show_tip).
  game_settings.gd       Настройки игрока и увиденные советы (user://settings.cfg).
  interact_prompt.gd     Значок «E» над ближайшим объектом.
  story_scene.gd         StoryScene — сюжетные сцены из data/dialogues.json (E листает).
  story_text.gd          StoryText — имя/пол героя: {hero}, {нашёл|нашла} во всех текстах.
  story_director.gd      StoryDirector — цепочка главных заданий (chain), разговор-цели
                         (talk_to в quests.json), сцены при входе в регион (on_enter),
                         финалы боссов (bosses), очередь сцен, сюжетные флаги в сейве.
  echo_warden.gd         Босс «Отголосок» (наследник GroveGuardian; проверять раньше него).
  skill_tree.gd          SkillTree — правила дерева навыков (очки = уровень−1+бонус−потрачено,
                         требования, Печать Неба для 3-го яруса). Ранги — в player.talents.
  skill_tree_panel.gd    Окно дерева (T).
  elite_modifiers.gd     EliteModifiers — элитные враги (apply до add_child, finish после).
  loot_generator.gd      LootGenerator — случайные предметы из data/loot_tables.json; результат —
                         обычное определение предмета, регистрируется в player.generated_items (id gen_NNNN).
  hero_creation_panel.gd Создание героя в главном меню.
shaders/hit_flash.gdshader
data/            ВЕСЬ контент: regions.json, quests.json, equipment.json, spells.json,
                 talents.json, bestiary.json, merchant_stock.json, crafting_recipes.json,
                 npc_relationships.json
assets/          Сгенерированный арт (world/, props/, icons/, sprites/), art_manifest.json
tools/art/       Генератор арта: build.py + palettes, terrain, flora, props, characters,
                 creatures, icons, jsonfmt (компактный JSON для regions.json)
tools/screenshot.gd, tools/validate_sprite_atlases.py
tests/           63 headless-теста, по одному на систему
```

## 5. Как проверять

```bash
godot --headless --path . --editor --import --quit       # обязательно после новых ассетов/классов
for t in tests/*.gd; do HOME=$(mktemp -d) godot --headless --path . --script "res://$t" >/dev/null 2>&1 || echo "FAIL $t"; done
python3 tools/validate_sprite_atlases.py
```

Скриншоты (в контейнере есть Xvfb и Mesa):

```bash
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
  --script res://tools/screenshot.gd -- /tmp/shots crystal_caves 300,400 700,420 [@miner]
```

Godot в контейнере не установлен: скачай `Godot_v4.7.2-stable_linux.x86_64.zip` с GitHub releases godotengine (через WebFetch/curl к github.com работает). Пересборка арта: `python3 tools/art/build.py` (Pillow, numpy, scipy), результат детерминирован.

CI (`.github/workflows/godot-validation.yml`) гоняет все `tests/*.gd` циклом — новые тесты подхватываются сами.

## 6. Рецепты расширения

- **Новый регион:** блок в `data/regions.json` (name, map_color, herb_quest, npcs, chests, herbs, enemies, gates с `requires_quest`/`requires_guardian`/`locked_message`, `terrain` со style day|night|cave, trails, ponds, trees, props, blockers, bushes) → ворота к нему из соседнего региона → `python3 tools/art/build.py` → импорт. Новый стиль = палитра в `palettes.py` + ветки в `build_world`/`terrain.py`/`world.gd::_add_ambient`.
- **Спутник:** `Companion` (наследник `WorldNpc`, `is_companion`), создаётся `main.ensure_companion()` (эффект сцены `companion_join`), не удаляется при смене региона, ставится рядом с героем в `_place_companion()`. E без цели рядом — разговор со спутником. Маркер над спутником только «ready».
- **Новый NPC:** запись в `npcs` региона → `on_<id>()` в `NpcDialogues` (+ квест в `marker_for`) → обёртка `_on_<id>_interacted` в `main.gd` → `Look` в `characters.NPCS` → имя в `hud.gd::PORTRAITS` → доверие в `npc_relationships.json`.
- **Новый враг:** наследник `SlimeEnemy` (задать sprite_sheet/offset/fps до `super._ready()`), `ENEMY_SCRIPTS` + `enemy_kind()` в `main.gd`, `FALLBACK_ENEMY_POSITIONS` в `game_save_state.gd`, `bestiary.json`, функция в `creatures.py` + строка в `build.py` и валидаторе. Поведение — через хуки (`_shape_chase`).
- **Новый предмет:** `data/equipment.json` + иконка в `icons.py`; цена продажи — `merchant_stock.json → sell_prices`.
- **Новый квест:** `data/quests.json` (target, reward, choices) + диалог; выбор с наградой — префикс `<npc>_reward:<choice>` в `handle_choice`.

## 7. Подводные камни (найдены на практике)

- **Циклические ссылки на class_name могут повесить загрузку** (без ошибок, тест просто висит): SkillTreePanel → HeroPanel → CombatSkills → SkywardGame → GameHud → SkillTreePanel. Общие стили — в `UiStyle`, не в окнах.

- Новый уровень больше **не ставит игру на паузу**: он даёт очко навыков (дерево — `T`). Старый `TalentChoicePanel` остался только как компонент; `pending_level_choices` не используется.
- Характеристики (`power`, `will`, `agility`) — обычные ключи в определении предмета; `player.get_stat()` = уровень−1 + экипировка. Урон заклинания × `get_spell_power_multiplier()`.
- `spawn_enemy(kind, pos, elite)`: "" — обычный, id — элита, "?" — бросок (только в сюжетной игре). Элита из `regions.json` — поле `"elite"` у врага.
- Позы врагов — `_pose("windup"|"lunge"|"rest")` (tween масштаба спрайта); телеграф — `combat_feedback.set_telegraph()`.
- Случайный лут: `main.loot_rng` (в тестах задавай seed); определения сгенерированных предметов сохраняются в сейве раньше инвентаря.
- Навык добавляется только в `data/talents.json` (branch, tier, max_rank, requires, seal) + эффект в `player.gd`/`magic_bolt.gd`.
- `queue_free()` удаляет узел в конце кадра — перед проверкой жди `process_frame`.
- Хитбокс снаряда — на уровне земли (там коллизии врагов); картинка поднята `visual.offset`. Не поднимай сам снаряд — попадания сломаются.
- Ореолы/свечение в генераторе рисуй **после** `outline()`, иначе вокруг свечения появится жёсткий контур.
- Тёмные враги на тёмном полу не читаются — давай контрастный акцент (у мыши бирюзовые крылья).
- Полоска здоровья врага — `combat_feedback.bar_y` (по умолчанию −28; хранитель −46, мышь −33).
- Автосохранение отложено на конец кадра (`request_autosave`), чтобы награда квеста попала в снимок; после поражения автосейв запрещён.
- `data/regions.json` форматируй через `tools/art/jsonfmt.py`, иначе каждое число встанет на отдельную строку.
- `*.uid`/`*.import` от редактора не коммитим (`git clean -fdq -e .godot -- '*.uid' '*.import'` перед `git add -A`).
- Тесты проверяют тексты диалогов (`dialogue_label`) и имя говорящего (`dialogue_speaker_label`) — меняя реплики, ищи их в `tests/`.
- Новые реплики пиши с `{hero}` и `{м|ж}` формами; тесты по умолчанию используют мужской род (Арен).
- Сюжетный режим включён, только если начат `main_prologue` (новая игра из меню). Вне его `StoryDirector` молчит — старые сейвы и тесты идут по классическому потоку.
- Сцены из `StoryDirector` ждут, пока закроется текущий диалог (`update()` в `_process`) — так награды и реплики NPC не теряются.
- `EchoWarden` наследует `GroveGuardian`, `SkySentinel` — `ForestShaman`: в `enemy_kind()` проверяй наследников первыми.
- **Сборки:** `export_presets.cfg` (Windows Desktop, Linux; json-данные в include_filter — без них игра пустая!). `release.yml` экспортирует на каждый push в main и публикует Release по тегу `v*` или при ручном запуске с `release_tag` (пуш тегов из облачной сессии ИИ блокируется прокси — проси владельца нажать «Run workflow»). В release-сборках нельзя передать сцену в командной строке, поэтому smoke-тест экспорта запускает `-- --smoke` (title_menu сразу открывает мир). Версия — `application/config/version` в project.godot. Локальная проверка без шаблонов: `godot --headless --export-pack "Linux" game.pck`, затем `godot --main-pack game.pck res://scenes/main.tscn`.
- **Шрифт:** `assets/fonts/skyward_pixel.ttf` из `tools/art/font.py` (глифы — строки пикселей; новый символ = строка в словаре `G`). Тема `assets/ui_theme.tres` подключена в project.godot (`gui/theme/custom`). Размеры шрифта всегда через `UiFont.px(n)` (≤12→9, ≤23→18, иначе 27), иначе пиксели «поплывут»; в `_draw()` шрифт — `UiFont.font()`. В `skyward_pixel.ttf.import` выключены сглаживание, хинтинг и субпиксели — файл .import закоммичен, не удаляй.
- **Звук:** `GameAudio.play("name")` (файлы `assets/audio/sfx/*.wav`), `GameAudio.music("track")`; музыку выбирает `main.update_music()` (стиль региона → трек, живой `GroveGuardian`-наследник → `boss`). Новые звуки/треки — функции в `tools/audio/build_audio.py`, затем `python3 tools/audio/build_audio.py`. Громкость — `GameSettings.get_float("music_volume"/"sfx_volume")`.
- **Hit-stop:** `main.hit_stop(сек)` ставит `Engine.time_scale = 0.05` на реальное время; в headless не срабатывает, чтобы тесты шли ровно.
- **Пак владельца вне git (9 ноября 2026):** папка `assets/incoming/` в `.gitignore` и вырезана из всей истории (репозиторий ~280 → ~100 МБ). Пак хранится локально у владельца (архив `Skyward_Tales_asset_pack.zip` он получил в чате); положить в `assets/incoming/...` нужно только для перерисовки HD-графики (`tools/art/hd/*`, `tools/art/chibi.py`). Игра пак не загружает — всё нужное уже лежит в `assets/world_hd`, `assets/sprites` и т. д.
- **Сборки:** `.github/workflows/release.yml` на каждый пуш в main кладёт в артефакт запуска установщик `SkywardTales-Setup.exe` (NSIS, `installer/skyward_tales.nsi`: ставит в `%LOCALAPPDATA%\Programs\Skyward Tales` без прав админа, ярлыки, удаление в «Приложениях»; сохранения не трогает) и zip для Windows и Linux. Импорт Godot кэшируется (`actions/cache`, папка `.godot`).
- **Купленный пак спрайтов** (лицензия владельца: можно изменять и продавать) лежит в `assets/incoming/` (вне git — см. выше) (Legacy Red — героиня, Companion — Мира, Blacksmith/Herbalist/Potion Maker — NPC, Decorations). `python3 tools/art/chibi.py` собирает из него `assets/sprites/chibi/<id>/<anim>.png` (8 направлений, левые отражены, кадр 64×64), `manifest.json` (кадры, ячейка, высота ног) и портреты `assets/sprites/portraits/`. Мужской герой и остальные NPC — перекраска/стрижка/бороды из Legacy Red и Companion (`make_variant`). Декор — `assets/world/decor_*.png`, ставится как prop `decor_<имя>` в terrain.props (+ blocker). `DirectionalSprite.configure_chibi(id)` включает лист: idle при стоянии, `play_named("roll"/"cast"/"hit"/"throw")`. Если листа нет — старые нарисованные кодом спрайты. Тайлсеты от PixiVan ещё в работе — земля пока своя. Враги (кроме Вейла) пока в старом стиле.
- **Камера ×2** (`scenes/player.tscn` zoom) — на экране 320×180 мира; `main._fit_to_view` уменьшает дальность обнаружения/стрельбы врагов (×0.68). Интерфейс не масштабируется.
- **Квестовые предметы** (herbs) спавнятся только при открытом задании (`_herb_quest`), а при старте задания — сразу (`QuestManager.quest_started` → `main._on_quest_started`).
- **Деревня:** постройки `village_*` (`tools/art/village.py`, палитра пака) и `decor_*` ставятся как terrain.props + blockers.
- **Поселение:** `scripts/settlement.gd` + `data/settlement.json` (доска, участки, жители: где найдены, дом, цена, реплики, услуга `discount`/`heal`/`items`). NPC жителей — id `settler_<id>`, спавнятся `settlement.npcs_for(region)`. Доска/участок/дом — `SettlementObject` (дом со своей коллизией). Подарки обновляются по числу выполненных заданий. Состояние — `world.settlement` в сохранении (восстанавливается до `_set_region`). Новый житель = запись в JSON + внешность в `tools/art/chibi.py` (`settler_<id>`) + портрет в `hud.PORTRAITS`.
- **Интерфейс:** рамки и кнопки — `assets/ui/*.png` (рисует `tools/art/village.py: build_ui`), `UiStyle.panel()/small_panel()/style_button()`; кнопки без своих стилей берут доску из `assets/ui_theme.tres`. Полоска HP врага рисуется только после урона (и всегда у элит/боссов).
- **Крафт:** `scripts/crafting_menu.gd` (`game.crafting`): точки сбора `GatherNode` из `regions.json → gather`, отдых по `crafting.play_time` (сохраняется), станции `CraftStation` из `gathering.json → placements`. Рецепты — `crafting_recipes.json` с полем `station` (`kitchen`/`alchemy`/`forge`) и необязательным `requires_recipe` (свиток `recipe_*`, при `player.add_item` выучивается в `player.learned_recipes`). Расходники описываются полем `use` (heal/mana/buff) в equipment.json; бафы — `player.buffs`, `buff_value()` входит в силу заклинаний, броню, скорость.
- **Новая земля** = запись в regions.json (`level`, `enemy_power`, `map_pos` для карты мира, `waystone`, `gather`, `dynamic_props` для меняющихся построек) + ворота туда и обратно + `python3 tools/art/build.py` (стиль в palettes.STYLES). Пример — `salt_coast`. Море/большая вода — прямоугольник ponds + blockers (ponds сами коллизий не дают).
- **Подземелья:** регион со стилем `crypt` и `terrain.rooms` ([x,y,w,h]); `tools/art/terrain.py: render_crypt` рисует пол/стены, `crypt_blockers()` даёт коллизии — пересобирать blockers при правке комнат. `doors` (ключ-предмет, `opened_doors` в сохранении) и `traps` (шипы `SpikeTrap`) спавнит `main._spawn_dungeon`.
- **Клики мыши:** `main._input` ловит ЛКМ для заклинаний; клик над GUI (`gui_get_hovered_control()`) пропускается к кнопкам и не помечается обработанным. Иначе кнопки диалогов без паузы не нажимаются (баг v0.3: выбор награды старейшины). Проверка — `tests/dialogue_click.gd` под `xvfb-run` (headless пропускается).
- **Открытый мир:** у региона `level`, `enemy_power` (множитель HP/урона/опыта, боссы не масштабируются — `main._scale_to_region`) и `waystone` [x, y]. Камни — `scripts/waystone.gd`, пробуждение = флаг `waystone_<регион>` в StoryDirector (сохраняется), перемещение — `main.fast_travel()` с кнопок карты (`WorldMapPanel.set_destinations`). Все переходы между регионами идут через `main._travel()`.
- **Побочные задания:** `"side": true` в quests.json — `start_quest` не трогает `active_quest_id` (это слот сюжета/старых заданий), сколько угодно параллельно; `quests.is_active()`, `get_side_summaries()`. Квестодатели — `data/quest_givers.json` + `scripts/quest_givers.gd` (NPC без своего `_on_<id>_interacted` автоматически становится квестодателем, если есть в givers). `requires_quest` в задании — порядок цепочки. Травы с полем `quest` считаются для него; враг с полем `quest` появляется только пока задание открыто (`main.spawn_quest_enemies`).
- **Задания на убийства:** поле `kill_kind` в quests.json (вид врага из `enemy_kind()`); `main._track_kill_quests` считает победы, сюжетное задание само завершается и запускает цепочку.
- `VailBoss` наследует `GroveGuardian` (тот выбирает свой спрайт в `_ready`, поэтому Вейл переставляет лист после `super._ready()`); `RiftShade` наследует `ForestShaman` — в `enemy_kind()` оба раньше родителей.
- Сюжетные боссы — `main.STORY_BOSSES` (kind → имя): флаг `<kind>_defeated`, без повторного появления, печать неба, сцена из `dialogues.json → bosses`. Новый босс = строка там + `ENEMY_SCRIPTS` + `bosses` + `story_objects.spawns`.
- `TempestColossus` наследует `EchoWarden` → в `enemy_kind()` он раньше; `WindWisp` наследует `ForestWolf` → раньше волка.
- Островные стили — `palettes.ISLAND_STYLES` (sky, spires): небо и облака вместо края леса. В `spires` вместо деревьев — каменные шпили (`flora.stone_spire`).
- Остров (`edge_margin` в terrain) — невидимые стены по краю; всё, что ставишь, держи внутри `edge_margin`.
- Пролог запускается только через мету `skyward_new_hero` (её ставит меню). Тесты, которые создают `main.tscn` напрямую, пролог не видят и начинают со старого потока Элиана.
- Не добавляй постоянных подсказок на экран: владельца они раздражают. Обучение — только через `hud.show_tip(id, текст)` (показывается один раз) и страницу «Управление» в паузе.
- `hud.message_label` невидим и хранит последнее сообщение для кода/тестов; игрок видит `hud.toasts`.
- Камера ограничена размером карты; HUD рассчитан на 640×360 (рамка 150×40 слева сверху, мини-карта справа, заклинания снизу).

## 8. Что делать дальше (по приоритету)

Актуальный порядок — в конце `docs/ROADMAP.md` (раздел этапа 22 «Разбор от 11 ноября»). Коротко:

1. Бой: попадание меча по фазам анимации (замах → удар → восстановление).
2. Первые 30–60 минут как эталон: деревня → поручение → исследование → подземелье → босс → улучшение.
3. Несколько путей подготовки к сюжетным главам вместо обязательных побочных заданий.
4. Поведение врагов, меняющее тактику; собственные награды занятий; удобства сумки и ремесла.
5. Идеи: экспедиции с выбором риска, свойства снаряжения, последствия в мире, совместные действия со спутниками, секреты локаций.
6. Архитектура: `main.gd` (~2040 строк), `player.gd` (~1040), `hud.gd` (~950) — продолжать выносить состояния героя и восстановление систем.

## 9. Известные ограничения

- ИИ не слышит звук и не играет руками: баланс, ощущение боя и музыка проверены только расчётом и тестами.
- Жители и враги — в старой мелкой графике; новые листы есть только у героев, Алой и курицы.
- Земля региона — одна большая текстура (до 3840×2560); другие биомы частично собраны из старого набора.
- Все этажи Башни испытаний — один зал; Хозяин цистерны и Страж жеоды — усиленные обычные враги.
- После загрузки особые противники (Хозяин, Страж) возвращаются с полным здоровьем; подъём в Башне начинается от кристалла.
- Оконный тест кликов в CI требует xvfb; если его не удалось поставить, шаг пишет предупреждение, а не «пройдено».

