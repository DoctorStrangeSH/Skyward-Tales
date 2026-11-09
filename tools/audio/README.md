# Звук Skyward Tales

| Что | Инструмент | Запуск |
|---|---|---|
| Музыка (10 треков, 44,1 кГц, стерео) | `orchestra.py` | `python3 tools/audio/orchestra.py [--only title,boss]` |
| Звуковые эффекты (44,1 кГц) | `sfx_hd.py` | `python3 tools/audio/sfx_hd.py [--only hit,chest]` |
| Фоновые звуки (ветер, птицы, сверчки…) | `build_audio.py` | `python3 tools/audio/build_audio.py [--names birds,night]` |

Музыка написана нотами прямо в `orchestra.py`: общая тема «Skyward» (титул, луга) и своя мелодия у каждой земли; аккомпанемент собирается из аккордовых схем. Играет её банк инструментов **GeneralUser GS** (S. Christian Collins), синтезатор — **TinySoundFont** (Bernhard Schelling, MIT). При первом запуске оба скачиваются с GitHub в `tools/audio/.cache/` (в git не хранятся), рендерер `sf_render.c` собирается `gcc`. Нужны `numpy`, `scipy`, `ffmpeg` с libvorbis.

Лицензия GeneralUser GS v2.0: «You may use GeneralUser GS without restriction for your own music creation, private or commercial… feel free to use it in your software projects». Отрендеренная музыка и эффекты — часть игры, сам банк в игру не входит.

Трек к земле подбирает `SkywardGame.MUSIC_BY_STYLE` (`scripts/main.gd`), звук заклинания — поле `sound` в `data/spells.json`.
