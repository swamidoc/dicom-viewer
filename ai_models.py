
import numpy as np
import cv2
from PIL import Image

def run_lung_inference(image):
    return np.random.rand(512, 512)

def run_abdomen_inference(image):
    return np.random.rand(512, 512)

def run_pelvis_inference(image):
    return np.random.rand(512, 512)

def run_neck_inference(image):
    return np.random.rand(512, 512)

def overlay_heatmap(image, heatmap):
    heatmap_color = cv2.applyColorMap((heatmap * 255).astype(np.uint8), cv2.COLORMAP_JET)
    image_rgb = cv2.cvtColor(np.array(image), cv2.COLOR_GRAY2RGB)
    combined = cv2.addWeighted(image_rgb, 0.7, heatmap_color, 0.3, 0)
    return Image.fromarray(combined)

def save_heatmap_image(heatmap_np, output_path):
    heatmap_color = cv2.applyColorMap((heatmap_np * 255).astype(np.uint8), cv2.COLORMAP_JET)
    Image.fromarray(cv2.cvtColor(heatmap_color, cv2.COLOR_BGR2RGB)).save(output_path)
