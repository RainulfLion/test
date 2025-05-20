import tkinter as tk
from tkinter import filedialog, messagebox
from PIL import Image, ImageTk

def open_image():
    file_path = filedialog.askopenfilename(
        filetypes=[("Image Files", "*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.tiff")]
    )
    if not file_path:
        return
    try:
        img = Image.open(file_path)
        img.thumbnail((600, 600))
        photo = ImageTk.PhotoImage(img)
        image_label.config(image=photo)
        image_label.image = photo
    except Exception as e:
        messagebox.showerror("Error", f"Cannot open image:\n{e}")

root = tk.Tk()
root.title("Simple Image Viewer")
root.geometry("650x700")

open_button = tk.Button(root, text="Open Image", command=open_image)
open_button.pack(pady=10)

image_label = tk.Label(root)
image_label.pack(pady=10)

root.mainloop()