import pydicom
from pathlib import Path

def parse_dicom_folder(folder: Path):
    """
    Parse all DICOM files in a folder and extract metadata.
    """
    studies = []
    for f in folder.glob("**/*.dcm"):
        ds = pydicom.dcmread(f)
        info = {
            "filename": str(f),
            "patient_name": str(ds.get("PatientName", "")),
            "study_date": ds.get("StudyDate", ""),
            "series_description": ds.get("SeriesDescription", ""),
            "window_center": ds.get("WindowCenter", None),
            "window_width": ds.get("WindowWidth", None),
            "pixel_spacing": ds.get("PixelSpacing", None),
            "rows": ds.get("Rows", None),
            "columns": ds.get("Columns", None),
        }
        studies.append(info)
    return studies

def get_study_metadata(folder: Path):
    """
    Return parsed study/series/image structure for the frontend.
    """
    return parse_dicom_folder(folder)