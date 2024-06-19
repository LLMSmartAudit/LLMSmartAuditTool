'''
This file contains the graphical user interface (GUI) for the triples_sum_to_zero program.
'''
import tkinter as tk
from tkinter import messagebox
from triples_sum_to_zero import triples_sum_to_zero
def check_sum():
    """
    Event handler for the Check Sum button.
    Retrieves the input from the entry field, calls the triples_sum_to_zero function,
    and displays the result in a message box.
    """
    nums = entry.get()
    nums = [int(num) for num in nums.split()]
    result = triples_sum_to_zero(nums)
    messagebox.showinfo("Result", f"There are three distinct elements that sum to zero: {result}")
# Create the main window
window = tk.Tk()
window.title("Triples Sum to Zero")
# Create the input label and entry field
label = tk.Label(window, text="Enter a list of integers:")
label.pack()
entry = tk.Entry(window)
entry.pack()
# Create the Check Sum button
button = tk.Button(window, text="Check Sum", command=check_sum)
button.pack()
# Start the main loop
window.mainloop()