import os
import shutil
import tempfile
import threading
import time
from fastapi import FastAPI, UploadFile, File, HTTPException, Response, Request
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from typing import List
import requests
from uuid import uuid4
from concurrent.futures import ThreadPoolExecutor

# === CONFIG ===
MAIN_BACKEND_URL = "http://127.0.0.1:8000"  # Change if your main backend is elsewhere

# === FastAPI app ===
app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"]
)

# === Progress tracking ===
progress_data = {}
progress_lock = threading.Lock()
executor = ThreadPoolExecutor(max_workers=4)

def set_progress(task_id, percent, status=""):
    with progress_lock:
        progress_data[task_id] = {"percent": percent, "status": status}

def get_progress(task_id):
    with progress_lock:
        return progress_data.get(task_id, {"percent": 0, "status": "starting"})

def remove_progress(task_id):
    with progress_lock:
        if task_id in progress_data:
            del progress_data[task_id]

# === Helper for cleaning up temp dirs ===
def safe_rmtree(path):
    try:
        shutil.rmtree(path)
    except Exception:
        pass

# === Helper for background upload with simulated progress ===
def background_forward_upload(task_id, temp_dir, file_paths, endpoint):
    try:
        # 1. Set progress at 50% (files received by proxy)
        set_progress(task_id, 0.5, "uploading to backend")

        # 2. Prepare files for requests
        files_payload = []
        for fp in file_paths:
            files_payload.append(('files', (os.path.basename(fp), open(fp, 'rb'))))
        # 3. Simulate progress 50%->95% while uploading
        def do_post():
            try:
                resp = requests.post(f"{MAIN_BACKEND_URL}{endpoint}", files=files_payload)
                return resp
            finally:
                for _, (_, f) in files_payload:
                    f.close()

        # Launch the POST in thread so we can simulate progress
        future = executor.submit(do_post)
        prog = 0.5
        while not future.done():
            prog = min(prog + 0.03, 0.95)
            set_progress(task_id, prog, "uploading to backend")
            time.sleep(0.5)
        resp = future.result()
        if resp.status_code == 200:
            set_progress(task_id, 1.0, "done")
        else:
            set_progress(task_id, 1.0, f"error:{resp.status_code}")
    except Exception as e:
        set_progress(task_id, 1.0, f"error:{e}")
    finally:
        safe_rmtree(temp_dir)

def background_forward_zip(task_id, temp_dir, zip_path, endpoint, fieldname="file"):
    try:
        set_progress(task_id, 0.5, "uploading to backend")
        def do_post():
            with open(zip_path, "rb") as f:
                files = {fieldname: (os.path.basename(zip_path), f)}
                resp = requests.post(f"{MAIN_BACKEND_URL}{endpoint}", files=files)
                return resp
        future = executor.submit(do_post)
        prog = 0.5
        while not future.done():
            prog = min(prog + 0.03, 0.95)
            set_progress(task_id, prog, "uploading to backend")
            time.sleep(0.5)
        resp = future.result()
        if resp.status_code == 200:
            set_progress(task_id, 1.0, "done")
        else:
            set_progress(task_id, 1.0, f"error:{resp.status_code}")
    except Exception as e:
        set_progress(task_id, 1.0, f"error:{e}")
    finally:
        safe_rmtree(temp_dir)

# === Upload folder endpoint ===
@app.post("/proxy/upload/")
async def proxy_upload(files: List[UploadFile] = File(...)):
    task_id = str(uuid4())
    temp_dir = tempfile.mkdtemp()
    file_paths = []
    try:
        # Save files to temp dir
        total = len(files)
        for idx, file in enumerate(files):
            out_path = os.path.join(temp_dir, file.filename)
            os.makedirs(os.path.dirname(out_path), exist_ok=True)
            with open(out_path, "wb") as f:
                while True:
                    chunk = await file.read(8192)
                    if not chunk:
                        break
                    f.write(chunk)
            file_paths.append(out_path)
            set_progress(task_id, (idx+1)/(total*2), "receiving files")
        # Forward in background
        threading.Thread(
            target=background_forward_upload,
            args=(task_id, temp_dir, file_paths, "/upload/"),
            daemon=True
        ).start()
        return {"task_id": task_id, "status": "started"}
    except Exception as e:
        safe_rmtree(temp_dir)
        set_progress(task_id, 1.0, f"error:{e}")
        raise HTTPException(500, f"Proxy upload error: {e}")

