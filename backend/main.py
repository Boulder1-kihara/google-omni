import os
import asyncio
import json
import base64
import traceback
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from dotenv import load_dotenv

from google import genai
from google.genai import types

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

app = FastAPI()
_api_key = os.environ.get('GOOGLE_API_KEY', '')
print(f"[STARTUP] API key prefix: {_api_key[:8]}")

client = genai.Client(api_key=_api_key, http_options={'api_version': 'v1beta'})

@app.websocket("/omni-live")
async def omni_live_endpoint(websocket: WebSocket):
    await websocket.accept()
    print("🟢 Deep Intel Omni Connected (Multimodal Ready - No Auto-Screenshots)!")

    # Multimodal config: Handles Voice, Text, and Images (if manually sent)
    config = types.LiveConnectConfig(
        response_modalities=["AUDIO"],
        system_instruction=types.Content(
            parts=[types.Part.from_text(
                "You are Deep Intel Omni, a highly capable multimodal AI assistant created by Abel. "
                "You can process voice, text, and images. "
                "Respond naturally, concisely, and helpfully."
            )]
        )
    )

    try:
        # Using the stable 2.5 flash model for seamless multimodal support
        async with client.aio.live.connect(model='gemini-2.5-flash', config=config) as session:
            print("🎙️ Connected to Gemini Live API (Multimodal Active)!")

            async def receive_from_flutter():
                try:
                    while True:
                        raw_data = await websocket.receive_text()
                        payload = json.loads(raw_data)

                        # 1. Forward Audio (Ears)
                        if "audio" in payload and payload["audio"]:
                            audio_bytes = base64.b64decode(payload["audio"])
                            await session.send(input=types.LiveClientRealtimeInput(
                                media_chunks=[types.Blob(mime_type="audio/pcm;rate=16000", data=audio_bytes)]
                            ))

                        # 2. Forward Text (Chat)
                        if "text" in payload and payload["text"]:
                            print(f"User typed: {payload['text']}")
                            await session.send(input=payload["text"], end_of_turn=True)

                        # 3. Forward Images (Multimodal Capability - Only when triggered by user)
                        if "image" in payload and payload["image"]:
                            try:
                                image_bytes = base64.b64decode(payload["image"])
                                await session.send(input=types.LiveClientRealtimeInput(
                                    media_chunks=[types.Blob(mime_type="image/jpeg", data=image_bytes)]
                                ))
                                print("📸 Static image frame sent to Omni")
                            except Exception as img_err:
                                print(f"⚠️ Bad image frame received: {img_err}")

                except Exception as e:
                    print(f"🔴 Flutter stream error: {e}")

            async def receive_from_gemini():
                try:
                    async for response in session.receive():
                        server_content = response.server_content
                        if server_content is None:
                            continue

                        model_turn = server_content.model_turn
                        if model_turn is not None:
                            for part in model_turn.parts:
                                # Send audio back to Flutter (Voice)
                                if part.inline_data and part:
                                    # Add your logic here for handling inline_data
                                    pass

                except Exception as e:
                    print(f"🔴 Gemini stream error: {e}")

            await receive_from_flutter()
            await receive_from_gemini()

    except Exception as e:
        print(f"🔴 Omni Live connection error: {e}")
        await websocket.close()