import re

log_path = r'C:\Users\HP\.gemini\antigravity\brain\d1aab8f5-8e8f-4fb5-8486-488d41865a3a\.system_generated\logs\overview.txt'

with open(log_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Look for the view_file output that showed lines 1-905
blocks = content.split('File Path: ile:///d:/xmechat/lib/screens/chat/private_chat_screen.dart')

if len(blocks) > 1:
    # Get the last block to get the latest view if any
    for b in reversed(blocks):
        if 'Total Lines: 905' in b or 'Showing lines 1 to 905' in b:
            lines = b.split('\n')
            code_lines = []
            capture = False
            for line in lines:
                if 'The following code has been modified' in line:
                    capture = True
                    continue
                if capture:
                    if 'The above content shows the entire, complete file contents' in line or 'The above content does NOT show' in line or '`' in line:
                        break
                    # Strip the line number: '123: text' -> 'text'
                    if ':' in line:
                        parts = line.split(':', 1)
                        if parts[0].isdigit():
                            code_lines.append(parts[1][1:] if parts[1].startswith(' ') else parts[1])
            
            if code_lines:
                with open('recovered.dart', 'w', encoding='utf-8') as out:
                    out.write('\n'.join(code_lines))
                print(f'Recovered {len(code_lines)} lines!')
                break
else:
    print('Not found')
