'''
Main file for triples_sum_to_zero software.
'''
from tkinter import Tk, Label, Button, filedialog
from tkinter.messagebox import showinfo
from utils import read_input_file, triples_sum_to_zero
def select_file():
    file_path = filedialog.askopenfilename(filetypes=[("Text files", "*.txt")])
    if file_path:
        numbers = read_input_file(file_path)
        result = triples_sum_to_zero(numbers)
        if result:
            showinfo("Result", "There are three distinct elements that sum to zero.")
        else:
            showinfo("Result", "There are no three distinct elements that sum to zero.")
root = Tk()
root.title("Triples Sum to Zero")
root.geometry("300x100")
label = Label(root, text="Select a file:")
label.pack()
button = Button(root, text="Browse", command=select_file)
button.pack()
root.mainloop()