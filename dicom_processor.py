
import pydicom
import os

def load_dicom_files_from_folder(folder_path):
    dicom_files = []
    for root, _, files in os.walk(folder_path):
        for file in files:
            if file.lower().endswith(('.dcm', '.dicom')):
                try:
                    dcm = pydicom.dcmread(os.path.join(root, file))
                    dicom_files.append(dcm)
                except Exception as e:
                    print(f"Failed to load {file}: {e}")
    return dicom_files

def extract_study_metadata(dcm):
    patient_name = getattr(dcm.PatientName, 'family_name', '') or getattr(dcm, 'PatientName', 'Unknown')
    study_date = getattr(dcm, 'StudyDate', 'Unknown')
    modality = getattr(dcm, 'Modality', 'Unknown')
    return patient_name, study_date, modality
