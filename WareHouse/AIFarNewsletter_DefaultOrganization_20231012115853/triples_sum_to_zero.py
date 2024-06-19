'''
This file contains the function triples_sum_to_zero that checks if there are three distinct elements in a list that sum to zero.
'''
def triples_sum_to_zero(nums):
    """
    Checks if there are three distinct elements in a list that sum to zero.
    Args:
        nums (list): List of integers.
    Returns:
        bool: True if there are three distinct elements that sum to zero, False otherwise.
    """
    n = len(nums)
    if n < 3:
        return False
    nums.sort()
    for i in range(n-2):
        if i > 0 and nums[i] == nums[i-1]:
            continue
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