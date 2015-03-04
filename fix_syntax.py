#!/usr/bin/python
import os, re, sys

rules = [
            (r'[\t ]+(?=[\r\n])', ''), #replace spaces before newlines
            (r'@property\s*\(((?:[\w ]+,)*[\w ]+)\)\s*',
                lambda m: '@property (%s) ' % (', '.join([s.strip() for s in m.group(1).split(',')]))), #space out property declarations
            (r'(@(?:interface|implementation)[^\n]*[^\n{])\n(?=[^\n])',
                lambda m: '%s\n\n' % m.groups(1)), #add blank lines after interface or implementation declarations (except where the interface line ends in a '{')
            (r'(?<=[^\n])\n@end', lambda m: '\n\n@end' ), #add blank lines before @end
            (r'for[ ]*\((.*)\)\s*{\n', lambda m: 'for (%s) {\n' % m.group(1)), #correct spacing for for loops
            (r'}\s*else\s*{', '} else {'), #correct spacing for else statements
            (r'\n(\s*)if\s*\((.*)\n\s*{', lambda m: '\n%sif (%s {' % (m.group(1), m.group(2))), #correct spacing for if statements
            (r'for \([ ]*uint[ ]+', 'for (NSUInteger '), #use NSUinteger instead of uint
            (r'for \([ ]*int[ ]+', 'for (NSInteger '), #use NSinteger instead of int
            (r'\n([+-])[ ]*\((\w+\s*\*?)\)\s*', lambda m: '\n%s (%s)' % (m.group(1), m.group(2))), #proper spacing in method definitions
            (r'#import\s+(?=["<])', '#import '),
            (r'(\n+(?:#import ["<][^"<>]*[">]\n+)+)', lambda m: "\n\n" + '\n'.join(
                sorted(
                    sorted(
                        set(
                            filter(lambda b: len(b) > 0,
                                map(lambda s: s.strip(), m.group(1).split('\n'))
                            )
                        ),
                        key=lambda k: k[9:].lower()),
                    key = lambda k: k[:9], reverse=True)
                ) + "\n\n"), # Organize imports

        ]

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print "fix_syntax.py DIRECTORY"
    else:
        for root, dirs, files in os.walk(sys.argv[1]):
            for name in files:
                if re.search('\.(h|m)$', name):
                    with open(os.path.join(root, name), 'r') as f1:
                        content = f1.read()
                    for pattern, repl in rules:
                        content = re.sub(pattern, repl, content)
                    with open(os.path.join(root, name), 'w+') as f2:
                        f2.write(content)
