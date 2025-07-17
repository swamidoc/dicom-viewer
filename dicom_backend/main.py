from fastapi import FastAPI, UploadFile, File, HTTPException, Response, Query, Form, status
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import os
import shutil
import pydicom
import numpy as np
from typing import List, Dict, Any
from PIL import Image
import io
import hashlib
import json
from cachetools import LRUCache
from concurrent.futures import ThreadPoolExecutor
import threading
import tempfile
import re
import zipfile
import SimpleITK as sitk

try:
    import moviepy.editor as mpy
    MOVIEPY_AVAILABLE = True
except ImportError:
    MOVIEPY_AVAILABLE = False

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

UPLOAD_ROOT = "./uploads"
STATIC_JPEG_DIRNAME = "images_jpeg"
METADATA_FILENAME = "metadata.json"

DEFAULT_WINDOW = 2000
DEFAULT_LEVEL = 1000

jpeg_cache = LRUCache(maxsize=2048)
mpr_cache = LRUCache(maxsize=512)

MAX_WORKERS = int(os.environ.get("DICOM_MAX_WORKERS", 2))
mpr_semaphore = threading.Semaphore(int(os.environ.get("DICOM_MPR_MAX", 2)))

def get_study_dir(study_id: str):
    return os.path.join(UPLOAD_ROOT, study_id)

def get_jpeg_dir(study_id: str):
    return os.path.join(get_study_dir(study_id), STATIC_JPEG_DIRNAME)

def get_metadata_path(study_id: str):
    return os.path.join(get_study_dir(study_id), METADATA_FILENAME)

def get_all_dicoms(study_path):
    dicoms = []
    for root, _, files in os.walk(study_path):
        for fname in files:
            if fname.lower().endswith('.dcm'):
                dicoms.append(os.path.join(root, fname))
    return dicoms

def dcm2jpeg(dcm_path, jpeg_path, window=DEFAULT_WINDOW, level=DEFAULT_LEVEL):
    ds = pydicom.dcmread(dcm_path)
    arr = ds.pixel_array.astype(np.float32)
    w = float(window)
    l = float(level)
    arr = np.clip((arr - (l - 0.5)) / (w - 1) + 0.5, 0, 1) * 255
    arr = arr.astype(np.uint8)
    img = Image.fromarray(arr)
    img.save(jpeg_path, format="JPEG")

def jpeg_cache_key(study_id, series_id, image_id):
    return f"{study_id}:{series_id}:{image_id}"

def mpr_cache_key(study_id, orientation, slice_index):
    return f"{study_id}:{orientation}:{slice_index}"

def extract_and_convert(study_id: str, study_dir: str):
    series_dict = {}
    jpeg_dir = get_jpeg_dir(study_id)
    if not os.path.exists(jpeg_dir):
        os.makedirs(jpeg_dir, exist_ok=True)
    dicom_paths = get_all_dicoms(study_dir)

    def convert_one(fpath):
        fname = os.path.relpath(fpath, study_dir)
        try:
            ds = pydicom.dcmread(fpath, stop_before_pixels=True, force=True)
            series_uid = getattr(ds, "SeriesInstanceUID", None)
            sop_uid = getattr(ds, "SOPInstanceUID", None)
            if not series_uid:
                series_uid = "SERIES_" + hashlib.md5(fname.encode()).hexdigest()
            if not sop_uid:
                sop_uid = "IMG_" + hashlib.md5(fname.encode()).hexdigest()
            series_desc = getattr(ds, "SeriesDescription", "Series")
            px_spacing = ds.get("PixelSpacing", [1.0, 1.0])
            spacing_x = float(px_spacing[1]) if len(px_spacing) > 1 else float(px_spacing[0])
            spacing_y = float(px_spacing[0])
            cols = int(getattr(ds, "Columns", 512))
            rows = int(getattr(ds, "Rows", 512))
            instance_num = int(getattr(ds, "InstanceNumber", 0))
            jpeg_filename = f"{series_uid}_{sop_uid}.jpg"
            jpeg_path = os.path.join(jpeg_dir, jpeg_filename)
            if not os.path.exists(jpeg_path):
                try:
                    dcm2jpeg(fpath, jpeg_path)
                except Exception:
                    return None
            try:
                with open(jpeg_path, "rb") as jf:
                    jpeg_bytes = jf.read()
                    cache_key = jpeg_cache_key(study_id, series_uid, sop_uid)
                    jpeg_cache[cache_key] = jpeg_bytes
            except Exception:
                pass
            window_center = DEFAULT_LEVEL
            window_width = DEFAULT_WINDOW
            return (
                series_uid, {
                    "image_id": sop_uid,
                    "filename": fname,
                    "jpeg_filename": jpeg_filename,
                    "instanceNumber": instance_num,
                    "pixelSpacingX": spacing_x,
                    "pixelSpacingY": spacing_y,
                    "Columns": cols,
                    "Rows": rows,
                    "WindowCenter": window_center,
                    "WindowWidth": window_width,
                },
                series_desc
            )
        except Exception:
            return None

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        for r in executor.map(convert_one, dicom_paths):
            if r is not None:
                series_uid, imgdict, sdesc = r
                if series_uid not in series_dict:
                    series_dict[series_uid] = {
                        "series_id": series_uid,
                        "seriesDescription": str(sdesc),
                        "images": []
                    }
                series_dict[series_uid]["images"].append(imgdict)
    for s in series_dict.values():
        s["images"].sort(key=lambda img: img["instanceNumber"])
    return list(series_dict.values())

