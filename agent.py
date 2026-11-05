import os
import re
import json
import time
import requests
from dotenv import load_dotenv

load_dotenv()

# Ключи API поддерживаемых провайдеров
POLZA_API_KEY = os.getenv("POLZA_API_KEY") or os.getenv("DEEPSEEK_API_KEY")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

SYSTEM_PROMPT = """
Ты — Рэй (Rae), элитный нетраннер и боевая напарница Ви в Cyberpunk 2077.
Ты прикрываешь Ви: бегаешь рядом как физический напарник, взламываешь врагов и системы, спасаешь в критический момент и ведешь огонь.
Твой характер: циничная, профессиональная, дерзкая, верная напарнику, используешь живой сленг Найт-Сити (чoomba, хром, деки, корпы, лед, санди, максдок).
Говори коротко, броско, дерзко, в стиле радиосвязи (1-2 коротких предложения максимум).

Когда Ви говорит с тобой, ты ОБЯЗАНА вернуть ответ СТРОГО в валидном JSON-формате:
{
  "action": "ACTION_TYPE",
  "target": "TARGET_DESCRIPTION",
  "speech": "Твоя короткая реплика (1-2 предложения)"
}

ДОСТУПНЫЕ ACTION_TYPE:
1. Быстрые взломы (Quickhacks):
   - "HACK_OVERHEAT" — поджечь врага, спалить пулеметчика / тяжелого пехотинца
   - "HACK_WEAPON_GLITCH" — заклинить стволы пачке врагов, вырубить огнестрел
   - "HACK_CYBERWARE_MALFUNCTION" — вырубить импланты, заглушить Сандевистан боссу/ниндзя
   - "HACK_DISABLE_CAMERAS" — вырубить камеры наблюдения в радиусе 25 метров
   - "HACK_DISABLE_TURRETS" — отключить автоматические турели
   - "HACK_PING_NETWORK" — пропинговать сеть, подсветить врагов сквозь стены

2. Спасение и боевая поддержка:
   - "COVER_ME" — шквальный огонь на подавление, прикрыть Ви, пока он лечится или перезаряжается
   - "REVIVE_PLAYER" — вколоть стимулятор/максдок, реанимировать Ви при критическом здоровье

3. Взаимодействие с миром:
   - "FORCE_OPEN_DOOR" — взломать/вскрыть запертую дверь или терминал в обход проверок

4. Бой на транспорте (Drive-by):
   - "VEHICLE_COMBAT_TIRES" — высунуться из окна и расстрелять колеса погоне
   - "VEHICLE_COMBAT_DRIVER" — снять водителя преследующей машины

5. Боевые стойки (Stances):
   - "SET_STANCE_GHOST" — тихий стелс-режим (сесть на корты, не стрелять первыми, глушить камеры)
   - "SET_STANCE_BERSERK" — мясорубка/штурм (агрессивная атака, гранаты, пуш)
   - "SET_STANCE_OVERWATCH" — оборона/снайпер (дистанция 20м, дальнее прикрытие)

6. Тактическое движение:
   - "FOLLOW" — идти рядом / следовать за Ви
   - "HOLD_POSITION" — ждать тут / держать позицию
   - "REGROUP" — ко мне / телепортнуться к Ви (если застряла)
   - "ENTER_VEHICLE" — сесть в машину к Ви
   - "EXIT_VEHICLE" — выйти из машины

7. Разговор:
   - "CHAT" — обычный диалог, реакция на слова Ви без игрового действия
"""

# Каскады моделей в порядке приоритета скорости и стабильности
POLZA_CASCADE = [
    "google/gemini-2.5-flash",          # ~2.5s, максимальный интеллект и лор
    "openai/gpt-4o-mini",               # ~3.0s, железобетонная стабильность
    "meta-llama/llama-3.3-70b-instruct" # резервная мощная открытая модель
]

GROQ_CASCADE = [
    "llama-3.3-70b-versatile",
    "llama-3.1-8b-instant"
]

def extract_json(raw_text: str) -> dict:
    raw_text = raw_text.strip()
    match = re.search(r"\{.*\}", raw_text, re.DOTALL)
    if match:
        return json.loads(match.group(0))
    return json.loads(raw_text)

def query_polza_auto(user_text: str) -> dict:
    """Автоматический перебор моделей Polza.ai: берет быстрейшую, при сбое мгновенно переключает на резерв"""
    url = "https://api.polza.ai/v1/chat/completions"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {POLZA_API_KEY}"
    }

    last_err = None
    for model_name in POLZA_CASCADE:
        t0 = time.time()
        try:
            payload = {
                "model": model_name,
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": user_text}
                ],
                "temperature": 0.5
            }
            # Таймаут 6 сек: если модель затупила в очереди, сразу прыгаем на следующую
            resp = requests.post(url, headers=headers, json=payload, timeout=6)
            data = resp.json()
            if "choices" in data and len(data["choices"]) > 0:
                content = data["choices"][0]["message"]["content"]
                parsed = extract_json(content)
                print(f"[Auto-Model] Выбрана: {model_name} ({time.time()-t0:.2f}s)")
                return parsed
        except Exception as e:
            last_err = e
            print(f"[!] Модель {model_name} задержалась ({e}), авто-переключение на резервную...")
            continue

    raise RuntimeError(f"Все модели Polza.ai недоступны: {last_err}")

def query_groq_auto(user_text: str) -> dict:
    """Автоматический выбор модели на Groq LPU"""
    url = "https://api.groq.com/openai/v1/chat/completions"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {GROQ_API_KEY}"
    }
    for model_name in GROQ_CASCADE:
        try:
            payload = {
                "model": model_name,
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": user_text}
                ],
                "response_format": {"type": "json_object"},
                "temperature": 0.6
            }
            resp = requests.post(url, headers=headers, json=payload, timeout=4)
            data = resp.json()
            content = data["choices"][0]["message"]["content"]
            return extract_json(content)
        except Exception:
            continue
    raise RuntimeError("Groq недоступен")

def process_command(user_text: str) -> dict:
    """Главный роутер: определяет провайдера и модель автоматически"""
    # 1. Если ключ Polza.ai (pza_...)
    if POLZA_API_KEY and POLZA_API_KEY.startswith("pza_"):
        try:
            return query_polza_auto(user_text)
        except Exception as e:
            print(f"[-] Ошибка авто-выбора Polza: {e}")

    # 2. Если прямой Groq
    if GROQ_API_KEY:
        try:
            return query_groq_auto(user_text)
        except Exception as e:
            print(f"[-] Ошибка авто-выбора Groq: {e}")

    # 3. Резервный ответ
    return {
        "action": "CHAT",
        "target": "none",
        "speech": "Помехи на канале связи, Ви! Проверь подключение к сети."
    }

if __name__ == "__main__":
    test_phrase = "Рэй, спали вон того пулеметчика!"
    print(f"Тест авто-выбора для: \"{test_phrase}\"")
    res = process_command(test_phrase)
    print("Результат:", json.dumps(res, ensure_ascii=False))
