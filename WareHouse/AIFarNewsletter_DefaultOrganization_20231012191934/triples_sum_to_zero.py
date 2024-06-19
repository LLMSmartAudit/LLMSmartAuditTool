import tkinter as tk
from tkinter import messagebox
def triples_sum_to_zero(nums):
    nums.sort()
    n = len(nums)
    for i in range(n-2):
        left = i + 1
        right = n - 1
        while left < right:
            total = nums[i] + nums[left] + nums[right]
            if total == 0:
                return True
            elif total < 0:
                left += 1
            else:
                right -= 1
    return False
def check_sum_to_zero():
    nums = [int(num) for num in entry.get().split()]
    if len(nums) < 3:
        messagebox.showerror("Error", "At least 3 numbers are required.")
    else:
        result = triples_sum_to_zero(nums)
        messagebox.showinfo("Result", f"Result: {result}")
# GUI setup
window = tk.Tk()
window.title("Triples Sum to Zero")
window.geometry("300x150")
label = tk.Label(window, text="Enter numbers (space-separated):")
label.pack()
entry = tk.Entry(window)
entry.pack()
button = tk.Button(window, text="Check", command=check_sum_to_zero)
button.pack()
window.mainloop()