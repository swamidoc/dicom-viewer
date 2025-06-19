
from kivymd.app import MDApp
from kivy.uix.screenmanager import ScreenManager
from viewer import DicomViewerScreen

class MainApp(MDApp):
    def build(self):
        self.title = "DICOM AI Viewer"
        sm = ScreenManager()
        sm.add_widget(DicomViewerScreen(name="viewer"))
        return sm

if __name__ == '__main__':
    MainApp().run()
