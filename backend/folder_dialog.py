import tkinter as tk
from tkinter import filedialog
import sys

def select_folder():
    root = tk.Tk()
    root.withdraw()
    folder_path = filedialog.askdirectory()
    root.destroy()
    print(folder_path)  # 将路径打印到标准输出

if __name__ == "__main__":
    select_folder()
