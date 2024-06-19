'''
Utility functions for triples_sum_to_zero software.
'''
def read_input_file(file_path):
    '''
    Read the input file and return a list of integers.
    '''
    with open(file_path, 'r') as file:
        numbers = [int(line.strip()) for line in file]
    return numbers
def triples_sum_to_zero(numbers):
    '''
    Check if there are three distinct elements in the list that sum to zero.
    Return True if such elements exist, False otherwise.
    '''
    numbers.sort()
    n = len(numbers)
    for i in range(n-2):
        left = i + 1
        right = n - 1
        while left < right:
            total = numbers[i] + numbers[left] + numbers[right]
            if total == 0:
                return True
            elif total < 0:
                left += 1
            else:
                right -= 1
    return False