# === Upload ZIP endpoint ===
@app.post("/proxy/upload_zip/")
async def proxy_upload_zip(file: UploadFile = File(...)):
    task_id = str(uuid4())
    temp_dir = tempfile.mkdtemp()
    try:
        zip_path = os.path.join(temp_dir, file.filename)
        with open(zip_path, "wb") as f:
            while True:
                chunk = await file.read(8192)
                if not chunk:
                    break
                f.write(chunk)
        set_progress(task_id, 0.45, "zip received")
        threading.Thread(
            target=background_forward_zip,
            args=(task_id, temp_dir, zip_path, "/upload_zip/"),
            daemon=True
        ).start()
        return {"task_id": task_id, "status": "started"}
    except Exception as e:
        safe_rmtree(temp_dir)
        set_progress(task_id, 1.0, f"error:{e}")
        raise HTTPException(500, f"Proxy upload_zip error: {e}")

# === Progress endpoint ===
@app.get("/proxy/progress/{task_id}")
def proxy_progress(task_id: str):
    return get_progress(task_id)

# === Proxy export endpoints (download study/series/slice) ===
@app.get("/proxy/study/{study_id}/download")
def proxy_download_study(study_id: str, format: str = "jpeg"):
    backend_url = f"{MAIN_BACKEND_URL}/studies/{study_id}/export/zip?format={format}"
    resp = requests.get(backend_url, stream=True)
    if resp.status_code != 200:
        raise HTTPException(resp.status_code, f"Backend error: {resp.text}")
    # Forward the zip stream
    return StreamingResponse(resp.raw, media_type="application/zip", headers={
        "Content-Disposition": resp.headers.get("Content-Disposition", f"attachment; filename=study_{study_id}_{format}.zip")
    })

@app.get("/proxy/series/{study_id}/{series_id}/download")
def proxy_download_series(study_id: str, series_id: str, format: str = "jpeg"):
    backend_url = f"{MAIN_BACKEND_URL}/studies/{study_id}/series/{series_id}/export/zip?format={format}"
    resp = requests.get(backend_url, stream=True)
    if resp.status_code != 200:
        raise HTTPException(resp.status_code, f"Backend error: {resp.text}")
    return StreamingResponse(resp.raw, media_type="application/zip", headers={
        "Content-Disposition": resp.headers.get("Content-Disposition", f"attachment; filename=series_{series_id}_{format}.zip")
    })

@app.post("/proxy/export/slice")
async def proxy_export_slice(request: Request):
    # Forward POST to backend with form/multipart data as is
    backend_url = f"{MAIN_BACKEND_URL}/export/slice"
    form = await request.form()
    files = []
    data = {}
    for k, v in form.multi_items():
        if isinstance(v, UploadFile):
            files.append(('image_file', (v.filename, await v.read(), v.content_type)))
        else:
            data[k] = v
    resp = requests.post(backend_url, data=data, files=files, stream=True)
    if resp.status_code != 200:
        raise HTTPException(resp.status_code, f"Backend error: {resp.text}")
    return StreamingResponse(resp.raw, media_type="application/zip", headers={
        "Content-Disposition": resp.headers.get("Content-Disposition", "attachment; filename=slice_export.zip")
    })

# === CORS preflight ===
@app.options("/{rest_of_path:path}")
async def preflight(rest_of_path: str):
    return Response(headers={"Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "*", "Access-Control-Allow-Methods": "*"})

# === Optional: WebSocket for progress (not implemented here) ===

# === Clean up progress records after a while (optional improvement) ===
# You could launch a background thread to periodically remove old task_ids from progress_data.