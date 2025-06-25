from fastapi import FastAPI, UploadFile, File, HTTPException, Response
from fastapi.responses import JSONResponse, FileResponse
import os
import shutil
import pydicom
import numpy as np
from typing import List, Dict, Any
from PIL import Image
import io
import hashlib

app = FastAPI()

def make_json_serializable(obj):
    if isinstance(obj, (str, int, float, bool, type(None))):
        return obj
    if isinstance(obj, dict):
        return {k: make_json_serializable(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple, set)):
        return [make_json_serializable(v) for v in obj]
    return str(obj)

def extract_study_structure(study_path: str) -> List[Dict[str, Any]]:
    """Extracts DICOM structure: series and images per series."""
    series_dict = {}
    for fname in os.listdir(study_path):
        if fname.lower().endswith('.dcm'):
            fpath = os.path.join(study_path, fname)
            try:
                ds = pydicom.dcmread(fpath, stop_before_pixels=True, force=True)
                series_uid = getattr(ds, "SeriesInstanceUID", None)
                sop_uid = getattr(ds, "SOPInstanceUID", None)
                if not series_uid:
                    series_uid = "SERIES_" + hashlib.md5((fname).encode()).hexdigest()
                if not sop_uid:
                    sop_uid = "IMG_" + hashlib.md5((fname).encode()).hexdigest()
                series_desc = getattr(ds, "SeriesDescription", "Series")
                if series_uid not in series_dict:
                    series_dict[series_uid] = {
                        "series_id": series_uid,
                        "seriesDescription": str(series_desc),
                        "images": []
                    }
                series_dict[series_uid]["images"].append({
                    "image_id": sop_uid,
                    "filename": fname,
                    "instanceNumber": int(getattr(ds, "InstanceNumber", 0)),
                })
            except Exception:
                continue
    for s in series_dict.values():
        s["images"].sort(key=lambda img: img["instanceNumber"])
    return list(series_dict.values())

def extract_study_metadata(study_path: str) -> Dict[str, str]:
    dicoms = [f for f in os.listdir(study_path) if f.lower().endswith('.dcm')]
    if not dicoms:
        return {
            "patientName": "Unknown",
            "studyDate": "Unknown",
            "description": "No Description"
        }
    try:
        ds = pydicom.dcmread(os.path.join(study_path, dicoms[0]), stop_before_pixels=True, force=True)
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

@app.post("/upload/")
async def upload_files(files: List[UploadFile] = File(...)):
    upload_dir = "./uploads"
    os.makedirs(upload_dir, exist_ok=True)
    study_id = str(len([d for d in os.listdir(upload_dir) if os.path.isdir(os.path.join(upload_dir, d))]) + 1)
    study_dir = os.path.join(upload_dir, study_id)
    os.makedirs(study_dir, exist_ok=True)
    for file in files:
        file_location = os.path.join(study_dir, file.filename)
        with open(file_location, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    return JSONResponse({"status": "ok", "study_id": study_id})

@app.get("/studies")
def list_studies():
    studies_dir = "./uploads"
    studies = []
    if os.path.exists(studies_dir):
        for study_folder in sorted(os.listdir(studies_dir)):
            study_path = os.path.join(studies_dir, study_folder)
            if os.path.isdir(study_path):
                meta = extract_study_metadata(study_path)
                structure = extract_study_structure(study_path)
                studies.append({
                    "study_id": study_folder,
                    "patientName": meta["patientName"],
                    "studyDate": meta["studyDate"],
                    "description": meta["description"],
                    "series": structure
                })
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
                    "images": [{"image_id": f"demo_ax_{i}", "filename": f"demo_ax_{i}.dcm", "instanceNumber": i} for i in range(1, 11)],
                },
                {
                    "series_id": "demo_coronal",
                    "seriesDescription": "Coronal Demo CT",
                    "images": [{"image_id": f"demo_cor_{i}", "filename": f"demo_cor_{i}.dcm", "instanceNumber": i} for i in range(1, 9)],
                },
            ]
        })
    return JSONResponse(make_json_serializable(studies))

@app.get("/studies/{study_id}")
def get_study_detail(study_id: str):
    study_path = os.path.join("./uploads", study_id)
    if not os.path.exists(study_path):
        raise HTTPException(404, "Study not found")
    meta = extract_study_metadata(study_path)
    structure = extract_study_structure(study_path)
    return JSONResponse(make_json_serializable({
        "study_id": study_id,
        "patientName": meta["patientName"],
        "studyDate": meta["studyDate"],
        "description": meta["description"],
        "series": structure
    }))

@app.get("/studies/{study_id}/series/{series_id}/image/{image_id}")
def get_image(
    study_id: str,
    series_id: str,
    image_id: str,
    format: str = "raw",
    window: float = None,
    level: float = None,
):
    study_path = os.path.join("./uploads", study_id)
    if not os.path.exists(study_path):
        raise HTTPException(404, "Study not found")
    files = os.listdir(study_path)
    target_file = None
    for fname in files:
        if not fname.lower().endswith('.dcm'):
            continue
        try:
            ds = pydicom.dcmread(os.path.join(study_path, fname), stop_before_pixels=True, force=True)
            sid = getattr(ds, "SeriesInstanceUID", None)
            iid = getattr(ds, "SOPInstanceUID", None)
            if not sid:
                sid = "SERIES_" + hashlib.md5((fname).encode()).hexdigest()
            if not iid:
                iid = "IMG_" + hashlib.md5((fname).encode()).hexdigest()
            if sid == series_id and iid == image_id:
                target_file = fname
                break
        except Exception:
            continue
    if not target_file:
        raise HTTPException(404, "Image not found")
    dcm_path = os.path.join(study_path, target_file)
    if format == "raw":
        return FileResponse(dcm_path, media_type="application/dicom")
    elif format == "jpeg":
        try:
            ds = pydicom.dcmread(dcm_path)
            arr = ds.pixel_array.astype(np.float32)
            # --- Window/Level logic ---
            # Reference: https://radiopaedia.org/articles/windowing-ct
            if window is not None and level is not None:
                w = float(window)
                l = float(level)
                arr = np.clip((arr - (l - 0.5)) / (w - 1) + 0.5, 0, 1) * 255
            else:
                arr = (arr - arr.min()) / (arr.max() - arr.min() + 1e-5) * 255.0
            arr = arr.astype(np.uint8)
            img = Image.fromarray(arr)
            buf = io.BytesIO()
            img.save(buf, format="JPEG")
            buf.seek(0)
            return Response(content=buf.read(), media_type="image/jpeg")
        except Exception:
            raise HTTPException(500, "Failed to convert DICOM to JPEG")
    else:
        raise HTTPException(400, "Unknown format requested")