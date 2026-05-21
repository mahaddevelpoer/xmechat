const fs = require('fs');
const logPath = 'C:\\Users\\HP\\.gemini\\antigravity\\brain\\d1aab8f5-8e8f-4fb5-8486-488d41865a3a\\.system_generated\\logs\\overview.txt';
const content = fs.readFileSync(logPath, 'utf8');

const blocks = content.split('File Path: ile:///d:/xmechat/lib/screens/chat/private_chat_screen.dart');
for (let i = blocks.length - 1; i >= 0; i--) {
    const b = blocks[i];
    if (b.includes('Total Lines: 905')) {
        const lines = b.split('\n');
        let codeLines = [];
        let capture = false;
        for (let line of lines) {
            line = line.replace(/\r$/, '');
            if (line.includes('The following code has been modified')) {
                capture = true;
                continue;
            }
            if (capture) {
                if (line.includes('The above content') || line.includes('`')) {
                    break;
                }
                const match = line.match(/^(\d+):\s(.*)$/);
                if (match) {
                    codeLines.push(match[2]);
                } else if (line.match(/^(\d+):$/)) {
                    codeLines.push('');
                }
            }
        }
        if (codeLines.length > 0) {
            fs.writeFileSync('recovered.dart', codeLines.join('\n'));
            console.log('Recovered ' + codeLines.length + ' lines!');
            process.exit(0);
        }
    }
}
console.log('Not found');
