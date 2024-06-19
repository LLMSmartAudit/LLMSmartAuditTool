'''
This file contains the GomokuGUI class which represents the graphical user interface for the Gomoku game.
'''
import tkinter as tk
from tkinter import messagebox
class GomokuGUI:
    def __init__(self, game):
        self.game = game
        self.window = tk.Tk()
        self.window.title("Gomoku")
        self.buttons = []
        self.create_board()
    def create_board(self):
        for i in range(15):
            row = []
            for j in range(15):
                button = tk.Button(self.window, width=2, height=1, command=lambda x=i, y=j: self.handle_move(x, y))
                button.grid(row=i, column=j)
                row.append(button)
            self.buttons.append(row)
    def handle_move(self, x, y):
        self.game.make_move(x, y)
        self.update_board()
        winner = self.game.check_win()
        if winner != 0:
            messagebox.showinfo("Game Over", f"Player {winner} wins!")
            self.window.quit()
    def update_board(self):
        for i in range(15):
            for j in range(15):
                if self.game.board[i][j] == 1:
                    self.buttons[i][j].config(text="X", state=tk.DISABLED)
                elif self.game.board[i][j] == 2:
                    self.buttons[i][j].config(text="O", state=tk.DISABLED)
    def run(self):
        self.window.mainloop()