def extract_study_metadata(study_dir: str):
    dicoms = get_all_dicoms(study_dir)
    if not dicoms:
        return {
            "patientName": "Unknown",
            "studyDate": "Unknown",
            "description": "No Description"
        }
    try:
        ds = pydicom.dcmread(dicoms[0], stop_before_pixels=True, force=True)
        return {
            "patientName": str(ds.get("PatientName", "Unknown")),
            "studyDate": str(ds.get("StudyDate", "Unknown")),
            "description": str(ds.get("StudyDescription", "No Description"))
        }
    except Exception:
        return {
            "patientName": "Unknown",
            "studyDate": "Unknown",
            "description": "No Description"
        }

def build_metadata_json(study_id: str, study_dir: str):
    meta = extract_study_metadata(study_dir)
    structure = extract_and_convert(study_id, study_dir)
    meta_json = {
        "study_id": study_id,
        "patientName": meta["patientName"],
        "studyDate": meta["studyDate"],
        "description": meta["description"],
        "series": structure,
        "ai_analysis": None
    }
    with open(get_metadata_path(study_id), "w") as f:
        json.dump(meta_json, f)
    return meta_json

def load_metadata_json(study_id: str):
    try:
        with open(get_metadata_path(study_id), "r") as f:
            return json.load(f)
    except Exception:
        return None

def make_json_serializable(obj):
    if isinstance(obj, (str, int, float, bool, type(None))):
        return obj
    if isinstance(obj, dict):
        return {k: make_json_serializable(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple, set)):
        return [make_json_serializable(v) for v in obj]
    return str(obj)

def safe_name(s):
    return re.sub(r"[^a-zA-Z0-9_\-. ]", "_", s.strip().replace("/", "_"))

def iter_file_chunks(file_path, chunk_size=8192):
    with open(file_path, "rb") as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            yield chunk

app.mount("/images", StaticFiles(directory=UPLOAD_ROOT), name="images")

@app.get("/studies/{study_id}/series/{series_id}/export/file")
def export_series_file(study_id: str, series_id: str, format: str = Query("jpeg")):
    study_dir = get_study_dir(study_id)
    jpeg_dir = get_jpeg_dir(study_id)
    meta_json = load_metadata_json(study_id)
    if not meta_json:
        raise HTTPException(404, "Study not found")
    series = next((s for s in meta_json["series"] if s["series_id"] == series_id), None)
    if not series:
        raise HTTPException(404, "Series not found")
    series_folder = safe_name(series["seriesDescription"])
    patient_folder = f"{safe_name(meta_json['patientName'])}_{safe_name(meta_json['studyDate'])}_{safe_name(meta_json['description'])}"

    if format == "jpeg":
        # Export all JPEGs as a zip
        temp_zip = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
        with zipfile.ZipFile(temp_zip, "w") as zipf:
            for img in series["images"]:
                jpeg_path = os.path.join(jpeg_dir, img["jpeg_filename"])
                if os.path.exists(jpeg_path):
                    zipf.write(jpeg_path, arcname=img["jpeg_filename"])
        temp_zip.close()
        return FileResponse(temp_zip.name, filename=f"{patient_folder}_{series_folder}.zip", media_type="application/zip")
    elif format == "dicom":
        # Export all DICOMs as a zip
        temp_zip = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
        with zipfile.ZipFile(temp_zip, "w") as zipf:
            for img in series["images"]:
                dcm_path = os.path.join(study_dir, img["filename"])
                if os.path.exists(dcm_path):
                    zipf.write(dcm_path, arcname=img["filename"])
        temp_zip.close()
        return FileResponse(temp_zip.name, filename=f"{patient_folder}_{series_folder}_dicom.zip", media_type="application/zip")
    elif format == "mp4":
        if not MOVIEPY_AVAILABLE:
            raise HTTPException(500, "moviepy not installed on server")
        frames = []
        for img in series["images"]:
            jpeg_path = os.path.join(jpeg_dir, img["jpeg_filename"])
            if os.path.exists(jpeg_path):
                frames.append(np.array(Image.open(jpeg_path)))
        if not frames:
            raise HTTPException(404, "No JPEGs found for MP4 export")
        tempdir = tempfile.mkdtemp()
        try:
            mp4_path = os.path.join(tempdir, f"{series_folder}.mp4")
            clip = mpy.ImageSequenceClip(frames, fps=12)
            clip.write_videofile(mp4_path, codec="libx264", fps=12, audio=False, verbose=False, logger=None)
            filename = f"{patient_folder}_{series_folder}.mp4"
            return FileResponse(mp4_path, filename=filename, media_type="video/mp4")
        finally:
            shutil.rmtree(tempdir)
    else:
        raise HTTPException(400, "Invalid format requested")

