'''
This file contains the Game class which handles the game logic.
'''
import tkinter as tk
class Game:
    def __init__(self, root):
        self.root = root
        self.root.title("Gomoku")
        self.board = Board(self.root)
        self.board.pack()
class Board(tk.Canvas):
    def __init__(self, master):
        super().__init__(master, width=600, height=600, bg="white")
        self.bind("<Button-1>", self.on_click)
        self.grid = [[0] * 15 for _ in range(15)]
        self.turn = 1
    def on_click(self, event):
        if self.turn == 1:
            self.draw_piece(event.x, event.y, "black")
            self.turn = 2
        else:
            self.draw_piece(event.x, event.y, "white")
            self.turn = 1
    def draw_piece(self, x, y, color):
        row = y // 40
        col = x // 40
        if self.grid[row][col] == 0:
            self.create_oval(col * 40, row * 40, (col + 1) * 40, (row + 1) * 40, fill=color)
            self.grid[row][col] = self.turn
            if self.check_win(row, col):
                self.show_winner()
    def check_win(self, row, col):
        directions = [(1, 0), (0, 1), (1, 1), (1, -1), (-1, 0), (0, -1), (-1, -1), (-1, 1)]
        for dx, dy in directions:
            count = 1
            for i in range(1, 5):
                new_row = row + i * dx
                new_col = col + i * dy
                if 0 <= new_row < 15 and 0 <= new_col < 15 and self.grid[new_row][new_col] == self.turn:
                    count += 1
                else:
                    break
            for i in range(1, 5):
                new_row = row - i * dx
                new_col = col - i * dy
                if 0 <= new_row < 15 and 0 <= new_col < 15 and self.grid[new_row][new_col] == self.turn:
                    count += 1
                else:
                    break
            if count >= 5:
                return True
        return False
    def show_winner(self):
        winner = "Black" if self.turn == 1 else "White"
        self.create_text(300, 300, text=f"{winner} wins!", font=("Arial", 30), fill="red")
        self.unbind("<Button-1>")