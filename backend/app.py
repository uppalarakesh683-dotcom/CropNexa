
from flask import Flask, request, jsonify
from flask_cors import CORS
from google import genai
from dotenv import load_dotenv
import os

load_dotenv()

app = Flask(__name__)
CORS(app)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if not GEMINI_API_KEY:
    raise RuntimeError("GEMINI_API_KEY is missing.")

client = genai.Client(api_key=GEMINI_API_KEY)


@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "success": True,
        "message": "CropNexa AI Farm Backend is running"
    })


@app.route("/api/chat", methods=["POST"])
def chat():
    try:
        data = request.get_json()

        if not data:
            return jsonify({
                "success": False,
                "error": "No request data received."
            }), 400

        message = data.get("message", "").strip()

        if not message:
            return jsonify({
                "success": False,
                "error": "Message cannot be empty."
            }), 400

        response = client.models.generate_content(
            model="gemini-3.6-flash",
            contents=f"""
You are CropNexa AI Farm Assistant.

Help farmers with crop management, irrigation, weather,
soil, fertilizers, pests, diseases, and farming practices.

The farmer can communicate in English, Telugu, or Hindi.

Always reply in the same language as the farmer.

Farmer's question:
{message}
"""
        )

        return jsonify({
            "success": True,
            "reply": response.text
        })

    except Exception as e:
        print("AI CHAT ERROR:", e)

        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 5000)),
        debug=False
    )