@app.get("/studies/{study_id}/export/file")
def export_study_file(study_id: str, format: str = Query("jpeg")):
    study_dir = get_study_dir(study_id)
    jpeg_dir = get_jpeg_dir(study_id)
    meta_json = load_metadata_json(study_id)
    if not meta_json:
        raise HTTPException(404, "Study not found")
    patient_folder = f"{safe_name(meta_json['patientName'])}_{safe_name(meta_json['studyDate'])}_{safe_name(meta_json['description'])}"
    if format == "jpeg":
        temp_zip = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
        with zipfile.ZipFile(temp_zip, "w") as zipf:
            for series in meta_json["series"]:
                series_folder = safe_name(series["seriesDescription"])
                for img in series["images"]:
                    jpeg_path = os.path.join(jpeg_dir, img["jpeg_filename"])
                    if os.path.exists(jpeg_path):
                        zipf.write(jpeg_path, arcname=f"{series_folder}/{img['jpeg_filename']}")
        temp_zip.close()
        return FileResponse(temp_zip.name, filename=f"{patient_folder}.zip", media_type="application/zip")
    elif format == "dicom":
        temp_zip = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
        with zipfile.ZipFile(temp_zip, "w") as zipf:
            for series in meta_json["series"]:
                series_folder = safe_name(series["seriesDescription"])
                for img in series["images"]:
                    dcm_path = os.path.join(study_dir, img["filename"])
                    if os.path.exists(dcm_path):
                        zipf.write(dcm_path, arcname=f"{series_folder}/{img['filename']}")
        temp_zip.close()
        return FileResponse(temp_zip.name, filename=f"{patient_folder}_dicom.zip", media_type="application/zip")
    elif format == "mp4":
        if not MOVIEPY_AVAILABLE:
            raise HTTPException(500, "moviepy not installed on server")
        frames = []
        for series in meta_json["series"]:
            for img in series["images"]:
                jpeg_path = os.path.join(jpeg_dir, img["jpeg_filename"])
                if os.path.exists(jpeg_path):
                    frames.append(np.array(Image.open(jpeg_path)))
        if not frames:
            raise HTTPException(404, "No JPEGs found for MP4 export")
        tempdir = tempfile.mkdtemp()
        try:
            mp4_path = os.path.join(tempdir, f"{patient_folder}.mp4")
            clip = mpy.ImageSequenceClip(frames, fps=12)
            clip.write_videofile(mp4_path, codec="libx264", fps=12, audio=False, verbose=False, logger=None)
            filename = f"{patient_folder}.mp4"
            return FileResponse(mp4_path, filename=filename, media_type="video/mp4")
        finally:
            shutil.rmtree(tempdir)
    else:
        raise HTTPException(400, "Invalid format requested")

@app.get("/studies/{study_id}/series/{series_id}/image/{image_id}")
def get_series_image(study_id: str, series_id: str, image_id: str, format: str = Query("jpeg")):
    study_dir = get_study_dir(study_id)
    jpeg_dir = get_jpeg_dir(study_id)
    meta_json = load_metadata_json(study_id)
    if not meta_json:
        raise HTTPException(404, "Study not found")
    series = next((s for s in meta_json["series"] if s["series_id"] == series_id), None)
    if not series:
        raise HTTPException(404, "Series not found")
    image = next((img for img in series["images"] if img["image_id"] == image_id), None)
    if not image:
        raise HTTPException(404, "Image not found")
    if format == "jpeg":
        jpeg_path = os.path.join(jpeg_dir, image["jpeg_filename"])
        if not os.path.exists(jpeg_path):
            dcm_path = os.path.join(study_dir, image["filename"])
            if not os.path.exists(dcm_path):
                raise HTTPException(404, "DICOM not found")
            dcm2jpeg(dcm_path, jpeg_path)
        return FileResponse(jpeg_path, media_type="image/jpeg")
    elif format == "dicom":
        dcm_path = os.path.join(study_dir, image["filename"])
        if not os.path.exists(dcm_path):
            raise HTTPException(404, "DICOM not found")
        return FileResponse(dcm_path, media_type="application/dicom")
    else:
        raise HTTPException(400, "Invalid format")

