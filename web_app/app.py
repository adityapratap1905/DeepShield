
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image, UnidentifiedImageError
from flask import Flask, request, jsonify, render_template

# -----------------------------------
# DeepShield configuration
# -----------------------------------

app = Flask(__name__)

BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "deepshield_final.keras"

IMAGE_SIZE = (224, 224)
MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10 MB

app.config["MAX_CONTENT_LENGTH"] = MAX_IMAGE_SIZE

# -----------------------------------
# Load trained model
# -----------------------------------

print("Loading DeepShield model...")

if not MODEL_PATH.is_file():
    raise FileNotFoundError(
        f"Model not found: {MODEL_PATH}\n"
        "Keep deepshield_final.keras in the same folder as app.py."
    )

model = tf.keras.models.load_model(MODEL_PATH)

print("DeepShield model loaded successfully!")


# -----------------------------------
# Image prediction
# -----------------------------------

def predict_image(image):
    image = image.convert("RGB").resize(IMAGE_SIZE)

    image_array = np.asarray(
        image, dtype=np.float32
    )

    image_array = np.expand_dims(image_array, axis=0)

    # Model training used raw RGB pixel values (0-255).
    score = float(
        np.asarray(model.predict(image_array, verbose=0)).reshape(-1)[0]
    )

    if not np.isfinite(score) or not 0 <= score <= 1:
        raise ValueError("Model returned an invalid prediction score.")

    # Assumes the training labels were:
    # fake = 0, real = 1
    prediction = "real" if score >= 0.5 else "fake"

    return {
        "prediction": prediction,
        "confidence": round(max(score, 1 - score) * 100, 2),
        "model_score": round(score, 4)
    }


# -----------------------------------
# Home page
# -----------------------------------

@app.route("/")
def home():
    return render_template("index.html")


# -----------------------------------
# Health check API
# -----------------------------------

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "project": "DeepShield",
        "status": "running",
        "model_loaded": model is not None
    })


# -----------------------------------
# Prediction API
# -----------------------------------

@app.route("/predict", methods=["POST"])
def predict():
    if "image" not in request.files:
        return jsonify({
            "error": "No image uploaded. Use the field name 'image'."
        }), 400

    uploaded_file = request.files["image"]

    if not uploaded_file.filename:
        return jsonify({"error": "Please select an image."}), 400

    try:
        image_bytes = uploaded_file.read(MAX_IMAGE_SIZE + 1)

        if not image_bytes:
            return jsonify({"error": "The uploaded file is empty."}), 400

        if len(image_bytes) > MAX_IMAGE_SIZE:
            return jsonify({"error": "Image must be 10 MB or smaller."}), 413

        import io

        with Image.open(io.BytesIO(image_bytes)) as image:
            image.load()
            result = predict_image(image)

        result["image"] = uploaded_file.filename

        return jsonify(result), 200

    except (UnidentifiedImageError, OSError):
        return jsonify({
            "error": "Invalid or unsupported image file."
        }), 400

    except Exception:
        app.logger.exception("Image prediction failed")
        return jsonify({
            "error": "Prediction failed. Check the server terminal."
        }), 500


# -----------------------------------
# Error handling
# -----------------------------------

@app.errorhandler(413)
def file_too_large(error):
    return jsonify({
        "error": "Image must be 10 MB or smaller."
    }), 413


# -----------------------------------
# Start server
# -----------------------------------

if __name__ == "__main__":
    app.run(
        host="127.0.0.1",
        port=5000,
        debug=False
    )
