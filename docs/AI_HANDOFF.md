# AI HANDOFF — Skyward Tales

Последнее обновление: 3 ноября 2026 года (сессия «синьор-ревью»: рефакторинг, графика, третий регион).

Точка входа для следующего разработчика (человека или ИИ). Прочитай этот файл, затем `docs/ROADMAP.md` (дорожная карта, согласованная с владельцем), `docs/STORY.md` (сюжет) и `assets/ART_GUIDE.md`. История шагов — в `git log` (сообщения коммитов подробные).

---

## 0. Начни отсюда (5 минут)

1. `git log --oneline -15` — что делалось последним.
2. Прогони тесты (раздел 5). Все 63 должны быть зелёными. Если нет — сначала чини.
3. Спроси владельца, что он увидел в окне игры: сам он запускает Godot 4.7 на Windows, ИИ — только headless + скриншоты через Xvfb.
4. Работай маленькими коммитами прямо в `main` (владелец так решил). После каждого коммита — тесты; после пуша — проверь GitHub Actions.

## 1. Проект

Skyward Tales — 2D top-down pixel-art fantasy RPG: исследование, магия, прокачка, квесты, NPC, боссы. Язык игры — **русский**. Владелец (DoctorStrangeSH) — продюсер и тестировщик; ИИ — технический лид, сам принимает инженерные решения.

- Godot **4.7.2**, GDScript, renderer GL Compatibility.
- Внутреннее разрешение 640×360, окно 1280×720, nearest filtering, 1 пиксель мира = 1 пиксель вьюпорта.
- Репозиторий: https://github.com/DoctorStrangeSH/Skyward-Tales (`main`). Ветка `feat/godot-rpg-foundation` устарела — всё уже в `main`.

## 2. Приоритеты владельца

1. **Сначала геймплей и надёжность**, но графика тоже важна: владелец хочет «красиво, как Sea of Stars и похожие популярные игры».
2. Весь арт генерируется кодом (`tools/art/`). PNG руками не править — менять генератор и пересобирать. Арт оригинальный, ничего не копировать из чужих игр.
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
- **Купленный пак спрайтов** (лицензия владельца: можно изменять и продавать) лежит в `assets/incoming/` (Legacy Red — героиня, Companion — Мира, Blacksmith/Herbalist/Potion Maker — NPC, Decorations). `python3 tools/art/chibi.py` собирает из него `assets/sprites/chibi/<id>/<anim>.png` (8 направлений, левые отражены, кадр 64×64), `manifest.json` (кадры, ячейка, высота ног) и портреты `assets/sprites/portraits/`. Мужской герой и остальные NPC — перекраска/стрижка/бороды из Legacy Red и Companion (`make_variant`). Декор — `assets/world/decor_*.png`, ставится как prop `decor_<имя>` в terrain.props (+ blocker). `DirectionalSprite.configure_chibi(id)` включает лист: idle при стоянии, `play_named("roll"/"cast"/"hit"/"throw")`. Если листа нет — старые нарисованные кодом спрайты. Тайлсеты от PixiVan ещё в работе — земля пока своя. Враги (кроме Вейла) пока в старом стиле.
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

