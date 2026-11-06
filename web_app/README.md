# DeepShield web application

The website uses the React, TypeScript, Vite, Tailwind CSS, and lucide-react interface from the supplied DeepShield project archive. It keeps the website inside `web_app/` and uses the existing FastAPI authentication and inference endpoints. It is separate from Flutter's web platform runner in `mobile_app/web/`.

The website includes a public landing page, backend-backed registration/login, and an authenticated dashboard for photo and video analysis. The photo scanner uses the existing FastAPI whole-image and face-manipulation signals endpoint. The video scanner uses the FaceForensics++ frame-sampling endpoint. Both are distinct from the bundled Keras classifier used by the legacy Flask `/predict` route.

## Local development

Use Python 3.11 or newer, Node.js/npm, and the backend environment. The FastAPI backend must be running for account access, model status, and media analysis.

Terminal 1, from the repository root:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
$env:DEEPSHIELD_AUTH_SECRET = [Environment]::GetEnvironmentVariable("DEEPSHIELD_AUTH_SECRET", "User")
if ([string]::IsNullOrWhiteSpace($env:DEEPSHIELD_AUTH_SECRET)) { throw "Saved auth secret not found." }
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Terminal 2:

```powershell
cd "D:\Gla\Mini Project\deepshield\web_app"
npm install
npm run dev
```

Open `http://localhost:3000`. Vite forwards `/api` requests to the FastAPI backend at `http://127.0.0.1:8000`. Override the target with `DEEPSHIELD_API_PROXY_TARGET` if needed. The backend reads `DEEPSHIELD_AUTH_SECRET` from its environment or `backend/.env`.

The photo route needs its pretrained image and face models. The video route needs the trained FF++ image checkpoint and video configuration. Open the dashboard's **Model status** section or `http://127.0.0.1:8000/health` to see which artifacts are loaded. The scanner reports unavailable models without substituting sample scores.

## Build and serve with Flask

Build the Vite app to `web_app/static/site/`:

```powershell
cd "D:\Gla\Mini Project\deepshield\web_app"
npm install
npm run build
```

Then, from the repository root, create the Flask environment and run the server:

```powershell
py -3 -m venv web_app/.venv
web_app/.venv/Scripts/Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r web_app/requirements.txt
python web_app/app.py
```

Open `http://127.0.0.1:5000`. Flask serves the built React app and forwards its allowed `/api/*` requests to FastAPI. Set `DEEPSHIELD_API_BASE_URL` if FastAPI is hosted at another address. The built website requires the backend to be running.

## Existing Flask image endpoint

`POST /predict` remains available for the older bundled Keras binary classifier, using multipart field `image` and JPEG/PNG files up to 10 MB. This route is not used by the React scanner. Its score is uncalibrated, its training provenance is undocumented, and a `real` output does not prove authenticity. Set `DEEPSHIELD_WEB_MODEL_PATH` if that model is stored elsewhere.
