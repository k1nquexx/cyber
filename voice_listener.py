import os
import io
import sys
import json
import time
import asyncio
import tempfile
import requests
import numpy as np
import sounddevice as sd
import scipy.io.wavfile as wav
import keyboard
import edge_tts
from dotenv import load_dotenv

# Определение рабочей директории (рядом с .exe или .py)
if getattr(sys, "frozen", False):
    BASE_DIR = os.path.dirname(sys.executable)
else:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

ENV_PATH = os.path.join(BASE_DIR, ".env")
load_dotenv(ENV_PATH)

from agent import process_command

POLZA_API_KEY = os.getenv("POLZA_API_KEY") or os.getenv("DEEPSEEK_API_KEY")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

CONFIG_FILE = os.path.join(BASE_DIR, "config.json")
STATE_FILE = os.path.join(BASE_DIR, "last_action.json")

# Загрузка конфигурации
DEFAULT_CONFIG = {
    "push_to_talk_key": "caps lock",
    "voice": "ru-RU-SvetlanaNeural",
    "tts_rate": "+15%",
    "tts_enabled": True,
    "sample_rate": 16000
}

config = DEFAULT_CONFIG.copy()
if os.path.exists(CONFIG_FILE):
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            config.update(json.load(f))
    except Exception as e:
        print(f"[-] Ошибка чтения config.json: {e}")

SAMPLE_RATE = config.get("sample_rate", 16000)
PTT_KEY = config.get("push_to_talk_key", "caps lock")

# Инициализация облачных клиентов
groq_client = None

if GROQ_API_KEY:
    try:
        import groq
        groq_client = groq.Groq(api_key=GROQ_API_KEY)
        print("[+] [STT] Подключен прямой Groq Whisper Turbo (~150 мс, 0 МБ VRAM)")
    except Exception as e:
        print(f"[-] Ошибка подключения Groq: {e}")

if not groq_client and POLZA_API_KEY and POLZA_API_KEY.startswith("pza_"):
    print("[+] [STT] Подключен облачный Whisper Turbo через Polza.ai (0 МБ VRAM, без VPN)")

def transcribe_audio(wav_bytes: bytes) -> str:
    """Распознавание речи через облачный Whisper Turbo (0 МБ VRAM)"""
    # 1. Groq прямой
    if groq_client:
        try:
            transcription = groq_client.audio.transcriptions.create(
                file=("command.wav", wav_bytes),
                model="whisper-large-v3-turbo",
                language="ru",
                response_format="text"
            )
            return str(transcription).strip()
        except Exception as e:
            print(f"[-] Groq Whisper error: {e}")

    # 2. Polza.ai (Whisper Turbo в облаке)
    if POLZA_API_KEY and POLZA_API_KEY.startswith("pza_"):
        try:
            url = "https://api.polza.ai/v1/audio/transcriptions"
            headers = {"Authorization": f"Bearer {POLZA_API_KEY}"}
            files = {"file": ("command.wav", wav_bytes, "audio/wav")}
            data = {"model": "openai/whisper-large-v3-turbo"}
            resp = requests.post(url, headers=headers, files=files, data=data, timeout=8)
            if resp.status_code == 200:
                return resp.json().get("text", "").strip()
            else:
                print(f"[-] Polza Whisper status {resp.status_code}: {resp.text}")
        except Exception as e:
            print(f"[-] Polza Whisper error: {e}")

    # 3. Резервный динамический локальный Whisper (если есть в системе)
    try:
        from faster_whisper import WhisperModel
        local_model = WhisperModel("base", device="cpu", compute_type="int8")
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as fp:
            tmp_name = fp.name
            fp.write(wav_bytes)
        try:
            segments, _ = local_model.transcribe(tmp_name, language="ru")
            return "".join([s.text for s in segments]).strip()
        finally:
            if os.path.exists(tmp_name):
                os.remove(tmp_name)
    except Exception:
        pass

    return ""

