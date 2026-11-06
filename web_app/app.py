
"""Standalone Flask website for DeepShield image analysis."""

import io
import json
import os
import threading
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request as UrlRequest, urlopen

import numpy as np
import tensorflow as tf
from PIL import Image, ImageOps, UnidentifiedImageError
from flask import Flask, Response, request, jsonify, render_template, send_from_directory

# -----------------------------------
# DeepShield configuration
# -----------------------------------

app = Flask(__name__)
BASE_DIR = Path(__file__).resolve().parent
app.config["MAX_CONTENT_LENGTH"] = int(
    os.getenv("DEEPSHIELD_WEB_PROXY_MAX_BYTES", str(210 * 1024 * 1024))
)

MODEL_PATH = Path(
    os.getenv("DEEPSHIELD_WEB_MODEL_PATH", str(BASE_DIR.parent / "model" / "deepshield_final.keras"))
)

IMAGE_SIZE = (224, 224)
MAX_IMAGE_SIZE = int(os.getenv("DEEPSHIELD_WEB_MAX_IMAGE_BYTES", str(10 * 1024 * 1024)))
MAX_IMAGE_PIXELS = 40_000_000
Image.MAX_IMAGE_PIXELS = MAX_IMAGE_PIXELS
PREDICTION_LOCK = threading.Lock()
AUTH_API_BASE_URL = os.getenv("DEEPSHIELD_API_BASE_URL", "http://127.0.0.1:8000").rstrip("/")
SPA_DIST_DIR = BASE_DIR / "static" / "site"

# -----------------------------------
# Load trained model
# -----------------------------------

print("Loading DeepShield model...")

if not MODEL_PATH.is_file():
    raise FileNotFoundError(
        f"Model not found: {MODEL_PATH}\n"
        "Set DEEPSHIELD_WEB_MODEL_PATH to the bundled model path."
    )

model = tf.keras.models.load_model(MODEL_PATH)

print("DeepShield model loaded successfully!")


# -----------------------------------
# Image prediction
# -----------------------------------

def predict_image(image):
    image = ImageOps.exif_transpose(image).convert("RGB").resize(IMAGE_SIZE)

    image_array = np.asarray(
        image, dtype=np.float32
    )

    image_array = np.expand_dims(image_array, axis=0)

    # Model training used raw RGB pixel values (0-255).
    with PREDICTION_LOCK:
        score = float(np.asarray(model.predict(image_array, verbose=0)).reshape(-1)[0])

    if not np.isfinite(score) or not 0 <= score <= 1:
        raise ValueError("Model returned an invalid prediction score.")

    # The bundled model was trained with fake=0 and real=1.
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
    built_index = SPA_DIST_DIR / "index.html"
    if built_index.is_file():
        return send_from_directory(SPA_DIST_DIR, "index.html")
    return render_template("index.html")


# -----------------------------------
# React website API proxy
# -----------------------------------

API_METHODS = {
    "health": "GET",
    "v1/auth/register": "POST",
    "v1/auth/login": "POST",
    "v1/auth/me": "GET",
    "v1/auth/logout": "POST",
    "v1/scan/image": "POST",
    "v2/detect/image": "POST",
    "v2/detect/video": "POST",
}


@app.route("/api/<path:api_path>", methods=["GET", "POST"])
def proxy_api(api_path):
    expected_method = API_METHODS.get(api_path)
    if expected_method is None:
        return jsonify({"detail": "API route not found."}), 404
    if request.method != expected_method:
        return jsonify({"detail": "Method not allowed."}), 405

    headers = {"Accept": "application/json"}
    authorization = request.headers.get("Authorization")
    if authorization:
        headers["Authorization"] = authorization
    if request.content_type:
        headers["Content-Type"] = request.content_type

    body = request.get_data(cache=False) if request.method == "POST" else None
    upstream_path = "/health" if api_path == "health" else f"/api/{api_path}"
    upstream_request = UrlRequest(
        f"{AUTH_API_BASE_URL}{upstream_path}",
        data=body,
        headers=headers,
        method=expected_method,
    )
    timeout = 600 if api_path in {"v1/scan/image", "v2/detect/image", "v2/detect/video"} else 20

    try:
        with urlopen(upstream_request, timeout=timeout) as upstream_response:
            response_body = upstream_response.read()
            response_status = upstream_response.status
            response_type = upstream_response.headers.get("Content-Type", "application/json")
    except HTTPError as error:
        response_body = error.read()
        response_status = error.code
        response_type = error.headers.get("Content-Type", "application/json")
    except (URLError, TimeoutError, OSError):
        return jsonify({
            "detail": "Could not reach DeepShield FastAPI. Start the backend and try again."
        }), 503

    return Response(response_body, status=response_status, content_type=response_type)


# -----------------------------------
# Existing backend authentication proxy
# -----------------------------------

@app.route("/auth/<string:action>", methods=["GET", "POST"])
def proxy_auth(action):
    allowed_methods = {
        "register": "POST",
        "login": "POST",
        "me": "GET",
        "logout": "POST",
    }
    expected_method = allowed_methods.get(action)
    if expected_method is None:
        return jsonify({"error": "Authentication action not found."}), 404
    if request.method != expected_method:
        return jsonify({"error": "Method not allowed."}), 405

    headers = {"Accept": "application/json"}
    authorization = request.headers.get("Authorization")
    if authorization:
        headers["Authorization"] = authorization

    body = None
    if request.method == "POST" and action in {"register", "login"}:
        payload = request.get_json(silent=True)
        if not isinstance(payload, dict):
            return jsonify({"error": "Send account details as JSON."}), 400
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    upstream_request = UrlRequest(
        f"{AUTH_API_BASE_URL}/api/v1/auth/{action}",
        data=body,
        headers=headers,
        method=expected_method,
    )

    try:
        with urlopen(upstream_request, timeout=15) as upstream_response:
            response_body = upstream_response.read()
            response_status = upstream_response.status
            response_type = upstream_response.headers.get("Content-Type", "application/json")
    except HTTPError as error:
        response_body = error.read()
        response_status = error.code
        response_type = error.headers.get("Content-Type", "application/json")
    except (URLError, TimeoutError, OSError):
        return jsonify({
            "error": "Could not reach DeepShield authentication. Start the backend and try again."
        }), 503

    return Response(response_body, status=response_status, content_type=response_type)


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

        with Image.open(io.BytesIO(image_bytes)) as image:
            if image.format not in {"JPEG", "PNG"}:
                return jsonify({"error": "Only JPEG and PNG images are supported."}), 415
            if image.width * image.height > MAX_IMAGE_PIXELS:
                return jsonify({"error": "Image dimensions are too large."}), 413
            image.verify()
        with Image.open(io.BytesIO(image_bytes)) as image:
            image.load()
            result = predict_image(image)

        result["image"] = uploaded_file.filename

        return jsonify(result), 200

    except Image.DecompressionBombError:
        return jsonify({"error": "Image dimensions are too large."}), 413

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
        "error": "Uploaded file exceeds the website upload limit."
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
