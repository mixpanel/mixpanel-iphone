#!/usr/bin/python
import os, re

rules = [
            (r'[\t ]+(?=[\r\n])', ''), #replace spaces before newlines
            (r'@property\s*\(((?:[\w ]+,)*[\w ]+)\)\s*',
                lambda m: '@property (%s) ' % (', '.join([s.strip() for s in m.group(1).split(',')]))), #space out property declarations
            (r'(@(?:interface|implementation)[^\n]*[^\n{])\n(?=[^\n])',
                lambda m: '%s\n\n' % m.groups(1)), #add blank lines after interface or implementation declarations (except where the interface line ends in a '{')
            (r'(?<=[^\n])\n@end', lambda m: '\n\n@end' ), #add blank lines before @end
        ]

if __name__ == '__main__':
    for root, dirs, files in os.walk('.'):
        for name in files:
            if re.search('\.(h|m)$', name):
                with open(os.path.join(root, name), 'r') as f1:
                    content = f1.read()
                for pattern, repl in rules:
                    content = re.sub(pattern, repl, content)
                with open(os.path.join(root, name), 'w+') as f2:
                    f2.write(content)
