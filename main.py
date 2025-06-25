import os
import json
import uuid
from datetime import datetime
from typing import List
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

ALLOWED_EXTENSIONS = {".dcm", ".dicom", ".jpg", ".jpeg", ".jp2", ".png", ".bmp"}

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict this!
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def allowed_file(filename):
    ext = os.path.splitext(filename)[1].lower()
    return ext in ALLOWED_EXTENSIONS

@app.post("/upload/")
async def upload_files(files: List[UploadFile] = File(...)):
    """
    Accepts multiple files upload for folder support.
    """
    saved_files = []
    for file in files:
        filename = file.filename
        ext = os.path.splitext(filename)[1].lower()
        if not allowed_file(filename):
            continue
        now = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_id = str(uuid.uuid4())[:8]
        safe_filename = f"{now}_{unique_id}_{os.path.basename(filename)}"
        out_path = os.path.join(UPLOAD_DIR, safe_filename)
        with open(out_path, "wb") as f:
            content = await file.read()
            f.write(content)
        saved_files.append(safe_filename)
    return {"files": saved_files}

@app.get("/studies/")
def list_studies():
    files = []
    for filename in os.listdir(UPLOAD_DIR):
        files.append({
            "filename": filename,
            "upload_time": os.path.getctime(os.path.join(UPLOAD_DIR, filename))
        })
    # Sort by upload time, latest first
    files.sort(key=lambda f: -f["upload_time"])
    return files

@app.get("/download/{filename}")
def download_file(filename: str):
    path = os.path.join(UPLOAD_DIR, filename)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(path, filename=filename)

@app.delete("/delete/{filename}")
def delete_file(filename: str):
    path = os.path.join(UPLOAD_DIR, filename)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="File not found")
    os.remove(path)
    return {"detail": "File deleted"}