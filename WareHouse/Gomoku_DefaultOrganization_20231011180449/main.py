'''
This is the main file for the Gomoku game.
'''
import tkinter as tk
from game import Game
def main():
    root = tk.Tk()
    game = Game(root)
    root.mainloop()
if __name__ == "__main__":
    main()