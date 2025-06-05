from flask import Flask, request, jsonify
from PIL import Image
import base64
import io
import json
import os
import requests

app = Flask(__name__)

GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key="
API_KEY = "AIzaSyCSsJdDg4JAjpq22ECnAnM87jqBfAqsWuQ"

RESPONSE_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "medicineNames": {
            "type": "ARRAY",
            "items": {"type": "STRING"}
        },
        "extractedText": {
            "type": "STRING"
        }
    },
    "required": ["medicineNames", "extractedText"]
}

@app.route('/predict', methods=['POST'])
def predict_medicine_names():
    if not request.is_json:
        return jsonify({"error": "Request must be JSON"}), 400

    data = request.get_json()
    image_data_b64 = data.get('image')
    mime_type = data.get('mimeType') # Get the mimeType from the request

    if not image_data_b64:
        return jsonify({"error": "No image data provided"}), 400

    if not mime_type:
        mime_type = "image/jpeg" # Default if no mimeType is sent
        print("Warning: No mimeType provided, defaulting to image/jpeg")

    try:
        image_bytes = base64.b64decode(image_data_b64)
        print(f"Decoded image bytes: {len(image_bytes)}")
        Image.open(io.BytesIO(image_bytes))
    except Exception as e:
        print(f"Error decoding image: {e}")
        return jsonify({"error": f"Invalid image data: {e}"}), 400

    prompt = "Analyze this handwritten medical prescription image. Identify and list all medicine names clearly. Also, provide the full text extracted from the image. Format the response as a JSON object with 'medicineNames' (an array of strings) and 'extractedText' (a single string)."

    chat_history = []
    chat_history.append({
        "role": "user",
        "parts": [
            {"text": prompt},
            {
                "inlineData": {
                    "mimeType": mime_type, # Use the received mimeType
                    "data": image_data_b64
                }
            }
        ]
    })

    payload = {
        "contents": chat_history,
        "generationConfig": {
            "responseMimeType": "application/json",
            "responseSchema": RESPONSE_SCHEMA
        }
    }

    print(f"Gemini API Payload: {json.dumps(payload)}")

    try:
        response = requests.post(
            GEMINI_API_URL + API_KEY,
            headers={'Content-Type': 'application/json'},
            data=json.dumps(payload),
            timeout=30
        )
        response.raise_for_status()
        result = response.json()

        print(f"Gemini API Response: {json.dumps(result)}")

        if result.get("candidates") and result["candidates"][0].get("content") and \
           result["candidates"][0]["content"].get("parts") and \
           result["candidates"][0]["content"]["parts"][0].get("text"):

            llm_response_text = result["candidates"][0]["content"]["parts"][0]["text"]
            print(f"LLM Raw Response Text: {llm_response_text}")

            try:
                parsed_llm_response = json.loads(llm_response_text)
                medicine_names = parsed_llm_response.get("medicineNames", [])
                extracted_text = parsed_llm_response.get("extractedText", "No text extracted.")

                return jsonify({
                    "success": True,
                    "medicine_names": medicine_names,
                    "extracted_text": extracted_text
                }), 200
            except json.JSONDecodeError as e:
                print(f"Failed to parse LLM JSON response: {e}, raw response: {llm_response_text}")
                return jsonify({"error": f"Failed to parse LLM JSON response: {e}", "llm_raw_response": llm_response_text}), 500
        else:
            return jsonify({"error": "LLM response format unexpected", "details": result}), 500

    except requests.exceptions.RequestException as e:
        print(f"Failed to call Gemini API: {e}")
        return jsonify({"error": f"Failed to call Gemini API: {e}"}), 500
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return jsonify({"error": f"An unexpected error occurred: {e}"}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)