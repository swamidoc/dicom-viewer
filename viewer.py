
from kivymd.uix.screen import MDScreen
from kivymd.uix.button import MDRaisedButton, MDFlatButton
from kivymd.uix.dialog import MDDialog
from kivymd.uix.snackbar import Snackbar
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.filechooser import FileChooserIconView
from backend.ai_models import (
    run_lung_inference,
    run_abdomen_inference,
    run_pelvis_inference,
    run_neck_inference,
    overlay_heatmap,
    save_heatmap_image
)
import os

class DicomViewerScreen(MDScreen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.current_image = None
        self.build_ui()

    def build_ui(self):
        layout = BoxLayout(orientation='horizontal')
        tools_panel = BoxLayout(orientation='vertical', size_hint_x=0.2, spacing=10, padding=5)
        for label, method in [
            ("Window: Bone", self.set_bone_window),
            ("Window: Lung", self.set_lung_window),
            ("Window: Abdomen", self.set_abdomen_window),
            ("Window: Brain", self.set_brain_window),
            ("AI: Lung Detect", self.ai_detect_lung),
            ("AI: Abdomen", self.ai_detect_abdomen),
            ("AI: Pelvis", self.ai_detect_pelvis),
            ("AI: Neck", self.ai_detect_neck),
            ("Export Image", self.export_current_image),
            ("Export AI Image", self.export_ai_image),
            ("Export Heatmap", self.export_ai_heatmap_dialog),
            ("Export Options", self.open_export_menu),
            ("Measure Distance", self.enable_measure_mode),
            ("MPR: Axial", self.show_mpr_axial),
            ("MPR: Coronal", self.show_mpr_coronal),
            ("MPR: Sagittal", self.show_mpr_sagittal)
        ]:
            btn = MDRaisedButton(text=label, on_release=method)
            tools_panel.add_widget(btn)
        layout.add_widget(tools_panel)
        # Placeholder for image widget
        # self.image_widget = ...
        # layout.add_widget(self.image_widget)
        self.add_widget(layout)

    def set_bone_window(self, *args): pass
    def set_lung_window(self, *args): pass
    def set_abdomen_window(self, *args): pass
    def set_brain_window(self, *args): pass
    def ai_detect_lung(self, *args): pass
    def ai_detect_abdomen(self, *args): pass
    def ai_detect_pelvis(self, *args): pass
    def ai_detect_neck(self, *args): pass
    def export_current_image(self, *args): pass
    def export_ai_image(self, *args): pass
    def open_export_menu(self, *args): pass
    def enable_measure_mode(self, *args): pass
    def show_mpr_axial(self, *args): pass
    def show_mpr_coronal(self, *args): pass
    def show_mpr_sagittal(self, *args): pass

    def export_ai_heatmap_dialog(self, *args):
        from kivymd.uix.menu import MDDropdownMenu
        options = [
            ("Lung", run_lung_inference),
            ("Abdomen", run_abdomen_inference),
            ("Pelvis", run_pelvis_inference),
            ("Neck", run_neck_inference)
        ]
        items = [
            {
                "text": label,
                "on_release": lambda x=label, fn=func: (self.dialog.dismiss(), self.choose_heatmap_path(fn, label))
            }
            for label, func in options
        ]
        self.dialog = MDDialog(
            title="Choose Region for Heatmap",
            type="simple",
            items=[MDFlatButton(text=item["text"], on_release=item["on_release"]) for item in items]
        )
        self.dialog.open()

    def choose_heatmap_path(self, ai_func, label):
        chooser = FileChooserIconView(path=".", filters=["*.jpg"], multiselect=False)
        box = BoxLayout(orientation="vertical")
        box.add_widget(chooser)
        confirm = MDRaisedButton(
            text="Export Heatmap",
            on_release=lambda x: (self._export_heatmap(ai_func, os.path.join(chooser.path, f"{label.lower()}_heatmap.jpg")), self.dialog.dismiss())
        )
        self.dialog = MDDialog(title="Save Heatmap As", type="custom", content_cls=box, buttons=[confirm])
        self.dialog.open()

    def _export_heatmap(self, ai_func, export_path):
        try:
            heatmap = ai_func(self.current_image)
            save_heatmap_image(heatmap, export_path)
            Snackbar(text="✅ Heatmap saved.").open()
        except Exception as e:
            Snackbar(text=f"❌ Heatmap export failed: {e}").open()
