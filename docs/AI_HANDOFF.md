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

Акт II: пещеры ──[main_echo]──▶ Небесный остров (стиль sky): архивариус Ориэн, Стражи-автоматы, 3 кристалла памяти, Мира — спутница.

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
- Остров (`edge_margin` в terrain) — невидимые стены по краю; всё, что ставишь, держи внутри `edge_margin`.
- Пролог запускается только через мету `skyward_new_hero` (её ставит меню). Тесты, которые создают `main.tscn` напрямую, пролог не видят и начинают со старого потока Элиана.
- Не добавляй постоянных подсказок на экран: владельца они раздражают. Обучение — только через `hud.show_tip(id, текст)` (показывается один раз) и страницу «Управление» в паузе.
- `hud.message_label` невидим и хранит последнее сообщение для кода/тестов; игрок видит `hud.toasts`.
- Камера ограничена размером карты; HUD рассчитан на 640×360 (рамка 150×40 слева сверху, мини-карта справа, заклинания снизу).

## 8. Что делать дальше (по приоритету)

1. **Следовать `docs/ROADMAP.md` по этапам** (интерфейс → сюжет → прокачка). Сюжет одобрен (`docs/STORY.md`), пролог и весь акт I готовы. Этап 3 готов (дерево, характеристики, случайная добыча). Этап 4 почти готов (анимации, телеграфы, отбрасывание, элиты, тряска). Начат акт II (этап 5): Мира-спутница, Небесный остров, Архив. Дальше: Ветреные шпили (второй остров, босс-опора), новые боссы/фазы, пиксельный шрифт.
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
