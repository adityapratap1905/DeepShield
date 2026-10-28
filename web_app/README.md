# DeepShield web dashboard

This standalone Flask dashboard is separate from Flutter's platform runner in `mobile_app/web/`. It serves one image upload flow backed by the bundled `model/deepshield_final.keras` binary classifier. This model is separate from the ONNX and FaceForensics++ pipelines in `model/` and does not establish image authenticity.

## Run locally

Use Python 3.11 or newer from the repository root:

```powershell
py -3 -m venv web_app/.venv
web_app/.venv/Scripts/Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r web_app/requirements.txt
python web_app/app.py
```

Open `http://127.0.0.1:5000`. `GET /health` reports whether the bundled model loaded. `POST /predict` accepts multipart field `image` with a JPEG or PNG up to 10 MB. Set `DEEPSHIELD_WEB_MAX_IMAGE_BYTES` to adjust the limit. The server binds to localhost and runs without Flask debug mode by default.

The response's `prediction` and `model_score` are estimates from the bundled model, and `confidence` is an uncalibrated model score. Do not treat a `real` result as proof that an image is authentic. The model's training and validation provenance is not documented in this repository, so no accuracy claims are made here. Set `DEEPSHIELD_WEB_MODEL_PATH` if the model is stored elsewhere.