0. **Этап 9 в ROADMAP — текущий.** Меч готов: `main.gd` → `sword_slash()/sword_spin()/_melee_hit()`, ввод `attack` (ЛКМ) и `cast_spell` (ПКМ), урон `player.get_melee_damage()` (слот `blade`, бонус `melee`). Магия в сюжете открывается флагом `magic_unlocked` после `main_guardian`. Анимации героя slash1/slash2/charge/spin собирает `tools/art/chibi.py` (слой VFX накладывается `over`). Тест: `tests/sword.gd`. Навыки 1–4: `scripts/combat_skills.gd` (узел `game.skills`, откаты, `hotbar_entries()`), данные `data/skills.json`, слоты `player.skill_slots` (сохраняются), пассивы `player.has_passive()`; удары идут через `main._strike()` (крит, вампиризм) и `_melee_hit/_line_hit`. Окно героя `scripts/hero_panel.gd` (C), панель `scripts/hotbar_slot.gd`. Тест: `tests/combat_skills.gd`. Лут: `main.roll_drops(kind, at, elite)` по `data/drops.json`, `chest_tier_reward(tier)`, `WorldLoot` (магнит, `"gold"` — монеты), ремесло в пути — станция `hand` (`open_handcraft`, клавиша B). Тест: `tests/loot_drops.gd`. Рыбалка: `scripts/fishing.gd` (узел `game.fishing`, состояния waiting/bite/reel, `manual_input`+`holding` для тестов), `fishing_panel.gd`, `fishing_bobber.gd`, `player.fish_log`; узел `fish` в `crafting.gather` запускает мини-игру. Журнал `quest_journal_panel.gd` (вкладки), трекер `quest_tracker.gd`. Тест: `tests/fishing.gd`. Внимание: лямбды GDScript копируют локальные переменные — в тестах пишите в словарь. Острова: `world.gd` → `_add_apron()` (полосы `<region>_apron_<side>.png`, `sky_clouds.gd`, `cloud_shadows.gd`), камера в `main._apply_camera_limits`. Титульный экран — `title_menu.gd` + `assets/ui/title_island.png`. Миникарта: `world_minimap.gd` (`follow` — HUD, иначе карта M), живые значки — `main.minimap_markers()`, сохраняемые — `discovered_landmarks`; миниатюры `tools/art/minimap.py` (`build.py --only minimap`). Ворота: `RegionGate.pick_kind()` + арт `tools/art/gates.py`. Тест: `tests/region_gates.gd`. Внимание: ошибка разбора скрипта вешает headless-тест без сообщения — проверяйте `--check-only --script res://scripts/main.gd`. Пепельная пустошь: регион `ashen_waste` в `regions.json` (стиль `ash` в palettes), враги `ember_hound.gd`, `magma_golem.gd`, `ash_cultist.gd`, босс `ash_lord.gd` (перекраски — `tools/art/recolor.py`), деревья/кусты раскидывает `tools/region_scatter.py <region>`. События: `world_events.gd` (`game.events`, `start(kind)`), воришка `loot_imp.gd`. Тесты: `ashen_waste.gd`, `world_events.gd`. Окно героя: `inventory_window.gd` (вкладки gear/skills, `slot_buttons`, `item_list` — сетка), ячейки `inventory_item_button.gd` (`summary` — полный текст, drag-источник), слоты `equip_slot.gd` (приём drop), `bag_drop_area.gd`, вкладка навыков `skills_page.gd`; старого `hero_panel.gd` больше нет, `hud.hero_visible` = `inventory_open`. Тест: `tests/inventory_drag.gd`. Подземелья: стиль `magma` (рендер `render_crypt` + лава из `ponds`), `RegionCatalog.is_underground()/is_dungeon()`; ловушки в `traps` — `[x,y]` шипы или `{"kind":"vent"}` (`flame_vent.gd`); `levers` (`dungeon_lever.gd`) и двери с `levers` (печати) — состояние в `opened_doors`. Босс `forge_titan.gd`. Тест: `tests/forge_depths.gd`. Акт III: главы `main_elder`, `main_echoes`, `main_ascent`, `main_heart` (цепочка в `dialogues.json` → `chain`, поле `title` = титр), отголоски — `story_objects` `keeper_echo_*`, регион `sky_heart`, босс `pattern_voice.gd` (`bosses.pattern_voice.finale`), выбор — `main.offer_finale()` / `choose_finale()` (выбор `finale:*` в `npc_dialogues.gd`, повторяется, пока не сделан). Тест: `tests/story_act3.gd`. Разнообразие: `day_night.gd` (`game.day_night`, CanvasModulate + светлячки, группы света `night_lights`/`torch_lights` из `world._add_glow`), `treasure_hunt.gd` + `dig_spot.gd` (`game.treasure`), `contracts.gd` + `contract_board.gd` (`game.contracts`, `contract_boards` в регионах), события `trader`/`meteor` в `world_events.gd`; всё сохраняется в `world.day/treasure/contracts`. Тест: `tests/variety.gd`. Легенды: `legends.gd` (`game.legends`, данные `data/legends.json`, спавн при `dark()`, meta `legend` — не сохраняется как враг, трофеи в `equipment.json`). Достижения: `achievements.gd` (`game.achievements.add(stat)/set_max(stat, v)`, данные `data/achievements.json`, вкладка `ach` в `quest_journal_panel.gd`); оба в `world.legends/achievements`. Тест: `tests/legends_achievements.gd`. Эпилог: `epilogue.gd` (`game.epilogue`: `ending()`, `xp_mult()/gold_mult()`, разломы из `data/epilogue.json` → `pattern_rift.gd`, враги-отголоски с meta `rift_echo` — не сохраняются; сохранение `world.epilogue`), небо `epilogue_sky.gd` (сияние/звездопад поверх видимой области), супербосс `pattern_shade.gd` (наследник `pattern_voice.gd`). NPC с `"requires_flag": "ending"` появляются только после финала; квесты с `requires_flag` и награды `items_by_flag` (`npc_dialogues._grant_reward`). Вестник — `herald` в `quest_givers.json`, облик в `chibi.py`. Тест: `tests/epilogue.gd`. Навигация: `quest_nav.gd` (`game.quest_nav`: `refresh()` раз в 0,3 с, `targets` — {region, position|null, kind main/side/offer/turnin}, `route(a,b)` по воротам, `minimap_markers()` — `goal_main/goal_side/goal_gate`, `region_badges()`), карта мира `world_overview.gd` (острова из `assets/world/<id>_mini.png`, позиции — `map_pos`, клик → `travel_requested`), панель `world_map_panel.gd` (612×348, `open_map(true)` — вкладка «Мир»). Миникарта: `_discover_landmarks()` медленно, `_draw_minimap()` каждый кадр. Респаун: `main._spawn_layout_enemy()` + `_process_respawns()` (`ENEMY_RESPAWN`). Автосейв: `_tick_autosave()` (`AUTOSAVE_INTERVAL`), значок `save_indicator.gd`. Рыбалка: `EARLY_LIMIT`, `REEL_GRACE` в `fishing.gd`. Тест: `tests/navigation.gd`. Этап 9 завершён; дальше — новые регионы и подземелья (см. ROADMAP).