@app.delete("/studies/{study_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_study(study_id: str):
    study_dir = get_study_dir(study_id)
    if not os.path.exists(study_dir):
        raise HTTPException(404, "Study not found")
    try:
        shutil.rmtree(study_dir)
    except Exception as e:
        raise HTTPException(500, f"Failed to delete study: {e}")
    return Response(status_code=status.HTTP_204_NO_CONTENT)

@app.post("/upload/")
async def upload_files(files: List[UploadFile] = File(...)):
    os.makedirs(UPLOAD_ROOT, exist_ok=True)
    study_id = str(len([d for d in os.listdir(UPLOAD_ROOT) if os.path.isdir(os.path.join(UPLOAD_ROOT, d))]) + 1)
    study_dir = get_study_dir(study_id)
    os.makedirs(study_dir, exist_ok=True)
    for file in files:
        file_location = os.path.join(study_dir, file.filename)
        os.makedirs(os.path.dirname(file_location), exist_ok=True)
        with open(file_location, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    build_metadata_json(study_id, study_dir)
    return JSONResponse({"status": "ok", "study_id": study_id})

@app.post("/upload_zip/")
async def upload_zip(file: UploadFile = File(...)):
    os.makedirs(UPLOAD_ROOT, exist_ok=True)
    study_id = str(len([d for d in os.listdir(UPLOAD_ROOT) if os.path.isdir(os.path.join(UPLOAD_ROOT, d))]) + 1)
    study_dir = get_study_dir(study_id)
    os.makedirs(study_dir, exist_ok=True)
    zip_path = os.path.join(study_dir, file.filename)
    with open(zip_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    try:
        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            zip_ref.extractall(study_dir)
        os.remove(zip_path)
        build_metadata_json(study_id, study_dir)
    except Exception as e:
        shutil.rmtree(study_dir)
        raise HTTPException(400, detail=f"Failed to extract zip: {e}")
    return {"status": "ok", "study_id": study_id}

@app.get("/studies")
def list_studies():
    studies = []
    if os.path.exists(UPLOAD_ROOT):
        for study_folder in sorted(os.listdir(UPLOAD_ROOT)):
            study_dir = get_study_dir(study_folder)
            if os.path.isdir(study_dir):
                meta_json = load_metadata_json(study_folder)
                if not meta_json:
                    meta_json = build_metadata_json(study_folder, study_dir)
                studies.append(meta_json)
    if not studies:
        studies.append({
            "study_id": "demo",
            "patientName": "Demo Patient",
            "studyDate": "2025-01-01",
            "description": "Demo Chest CT",
            "series": [
                {
                    "series_id": "demo_axial",
                    "seriesDescription": "Axial Demo CT",
                    "images": [
                        {
                            "image_id": f"demo_ax_{i}",
                            "filename": f"demo_ax_{i}.dcm",
                            "jpeg_filename": f"demo_axial_demo_ax_{i}.jpg",
                            "instanceNumber": i,
                            "pixelSpacingX": 1.0,
                            "pixelSpacingY": 1.0,
                            "Columns": 512,
                            "Rows": 512,
                            "WindowCenter": DEFAULT_LEVEL,
                            "WindowWidth": DEFAULT_WINDOW,
                        } for i in range(1, 11)
                    ],
                },
                {
                    "series_id": "demo_coronal",
                    "seriesDescription": "Coronal Demo CT",
                    "images": [
                        {
                            "image_id": f"demo_cor_{i}",
                            "filename": f"demo_cor_{i}.dcm",
                            "jpeg_filename": f"demo_coronal_demo_cor_{i}.jpg",
                            "instanceNumber": i,
                            "pixelSpacingX": 1.0,
                            "pixelSpacingY": 1.0,
                            "Columns": 512,
                            "Rows": 512,
                            "WindowCenter": DEFAULT_LEVEL,
                            "WindowWidth": DEFAULT_WINDOW,
                        } for i in range(1, 9)
                    ],
                },
            ],
            "ai_analysis": None
        })
    return JSONResponse(make_json_serializable(studies))

@app.get("/studies/{study_id}")
def get_study_detail(study_id: str):
    study_dir = get_study_dir(study_id)
    if not os.path.exists(study_dir):
        raise HTTPException(404, "Study not found")
    meta_json = load_metadata_json(study_id)
    if not meta_json:
        meta_json = build_metadata_json(study_id, study_dir)
    return JSONResponse(make_json_serializable(meta_json))