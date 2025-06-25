import os
import json
from fastapi import FastAPI, UploadFile, File, Query
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import pydicom
import numpy as np
from PIL import Image

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

app = FastAPI()

# Allow CORS for local Flutter/web dev (in production, change to your frontend domain)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

WINDOW_PRESETS = {
    "bone":    {"window": 2000, "level": 500},
    "lung":    {"window": 1500, "level": -600},
    "brain":   {"window": 80,   "level": 40},
    "abdomen": {"window": 400,  "level": 50},
}

def apply_window(arr, window_center, window_width):
    arr = arr.astype(np.float32)
    img = np.clip((arr - window_center + window_width / 2) / window_width * 255, 0, 255)
    return img.astype(np.uint8)

def get_pixel_spacing(ds):
    # Try to fetch PixelSpacing, fallback to ImagerPixelSpacing, else [1.0, 1.0]
    val = getattr(ds, "PixelSpacing", None)
    if val is None:
        val = getattr(ds, "ImagerPixelSpacing", None)
    if val is not None:
        return [float(v) for v in val]
    else:
        return [1.0, 1.0]

@app.post("/upload/")
async def upload_dicom(file: UploadFile = File(...)):
    filename = file.filename
    file_path = os.path.join(UPLOAD_DIR, filename)
    with open(file_path, "wb") as f:
        f.write(await file.read())

    ds = pydicom.dcmread(file_path)
    images = []
    # Get image window/level, if available
    win_center = float(ds.WindowCenter[0] if isinstance(ds.WindowCenter, pydicom.multival.MultiValue) else ds.WindowCenter) if hasattr(ds, "WindowCenter") else np.mean(ds.pixel_array)
    win_width = float(ds.WindowWidth[0] if isinstance(ds.WindowWidth, pydicom.multival.MultiValue) else ds.WindowWidth) if hasattr(ds, "WindowWidth") else np.ptp(ds.pixel_array)

    # Multi-frame support
    if hasattr(ds, "NumberOfFrames") and ds.NumberOfFrames > 1:
        arr = ds.pixel_array
        for i, frame in enumerate(arr):
            img_path = f"{file_path}_frame_{i+1}.png"
            img = Image.fromarray(apply_window(frame, win_center, win_width))
            img.save(img_path)
            images.append(os.path.basename(img_path))
    else:
        arr = ds.pixel_array
        img_path = file_path.replace(".dcm", ".png")
        img = Image.fromarray(apply_window(arr, win_center, win_width))
        img.save(img_path)
        images.append(os.path.basename(img_path))

    meta = {
        "patient_name": str(getattr(ds, "PatientName", "")),
        "study_date": str(getattr(ds, "StudyDate", "")),
        "description": str(getattr(ds, "StudyDescription", "")),
        "dicom_file": filename,
        "images": images,
        "pixel_spacing": get_pixel_spacing(ds)
    }
    meta_path = file_path + ".json"
    with open(meta_path, "w") as f:
        json.dump(meta, f)
    return meta

@app.get("/studies/")
def list_studies():
    studies = []
    for fname in os.listdir(UPLOAD_DIR):
        if fname.endswith(".dcm.json"):
            with open(os.path.join(UPLOAD_DIR, fname)) as f:
                studies.append(json.load(f))
    return studies

@app.get("/images/{image_name}")
def get_image(image_name: str, window: str = Query(None), level: float = Query(None), width: float = Query(None)):
    path = os.path.join(UPLOAD_DIR, image_name)
    if not os.path.exists(path):
        return JSONResponse({"error": "Image not found"}, status_code=404)

    # If a window preset or custom window/level is requested
    if window in WINDOW_PRESETS or (level is not None and width is not None):
        # Find the original DICOM file for this image
        # For multi-frame: filename_frame_x.png → filename.dcm
        ds_path = path.split("_frame_")[0].replace(".png", ".dcm")
        if not os.path.exists(ds_path):
            return JSONResponse({"error": "DICOM source not found"}, status_code=404)
        ds = pydicom.dcmread(ds_path)
        arr = ds.pixel_array
        if "_frame_" in path:
            idx = int(path.split("_frame_")[1].split(".")[0]) - 1
            arr = arr[idx]
        if window in WINDOW_PRESETS:
            preset = WINDOW_PRESETS[window]
            wlevel = preset["level"]
            wwidth = preset["window"]
        else:
            wlevel = level if level is not None else float(ds.WindowCenter) if hasattr(ds, "WindowCenter") else np.mean(arr)
            wwidth = width if width is not None else float(ds.WindowWidth) if hasattr(ds, "WindowWidth") else np.ptp(arr)
        img = Image.fromarray(apply_window(arr, wlevel, wwidth))
        tmp_path = path.replace(".png", f"_preview.png")
        img.save(tmp_path)
        return FileResponse(tmp_path)
    return FileResponse(path)

@app.get("/metadata/{dicom_file}")
def get_metadata(dicom_file: str):
    file_path = os.path.join(UPLOAD_DIR, dicom_file)
    if not os.path.exists(file_path):
        return JSONResponse({"error": "DICOM file not found"}, status_code=404)
    ds = pydicom.dcmread(file_path)
    meta = {
        "patient_name": str(getattr(ds, "PatientName", "")),
        "study_date": str(getattr(ds, "StudyDate", "")),
        "description": str(getattr(ds, "StudyDescription", "")),
        "pixel_spacing": get_pixel_spacing(ds)
    }
    return meta