import re

def check_brackets(content):
    stack = []
    line_num = 1
    char_num = 0
    for i, char in enumerate(content):
        if char == '\n':
            line_num += 1
            char_num = 0
        else:
            char_num += 1
            
        if char in '({[':
            stack.append((char, line_num, char_num))
        elif char in ')}]':
            if not stack:
                print(f'Unmatched closing bracket {char} at line {line_num}:{char_num}')
                return False
            open_char, open_line, open_char_num = stack.pop()
            expected = {'(': ')', '{': '}', '[': ']'}
            if expected[open_char] != char:
                print(f'Mismatched bracket: expected {expected[open_char]}, got {char} at line {line_num}:{char_num}')
                return False
    
    if stack:
        for char, line, char_pos in stack:
            print(f'Unmatched opening bracket {char} at line {line}:{char_pos}')
        return False
    
    print('Bracket matching: OK')
    return True

# 检查QML文件
file_path = r'Qt_Oil_NewContent\ContinuousLearning\components\ModelTraining.qml'
try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print(f"File has {len(content.split(chr(10)))} lines")
    check_brackets(content)
    
    # 检查最后几行
    lines = content.split('\n')
    print(f"\n=== Last 10 lines ===")
    for i in range(max(0, len(lines)-10), len(lines)):
        print(f"{i+1:4d}: {lines[i]}")
        
except FileNotFoundError:
    print(f"File not found: {file_path}")
except Exception as e:
    print(f"Error: {e}")