1. **Следовать `docs/ROADMAP.md` по этапам** (интерфейс → сюжет → прокачка). Сюжет одобрен (`docs/STORY.md`), пролог и весь акт I готовы. Этап 3 готов (дерево, характеристики, случайная добыча). Этап 4 почти готов (анимации, телеграфы, отбрасывание, элиты, тряска). Начат этап 8 «Большой мир» (см. ROADMAP): уровни регионов, небесные камни, побочные квестодатели, Туманная топь. Акт II завершён (этап 5): Мира-спутница, Небесный остров, Архив, Ветреные шпили, Буревой колосс, Расколотый остров и Вейл. Есть звук, музыка, hit-stop и релизные сборки. Дальше: третий остров/бой с Вейлом, пиксельный шрифт, звуки окружения, сборка Windows.
2. **Анимации атаки и гибели врагов** (сейчас вспышка + облачко), анимация удара героя по нему.
3. **Синергия льда и молнии**, новые таланты для молнии (в пещерах мыши слабы к ней).
4. **Сюжетная арка:** что случилось с лесом и пещерой, финальный босс в сердце пещеры (алтарь уже стоит — `crystal_altar`).
5. **Пиксельный шрифт** для интерфейса (сейчас системный шрифт с обводкой).
6. **Звук и музыка**, затем **экспорт Windows EXE** в GitHub Actions.
7. Технический долг: `main.gd` (~830 строк) — вынести ввод, магию и таланты; `hud.gd` (~580) — диалог в отдельный компонент.

## 9. Известные ограничения

- Ручной QA в окне не проводился ИИ; владелец ещё не оценивал новую графику, пещеры и продажу.
- Земля региона — одна PNG 1280×864; при росте карт перейти на TileMapLayer.
- Враги обходят препятствия простым steering.
- Редкий дроп сундуков (7%) может не выпасть за прохождение.
- Нет звука, музыки, экспорта.
