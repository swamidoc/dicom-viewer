
from PIL import Image
import pydicom
import cv2
import numpy as np

def export_slice_to_jpg(slice_image, output_path):
    slice_image.save(output_path)

def export_slice_to_dicom(slice_image, output_path):
    ds = pydicom.Dataset()
    ds.PixelData = slice_image.tobytes()
    ds.save_as(output_path)

def export_series_to_jpg(series_images, output_folder):
    for i, img in enumerate(series_images):
        img.save(f"{output_folder}/slice_{i}.jpg")

def export_series_to_dicom(series_images, output_folder):
    for i, img in enumerate(series_images):
        ds = pydicom.Dataset()
        ds.PixelData = img.tobytes()
        ds.save_as(f"{output_folder}/slice_{i}.dcm")

def export_series_to_mp4(series_images, output_path, fps=10):
    height, width = series_images[0].size
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    video = cv2.VideoWriter(output_path, fourcc, fps, (height, width))
    for img in series_images:
        frame = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
        video.write(frame)
    video.release()

def export_study_to_mp4(study_dict, output_folder, fps=10):
    for series_id, images in study_dict.items():
        output_path = f"{output_folder}/{series_id}.mp4"
        export_series_to_mp4(images, output_path, fps)
