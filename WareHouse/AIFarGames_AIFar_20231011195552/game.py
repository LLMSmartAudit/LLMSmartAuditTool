'''
This file contains the Game class which represents the Gomoku game logic.
'''
class Game:
    def __init__(self):
        self.board = [[0] * 15 for _ in range(15)]
        self.current_player = 1
    def make_move(self, x, y):
        if self.board[x][y] == 0:
            self.board[x][y] = self.current_player
            self.current_player = 3 - self.current_player
    def check_win(self):
        # Check rows
        for i in range(15):
            for j in range(11):
                if self.board[i][j] != 0 and self.board[i][j] == self.board[i][j + 1] == self.board[i][j + 2] == self.board[i][j + 3] == self.board[i][j + 4]:
                    return self.board[i][j]
        # Check columns
        for i in range(11):
            for j in range(15):
                if self.board[i][j] != 0 and self.board[i][j] == self.board[i + 1][j] == self.board[i + 2][j] == self.board[i + 3][j] == self.board[i + 4][j]:
                    return self.board[i][j]
        # Check diagonals (top-left to bottom-right)
        for i in range(11):
            for j in range(11):
                if self.board[i][j] != 0 and self.board[i][j] == self.board[i + 1][j + 1] == self.board[i + 2][j + 2] == self.board[i + 3][j + 3] == self.board[i + 4][j + 4]:
                    return self.board[i][j]
        # Check diagonals (top-right to bottom-left)
        for i in range(11):
            for j in range(4, 15):
                if self.board[i][j] != 0 and self.board[i][j] == self.board[i + 1][j - 1] == self.board[i + 2][j - 2] == self.board[i + 3][j - 3] == self.board[i + 4][j - 4]:
                    return self.board[i][j]
        return 0