async def speak_text(text: str):
    """Синтез речи через Microsoft Edge TTS без задержек"""
    if not config.get("tts_enabled", True) or not text:
        return
    try:
        voice = config.get("voice", "ru-RU-SvetlanaNeural")
        rate = config.get("tts_rate", "+15%")
        communicate = edge_tts.Communicate(text, voice, rate=rate)
        
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as fp:
            temp_path = fp.name
            
        await communicate.save(temp_path)
        
        import soundfile as sf
        data, fs = sf.read(temp_path)
        sd.play(data, fs)
        sd.wait()
        
        if os.path.exists(temp_path):
            os.remove(temp_path)
    except Exception as e:
        print(f"[-] Ошибка озвучки TTS: {e}")

def save_action_for_game(action_data: dict):
    """Атомарная запись действия для CET мода Cyberpunk 2077"""
    action_data["timestamp"] = time.time()
    tmp_file = STATE_FILE + ".tmp"
    with open(tmp_file, "w", encoding="utf-8") as f:
        json.dump(action_data, f, ensure_ascii=False, indent=2)
    try:
        os.replace(tmp_file, STATE_FILE)
    except Exception:
        os.remove(tmp_file)

def main():
    print("\n" + "="*60)
    print("      CYBER COMPANION: RAE (РЭЙ) - ГОЛОСОВОЙ МОСТ      ")
    print("="*60)
    print(f"[*] Клавиша связи (Push-to-Talk): [{PTT_KEY.upper()}]")
    print(f"[*] Голосовой движок TTS:         {config.get('voice')}")
    print(f"[*] Файл состояния для игры:     {STATE_FILE}")
    print("="*60)
    print(f"ЗАЖМИ [{PTT_KEY.upper()}], ПРОИЗНЕСИ КОМАНДУ И ОТПУСТИ КЛАВИШУ...\n")

    while True:
        try:
            keyboard.wait(PTT_KEY)
            print("\n>>> [МИКРОФОН ВКЛЮЧЕН] Говори...")
            audio_frames = []

            def audio_callback(indata, frames, time_info, status):
                audio_frames.append(indata.copy())

            with sd.InputStream(samplerate=SAMPLE_RATE, channels=1, dtype="int16", callback=audio_callback):
                while keyboard.is_pressed(PTT_KEY):
                    sd.sleep(30)

            print("<<< [МИКРОФОН ВЫКЛЮЧЕН] Обработка команды...")
            if not audio_frames:
                continue

            audio_data = np.concatenate(audio_frames, axis=0)
            
            # Проверка уровня звука
            max_volume = np.max(np.abs(audio_data))
            if max_volume < 400:
                print("[-] Слишком тихо, повтори громче.")
                continue

            # Кодируем wav в память
            wav_buffer = io.BytesIO()
            wav.write(wav_buffer, SAMPLE_RATE, audio_data)
            wav_bytes = wav_buffer.getvalue()

            # Распознаем речь
            start_t = time.time()
            user_text = transcribe_audio(wav_bytes)
            stt_time = (time.time() - start_t) * 1000

            if not user_text:
                print("[-] Не удалось распознать речь.")
                continue

            print(f"[Ви]: \"{user_text}\" (STT: {stt_time:.0f}ms)")

            # Отправка в нейросеть
            start_llm = time.time()
            decision = process_command(user_text)
            llm_time = (time.time() - start_llm) * 1000

            action = decision.get("action", "CHAT")
            target = decision.get("target", "none")
            speech = decision.get("speech", "")

            print(f"[Рэй -> Действие]: {action} (Цель: {target}) | LLM: {llm_time:.0f}ms")
            print(f"[Рэй -> Голос]:    \"{speech}\"\n")

            # Передаем действие в Cyberpunk 2077
            save_action_for_game(decision)

            # Озвучиваем ответ в наушники
            if speech:
                asyncio.run(speak_text(speech))

        except KeyboardInterrupt:
            print("\nОстановка голосового моста...")
            break
        except Exception as e:
            print(f"[-] Ошибка в цикле прослушивания: {e}")
            time.sleep(1)

if __name__ == "__main__":
    main()
